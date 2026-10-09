import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/db/days_repository.dart';
import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/weather/weather_provider.dart';
import '../map/map_images.dart';
import '../map/thumbnail_renderer.dart';
import '../../platform/device_access.dart';
import '../../platform/notification_service.dart';
import '../../platform/permission_service.dart';
import '../../platform/providers.dart';
import '../../tracking/tracking.dart';
import 'batch_writer.dart';
import 'guards.dart';
import 'live_state_provider.dart';
import 'live_track_provider.dart';
import 'recording_access.dart';
import 'recording_clock.dart';
import 'recording_strings.dart';
import 'recovery_service.dart';

enum RecordingErrorKind { locationDenied, locationServiceOff, reducedAccuracy, alreadyRecording }

class RecordingError implements Exception {
  const RecordingError(this.kind);
  final RecordingErrorKind kind;
  @override
  String toString() => 'RecordingError(${kind.name})';
}

/// Owns a ski day from Start to End: sources → engine → DB, guards, watchdog,
/// live state. keepAlive; created at boot.
class RecordingController extends Notifier<RecordingState> {
  TrackingEngine? _engine;
  BatchWriter? _writer;
  Guards? _guards;
  TickerHandle? _ticker;
  StreamSubscription<RawFix>? _fixSub;
  StreamSubscription<PressureSample>? _pressSub;
  StreamSubscription<int>? _hrSub;
  StreamSubscription<bool>? _serviceSub;
  AppLifecycleListener? _lifecycle;
  int _lastSegmentsWriteMs = 0;
  int _lastWatchdogMs = 0;
  int _lastBatterySampleMs = 0;
  final List<(int ts, int pct)> _battery = [];
  bool _resortResolved = false;
  int _lastResortTryMs = 0;
  bool _ending = false;
  bool _watchHrSeen = false;
  int? _accessLostSinceMs;
  bool _recheckingAccess = false;

  DaysRepository get _repo => ref.read(daysRepositoryProvider);
  RecordingClock get _clock => ref.read(recordingClockProvider);
  LocationSource get _location => ref.read(locationSourceProvider);
  BarometerSource get _baro => ref.read(barometerSourceProvider);
  BatterySource get _batterySrc => ref.read(batterySourceProvider);
  HeartRateSource get _hr => ref.read(heartRateSourceProvider);
  PermissionService get _perm => ref.read(permissionServiceProvider);
  NotificationService get _notif => ref.read(notificationServiceProvider);
  DeviceAccessSource get _access => ref.read(deviceAccessProvider);
  RecordingStrings get _s => RecordingStrings.forLocale(ref.read(settingsProvider).locale, WidgetsBinding.instance.platformDispatcher.locale.languageCode);

  @override
  RecordingState build() {
    ref.keepAlive();
    ref.onDispose(_teardown);
    return RecordingState.idle;
  }

  TrackingEngine? get engine => _engine;

  // ---------------------------------------------------------------- start

  Future<void> startDay() async {
    if (state.status != RecordingStatus.idle || _ending) throw const RecordingError(RecordingErrorKind.alreadyRecording);
    state = const RecordingState(status: RecordingStatus.starting);
    try {
      var st = await _perm.status();
      // iOS reports "not determined" (e.g. after "Allow Once" expired) as
      // denied: ask again instead of sending the rider to Settings.
      if (st == LocationPermissionState.denied) st = await _perm.requestWhenInUse();
      if (st == LocationPermissionState.denied || st == LocationPermissionState.deniedForever) {
        throw const RecordingError(RecordingErrorKind.locationDenied);
      }
      if (!await _perm.isLocationServiceEnabled()) throw const RecordingError(RecordingErrorKind.locationServiceOff);
      if (!await _perm.hasPreciseLocation()) {
        if (!await _perm.requestTemporaryFullAccuracy()) throw const RecordingError(RecordingErrorKind.reducedAccuracy);
      }
      final now = _clock.now();
      // An interrupted day still open (recovery card): Start continues it when
      // it is still today, otherwise it is finished first and a new day begins.
      final open = await _repo.activeDay();
      if (open != null) {
        if (!Guards.dayExpired(open.startedAt, now)) {
          state = RecordingState.idle;
          await resumeDay(open.id);
          return;
        }
        await endRecoveredDay(open.id);
      }
      // Restart merge: a day that ended < 4 h ago continues silently.
      final recent = await _mergeCandidate(now);
      String dayId;
      int startedAt;
      if (recent != null) {
        dayId = recent.day.id;
        startedAt = recent.day.startedAt;
        await _repo.reopenDay(dayId);
        _engine = _replay(dayId, recent.points);
        _resortResolved = recent.day.resortId != null;
        ref.read(liveTrackProvider.notifier).seed(recent.points);
      } else {
        dayId = const Uuid().v7();
        startedAt = now;
        await _repo.createActiveDay(id: dayId, startedAt: startedAt);
        _engine = TrackingEngine(dayId: dayId);
        _resortResolved = false;
        ref.read(liveTrackProvider.notifier).clear();
      }
      await _run(dayId: dayId, startedAt: startedAt);
    } catch (_) {
      state = RecordingState.idle;
      rethrow;
    }
  }

