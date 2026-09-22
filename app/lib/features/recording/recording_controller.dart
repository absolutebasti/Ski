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
import '../map/thumbnail_renderer.dart';
import '../../platform/notification_service.dart';
import '../../platform/permission_service.dart';
import '../../platform/providers.dart';
import '../../tracking/tracking.dart';
import 'batch_writer.dart';
import 'guards.dart';
import 'live_state_provider.dart';
import 'live_track_provider.dart';
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
  AppLifecycleListener? _lifecycle;
  int _lastSegmentsWriteMs = 0;
  int _lastWatchdogMs = 0;
  int _lastBatterySampleMs = 0;
  final List<(int ts, int pct)> _battery = [];
  bool _resortResolved = false;
  bool _ending = false;
  bool _watchHrSeen = false;

  DaysRepository get _repo => ref.read(daysRepositoryProvider);
  RecordingClock get _clock => ref.read(recordingClockProvider);
  LocationSource get _location => ref.read(locationSourceProvider);
  BarometerSource get _baro => ref.read(barometerSourceProvider);
  BatterySource get _batterySrc => ref.read(batterySourceProvider);
  HeartRateSource get _hr => ref.read(heartRateSourceProvider);
  PermissionService get _perm => ref.read(permissionServiceProvider);
  NotificationService get _notif => ref.read(notificationServiceProvider);
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
    if (state.isRecording || state.status == RecordingStatus.starting) throw const RecordingError(RecordingErrorKind.alreadyRecording);
    state = const RecordingState(status: RecordingStatus.starting);
    try {
      final st = await _perm.status();
      if (st == LocationPermissionState.denied || st == LocationPermissionState.deniedForever) {
        throw const RecordingError(RecordingErrorKind.locationDenied);
      }
      if (!await _perm.isLocationServiceEnabled()) throw const RecordingError(RecordingErrorKind.locationServiceOff);
      if (!await _perm.hasPreciseLocation()) {
        if (!await _perm.requestTemporaryFullAccuracy()) throw const RecordingError(RecordingErrorKind.reducedAccuracy);
      }
      final now = _clock.now();
      // Restart merge: a day that ended < 4 h ago continues silently.
      final recent = await _repo.recentFinishedDay(nowMs: now, window: const Duration(hours: TrackingConfig.restartMergeWindowH));
      String dayId;
      int startedAt;
      if (recent != null) {
        dayId = recent.id;
        startedAt = recent.startedAt;
        await _repo.reopenDay(dayId);
        final points = await _repo.pointsRaw(dayId);
        _engine = _replay(dayId, points);
        _resortResolved = recent.resortId != null;
        ref.read(liveTrackProvider.notifier).seed(points);
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

  Future<void> _run({required String dayId, required int startedAt}) async {
    final now = _clock.now();
    _writer = BatchWriter(_repo, dayId);
    _guards = Guards(dayStartMs: startedAt);
    _lastSegmentsWriteMs = now;
    _lastWatchdogMs = now;
    _lastBatterySampleMs = 0;
    _battery.clear();
    _ending = false;
    _watchHrSeen = false;

    _fixSub = _location.fixes.listen((f) => _engine?.addFix(f), onError: (_) {});
    _pressSub = _baro.samples.listen((s) => _engine?.addPressure(s));
    _hrSub = _hr.bpm.listen((b) {
      _watchHrSeen = true;
      _engine?.addHeartRate(b);
    });
    await _location.start();
    await _baro.start();
    await ref.read(watchdogChannelProvider).start();

    _lifecycle = AppLifecycleListener(onPause: () => unawaited(_writer?.flush(_clock.now())), onDetach: () => unawaited(_writer?.flush(_clock.now())));
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
        if (!_resortResolved) unawaited(_resolveResort(p));
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
    }
    if (now - _lastBatterySampleMs >= TrackingConfig.batterySampleMin * 60000) {
      _lastBatterySampleMs = now;
      unawaited(_sampleBattery(now));
    }
    for (final a in _guards!.evaluate(tick.live, now)) {
      unawaited(_handleGuard(a));
    }
  }

  Future<void> _resolveResort(TrackPoint p) async {
    _resortResolved = true;
    final repo = await ref.read(resortRepositoryProvider.future);
    final r = repo.nearest(p.lat!, p.lon!);
    final dayId = state.dayId;
    if (dayId == null) return;
    await _repo.setResort(dayId, resortId: r?.id, resortName: r?.name);
    if (r != null) await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastResortId: r.id));
  }

  Future<void> _sampleBattery(int now) async {
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
    final result = e.finish();
    await _writer?.flush(now);
    final meaningful = result.stats.totalDistanceM >= TrackingConfig.meaningfulDayMinDistanceM &&
        (result.stats.skiMs + result.stats.liftMs + result.stats.otherMs) >= TrackingConfig.meaningfulDayMinMovingS * 1000;
    String? out;
    if (!meaningful) {
      await _repo.discardDay(dayId);
    } else {
      final endedAt = trimTrailingIdleFrom ?? (result.points.isEmpty ? now : result.points.last.ts);
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
        final path = await ThumbnailRenderer.render(detail);
        await _repo.updateMapThumb(dayId, path);
      }
    } catch (_) {}
    try {
      final d = await _repo.day(dayId);
      final resortId = d?.resortId;
      if (resortId != null) {
        final resorts = await ref.read(resortRepositoryProvider.future);
        final resort = resorts.byId(resortId);
        if (resort != null) {
          final w = await ref.read(weatherProvider(resort).future);
          if (w != null) await _repo.setWeather(dayId, w);
        }
      }
    } catch (_) {}
    ref.invalidate(dayDetailProvider(dayId));
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
    _fixSub = null;
    _pressSub = null;
    _hrSub = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _location.stop();
    await _baro.stop();
    await ref.read(watchdogChannelProvider).stop();
    await _notif.cancel(NotificationIds.dayReminder);
    await _notif.cancel(NotificationIds.idle);
  }

  void _teardownState() {
    _engine = null;
    _writer = null;
    _guards = null;
    _ending = false;
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
    _lifecycle?.dispose();
  }

  // ---------------------------------------------------------------- recovery

  /// At boot: continue an active day silently if its last fix is recent (or the
  /// app was relaunched by the location watchdog); otherwise leave it for the
  /// recovery card. Returns true when recording resumed.
  Future<bool> resumeIfActive() async {
    if (state.isRecording) return true;
    final d = await _repo.activeDay();
    if (d == null) return false;
    final now = _clock.now();
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
    final d = await _repo.day(dayId);
    if (d == null) return false;
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