  /// Rebuild a live engine from stored points (same code path as computeDay).
  TrackingEngine _replay(String dayId, List<TrackPoint> points) {
    final e = TrackingEngine(dayId: dayId);
    for (final p in points) {
      if (p.hasPosition) {
        e.addFix(RawFix(ts: p.ts, lat: p.lat!, lon: p.lon!, hAccM: p.hAccM ?? 99, gpsAltM: p.gpsAltM, vAccM: p.vAccM, speedMs: p.speedMs, speedAccMs: p.speedAccMs, courseDeg: p.courseDeg));
      }
      if (p.pressureHpa != null) e.addPressure(PressureSample(ts: p.ts, hPa: p.pressureHpa!));
      if (p.heartRateBpm != null) e.addHeartRate(p.heartRateBpm!);
      e.tick(p.ts);
    }
    return e;
  }

  /// The finished day a Start continues (restart merge, docs/PLAN.md §5):
  /// ended < restartMergeWindowH ago, still the same ski day (no rollover,
  /// under maxDayH), its points on this phone, and — when iOS knows where we
  /// are — not somewhere else (> restartMergeMaxKm from where it ended).
  Future<({DayRecord day, List<TrackPoint> points})?> _mergeCandidate(int now) async {
    final recent = await _repo.recentFinishedDay(nowMs: now, window: const Duration(hours: TrackingConfig.restartMergeWindowH));
    if (recent == null || Guards.dayExpired(recent.startedAt, now)) return null;
    final points = await _repo.pointsRaw(recent.id);
    final lastPos = points.lastWhere((p) => p.hasPosition, orElse: () => const TrackPoint(ts: 0));
    if (!lastPos.hasPosition) return null; // restored from the server without its track
    try {
      final here = await _location.lastKnown();
      if (here != null &&
          now - here.ts <= 15 * 60000 &&
          haversineM(here.lat, here.lon, lastPos.lat!, lastPos.lon!) > TrackingConfig.restartMergeMaxKm * 1000) {
        return null;
      }
    } catch (_) {}
    return (day: recent, points: points);
  }

  Future<void> _run({required String dayId, required int startedAt}) async {
    final now = _clock.now();
    _writer = BatchWriter(_repo, dayId);
    _guards = Guards(dayStartMs: startedAt, sessionStartMs: now);
    _lastSegmentsWriteMs = now;
    _lastWatchdogMs = now;
    _lastBatterySampleMs = 0;
    _battery.clear();
    _ending = false;
    _watchHrSeen = false;
    _accessLostSinceMs = null;
    ref.read(recordingHintsProvider.notifier).reset();
    ref.read(trackingAccessProvider.notifier).reset();
    // iOS: CMAltimeter needs Motion & Fitness; without it the day is GPS-only.
    if (!await _access.isMotionGranted()) ref.read(recordingHintsProvider.notifier).push(RecordingHint.motionDenied);

    // A stream error usually means access was lost: re-check right away.
    _fixSub = _location.fixes.listen((f) => _engine?.addFix(f), onError: (_) => unawaited(recheckAccess()));
    _serviceSub = _access.locationServiceChanges.listen(_onServiceStatus);
    _pressSub = _baro.samples.listen((s) => _engine?.addPressure(s));
    _hrSub = _hr.bpm.listen((b) {
      _watchHrSeen = true;
      _engine?.addHeartRate(b);
    });
    await _location.start();
    await _baro.start();
    await ref.read(watchdogChannelProvider).start();

    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(_writer?.flush(_clock.now())),
      onDetach: () => unawaited(_writer?.flush(_clock.now())),
      // Settings may have changed while we were in the background.
      onResume: () => unawaited(recheckAccess()),
    );
    _ticker = _clock.periodic(const Duration(seconds: 1), _onTick);

    ref.read(isRecordingProvider.notifier).set(true);
    ref.read(liveStateNotifierProvider.notifier).set(_engine!.live);
    state = RecordingState(status: RecordingStatus.recording, dayId: dayId, startedAt: startedAt);
    ref.read(recoveryRefreshProvider.notifier).bump();
  }

  // ---------------------------------------------------------------- tick

  void _onTick() {
    final e = _engine;
    final w = _writer;
    if (e == null || w == null || _ending) return;
    final now = _clock.now();
    final tick = e.tick(now);
    final p = tick.point;
    if (p != null) {
      w.add(p, stats: tick.segmentsChanged ? e.stats : null, streamRestarts: _location.restartCount);
      if (p.accepted) {
        ref.read(liveTrackProvider.notifier).add(p);
        // Unresolved until a resort is found; retried once a minute (first fixes
        // often sit in the valley car park, outside every radius).
        if (!_resortResolved && now - _lastResortTryMs >= 60000) {
          _lastResortTryMs = now;
          unawaited(_resolveResort(p));
        }
      }
    }
    ref.read(liveStateNotifierProvider.notifier).set(tick.live);
    if (w.due(now)) unawaited(w.flush(now));
    if (tick.segmentsChanged && now - _lastSegmentsWriteMs >= 10000) {
      _lastSegmentsWriteMs = now;
      unawaited(_repo.replaceSegments(e.dayId, e.segments));
    }
    if (now - _lastWatchdogMs >= TrackingConfig.streamWatchdogS * 1000) {
      _lastWatchdogMs = now;
      unawaited(_location.restartIfSilent(now));
      // Access can be revoked while the phone stays locked (no resume event).
      unawaited(recheckAccess());
    }
    if (now - _lastBatterySampleMs >= TrackingConfig.batterySampleMin * 60000) {
      _lastBatterySampleMs = now;
      unawaited(_sampleBattery(now));
    }
    for (final a in _guards!.evaluate(tick.live, now, accessLostSinceMs: _accessLostSinceMs)) {
      unawaited(_handleGuard(a));
    }
  }

  // ---------------------------------------------------------------- access

  void _onServiceStatus(bool enabled) {
    if (!enabled) {
      _setAccess(TrackingAccess.serviceOff);
    } else {
      unawaited(recheckAccess());
    }
  }

  /// Re-reads service state + permission (on resume and when the service
  /// comes back). Public so the Heute screen can call it after Settings.
  Future<void> recheckAccess() async {
    if (!state.isRecording || _recheckingAccess) return;
    _recheckingAccess = true;
    try {
      final on = await _perm.isLocationServiceEnabled();
      final st = await _perm.status();
      if (!state.isRecording) return;
      if (!on) {
        _setAccess(TrackingAccess.serviceOff);
      } else if (st == LocationPermissionState.denied || st == LocationPermissionState.deniedForever) {
        _setAccess(TrackingAccess.permissionDenied);
      } else {
        _setAccess(TrackingAccess.ok);
      }
    } catch (_) {
      // plugin hiccup: keep the current state
    } finally {
      _recheckingAccess = false;
    }
  }

  void _setAccess(TrackingAccess a) {
    if (!state.isRecording || _ending) return;
    final prev = ref.read(trackingAccessProvider);
    if (prev.access == a) return;
    if (a == TrackingAccess.ok) {
      _accessLostSinceMs = null;
      ref.read(trackingAccessProvider.notifier).reset();
      unawaited(_notif.cancel(NotificationIds.access));
      return;
    }
    _accessLostSinceMs ??= _clock.now();
    ref.read(trackingAccessProvider.notifier).set(TrackingAccessState(access: a, lostSinceMs: _accessLostSinceMs));
    // Not gated by the reminder opt-in: nothing is being recorded right now.
    unawaited(_notif.showReminder(NotificationIds.access, _s.accessLostTitle, _s.accessLostBody(a)));
  }

  Future<void> _resolveResort(TrackPoint p) async {
    final repo = await ref.read(resortRepositoryProvider.future);
    final r = repo.nearest(p.lat!, p.lon!);
    final dayId = state.dayId;
    if (dayId == null || r == null) return; // stay unresolved, retry later
    _resortResolved = true;
    await _repo.setResort(dayId, resortId: r.id, resortName: r.name);
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastResortId: r.id));
  }

  Future<void> _sampleBattery(int now) async {
    final lowPower = await _access.isLowPowerMode();
    ref.read(lowPowerModeProvider.notifier).set(lowPower);
    if (lowPower) ref.read(recordingHintsProvider.notifier).push(RecordingHint.lowPowerMode);
    final pct = await _batterySrc.level();
    if (pct == null) return;
    _battery.add((now, pct));
    _battery.removeWhere((s) => now - s.$1 > 30 * 60000);
    int? eta;
    if (_battery.length >= 2) {
      final first = _battery.first;
      final dt = now - first.$1;
      final drop = first.$2 - pct;
      if (dt > 0 && drop > 0) eta = now + (pct / (drop / dt)).round();
    }
    _engine?.setBattery(pct: pct, etaTs: eta);
  }

  Future<void> _handleGuard(GuardAction a) async {
    final optIn = ref.read(settingsProvider).notificationsOptIn;
    switch (a) {
      case GuardAction.none:
        return;
      case GuardAction.remindIdle:
        if (optIn) await _notif.showReminder(NotificationIds.idle, _s.idleTitle, _s.idleBody);
      case GuardAction.remindFourHours:
        if (optIn) await _notif.showReminder(NotificationIds.dayReminder, _s.fourHoursTitle, _s.fourHoursBody);
      case GuardAction.warnBattery:
        if (optIn) await _notif.showReminder(NotificationIds.battery, _s.batteryTitle, _s.batteryBody);
      case GuardAction.autoEndIdle:
        final id = await endDay(trimTrailingIdleFrom: _guards?.stopSince);
        if (optIn && id != null) await _notif.showReminder(NotificationIds.summary, _s.autoEndTitle, _s.autoEndIdleBody);
      case GuardAction.autoEndVehicle:
        final id = await endDay();
        if (optIn && id != null) await _notif.showReminder(NotificationIds.vehicle, _s.autoEndTitle, _s.autoEndVehicleBody);
      case GuardAction.autoEndMidnight:
      case GuardAction.autoEndMaxDuration:
        // Forgotten recording: close it, trimming the trailing idle time.
        final id = await endDay(trimTrailingIdleFrom: _guards?.stopSince);
        if (optIn && id != null) await _notif.showReminder(NotificationIds.summary, _s.autoEndTitle, _s.autoEndLongBody);
      case GuardAction.autoEndNoAccess:
        final id = await endDay(trimTrailingIdleFrom: _accessLostSinceMs);
        if (id != null) await _notif.showReminder(NotificationIds.summary, _s.autoEndTitle, _s.autoEndNoAccessBody);
    }
  }

  // ---------------------------------------------------------------- end

  /// Ends the day. Returns the dayId, or null when the day was too short and discarded.
  Future<String?> endDay({int? trimTrailingIdleFrom}) async {
    final e = _engine;
    final dayId = state.dayId;
    if (e == null || dayId == null || _ending) return null;
    _ending = true;
    state = RecordingState(status: RecordingStatus.ending, dayId: dayId, startedAt: state.startedAt);
    await _stopSources();
    final now = _clock.now();
    var result = e.finish();
    await _writer?.flush(now);
    // Trailing idle (forgotten recording): the numbers end where the day
    // ended — drop the idle tail before computing what is stored and synced.
    if (trimTrailingIdleFrom != null && result.points.isNotEmpty && result.points.last.ts > trimTrailingIdleFrom) {
      await _repo.deletePointsAfter(dayId, trimTrailingIdleFrom);
      result = TrackingEngine.computeDay(dayId, await _repo.pointsRaw(dayId));
    }
    final meaningful = result.stats.totalDistanceM >= TrackingConfig.meaningfulDayMinDistanceM &&
        (result.stats.skiMs + result.stats.liftMs + result.stats.otherMs) >= TrackingConfig.meaningfulDayMinMovingS * 1000;
    String? out;
    if (!meaningful) {
      await _repo.discardDay(dayId);
    } else {
      final lastTs = result.points.isEmpty ? now : result.points.last.ts;
      final endedAt = trimTrailingIdleFrom == null || trimTrailingIdleFrom > lastTs ? lastTs : trimTrailingIdleFrom;
      await _repo.finishDay(dayId, endedAt: endedAt, stats: result.stats, segments: result.segments, trackedOnWatch: _watchHrSeen);
      out = dayId;
    }
    _teardownState();
    if (out != null) await _enrichFinishedDay(out);
    return out;
  }

  /// Map thumbnail + weather snapshot for a finished day. Never blocks saving:
  /// every step is best effort.
  Future<void> _enrichFinishedDay(String dayId) async {
    try {
      final detail = await _repo.dayDetail(dayId);
      if (detail != null && detail.points.length >= 2) {
        final path = await ThumbnailRenderer.renderBoth(detail);
        await _repo.updateMapThumb(dayId, path);
      }
    } catch (_) {}
    // Apple-Maps satellite images (MAP-SNAPSHOT; network, iOS only): not
    // awaited so the Tagesbilanz opens at once. Offline the path PNGs stay and
    // the day card retries later (missing `<id>_map.png` = retry signal).
    try {
      unawaited(ref.read(mapImagesProvider).render(dayId));
    } catch (_) {}
    ref.invalidate(dayDetailProvider(dayId));
    // Weather is network (up to two 10 s timeouts on a weak mountain signal):
    // the Tagesbilanz opens without it and refreshes when it lands.
    unawaited(_attachWeather(dayId));
  }

  Future<void> _attachWeather(String dayId) async {
    try {
      final d = await _repo.day(dayId);
      final resortId = d?.resortId;
      if (resortId == null) return;
      final resorts = await ref.read(resortRepositoryProvider.future);
      final resort = resorts.byId(resortId);
      if (resort == null) return;
      final w = await ref.read(weatherProvider(resort).future);
      if (w == null) return;
      await _repo.setWeather(dayId, w);
      ref.invalidate(dayDetailProvider(dayId));
    } catch (_) {}
  }

  Future<void> discardDay() async {
    final dayId = state.dayId;
    _ending = true;
    await _stopSources();
    if (dayId != null) await _repo.discardDay(dayId);
    _teardownState();
  }

  Future<void> _stopSources() async {
    _ticker?.cancel();
    _ticker = null;
    await _fixSub?.cancel();
    await _pressSub?.cancel();
    await _hrSub?.cancel();
    await _serviceSub?.cancel();
    _fixSub = null;
    _pressSub = null;
    _hrSub = null;
    _serviceSub = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _location.stop();
    await _baro.stop();
    await ref.read(watchdogChannelProvider).stop();
    await _notif.cancel(NotificationIds.dayReminder);
    await _notif.cancel(NotificationIds.idle);
    await _notif.cancel(NotificationIds.access);
  }

  void _teardownState() {
    _engine = null;
    _writer = null;
    _guards = null;
    _ending = false;
    _accessLostSinceMs = null;
    ref.read(trackingAccessProvider.notifier).reset();
    ref.read(recordingHintsProvider.notifier).reset();
    ref.read(isRecordingProvider.notifier).set(false);
    ref.read(liveStateNotifierProvider.notifier).reset();
    ref.read(liveTrackProvider.notifier).clear();
    state = RecordingState.idle;
    ref.read(recoveryRefreshProvider.notifier).bump();
  }

  void _teardown() {
    _ticker?.cancel();
    _fixSub?.cancel();
    _pressSub?.cancel();
    _hrSub?.cancel();
    _serviceSub?.cancel();
    _lifecycle?.dispose();
  }

  // ---------------------------------------------------------------- recovery

  /// At boot: continue an active day silently if its last fix is recent (or the
  /// app was relaunched by the location watchdog); otherwise leave it for the
  /// recovery card. Returns true when recording resumed.
  Future<bool> resumeIfActive() async {
    if (state.isRecording) return true;
    final d = await _repo.activeDay();
    if (d == null) {
      // Nothing to record: make sure iOS stops relaunching us on movement.
      await ref.read(watchdogChannelProvider).stop();
      return false;
    }
    final now = _clock.now();
    if (Guards.dayExpired(d.startedAt, now)) {
      // Yesterday's day (or > maxDayH): the guards would have closed it.
      await endRecoveredDay(d.id);
      return false;
    }
    final last = d.lastFixAt ?? d.startedAt;
    final launchedByWatchdog = await ref.read(watchdogChannelProvider).didLaunchFromLocation();
    if (now - last > TrackingConfig.silentResumeMaxMin * 60000 && !launchedByWatchdog) {
      ref.read(recoveryRefreshProvider.notifier).bump();
      return false;
    }
    return resumeDay(d.id);
  }

  /// "Fortsetzen" on the recovery card, or silent resume.
  Future<bool> resumeDay(String dayId) async {
    if (state.isRecording) return true;
    if (state.status != RecordingStatus.idle || _ending) return false;
    final d = await _repo.day(dayId);
    if (d == null) return false;
    if (Guards.dayExpired(d.startedAt, _clock.now())) {
      await endRecoveredDay(dayId);
      return false;
    }
    state = const RecordingState(status: RecordingStatus.starting);
    try {
      final points = await _repo.pointsRaw(dayId);
      _engine = _replay(dayId, points);
      _resortResolved = d.resortId != null;
      ref.read(liveTrackProvider.notifier).seed(points);
      await _run(dayId: dayId, startedAt: d.startedAt);
      return true;
    } catch (_) {
      state = RecordingState.idle;
      rethrow;
    }
  }

  /// "Beenden & speichern" on the recovery card: finish from stored points.
  Future<String?> endRecoveredDay(String dayId) async {
    final d = await _repo.day(dayId);
    if (d == null) return null;
    await ref.read(watchdogChannelProvider).stop();
    final points = await _repo.pointsRaw(dayId);
    final result = TrackingEngine.computeDay(dayId, points);
    final meaningful = result.stats.totalDistanceM >= TrackingConfig.meaningfulDayMinDistanceM;
    if (!meaningful) {
      await _repo.discardDay(dayId);
      ref.read(recoveryRefreshProvider.notifier).bump();
      return null;
    }
    await _repo.finishDay(dayId, endedAt: d.lastFixAt ?? (points.isEmpty ? d.startedAt : points.last.ts), stats: result.stats, segments: result.segments, trackedOnWatch: d.trackedOnWatch);
    ref.read(recoveryRefreshProvider.notifier).bump();
    await _enrichFinishedDay(dayId);
    return dayId;
  }

  Future<void> discardRecoveredDay(String dayId) async {
    await ref.read(watchdogChannelProvider).stop();
    await _repo.discardDay(dayId);
    ref.read(recoveryRefreshProvider.notifier).bump();
  }

  /// Diagnostics: recompute a finished day with the current engine version.
  Future<void> recomputeDay(String dayId) async {
    final d = await _repo.day(dayId);
    if (d == null) return;
    final points = await _repo.pointsRaw(dayId);
    final result = TrackingEngine.computeDay(dayId, points);
    await _repo.finishDay(dayId, endedAt: d.endedAt ?? (points.isEmpty ? d.startedAt : points.last.ts), stats: result.stats, segments: result.segments, trackedOnWatch: d.trackedOnWatch);
  }
}

final recordingControllerProvider = NotifierProvider<RecordingController, RecordingState>(RecordingController.new);
