import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../core/settings.dart';
import '../../recording/live_state_provider.dart';
import '../social_api.dart';
import '../social_models.dart';
import 'duel_api.dart';
import 'duel_models.dart';
import 'duel_providers.dart';

/// Writes the own `live_days` row while a day is being recorded inside a
/// Tagesduell, so the partners see the numbers move before anyone ends the
/// day (docs/BACKLOG.md SOC-LIVE-DUEL).
///
/// Active while `isRecordingProvider` is true AND `myDuelProvider` has a
/// duel AND a signed-in [DuelApi] exists. While active it upserts
///   * once on activation,
///   * every [interval] (120 s by default) when the numbers changed,
///   * at once when a run finished (`LiveState.lastRun` changed).
/// It stops with `endDay` (recording flag off) — no write after that; the
/// finished day replaces the live row on the server once it synced. Failures
/// are swallowed: the next tick tries again.
///
/// Riverpod 3 pauses a provider nobody watches, so the uploader lives behind
/// [liveDuelUploaderProvider] and is kept alive by [LiveDuelSyncHost] (mount
/// it once in the app tree).
/// Local calendar day used by the midnight guard; tests pin it to the fixture date.
final liveDuelClockProvider = Provider<DateTime Function()>((ref) => today);

class LiveDuelUploader {
  LiveDuelUploader(this._ref, {required this.interval});

  final Ref _ref;
  final Duration interval;

  Timer? _timer;
  LiveDayPayload? _lastSent;
  String? _lastRunId;
  bool _inFlight = false;
  bool _disposed = false;

  /// Writes so far (diagnostics, tests).
  int writes = 0;

  bool get isActive => _timer != null;

  void start() {
    _ref.listen<bool>(isRecordingProvider, (_, _) => _evaluate());
    _ref.listen<AsyncValue<DuelGroup?>>(myDuelProvider, (_, _) => _evaluate());
    _ref.listen<LiveState>(liveStateProvider, (_, next) => _onLive(next));
    _evaluate();
  }

  void dispose() {
    _disposed = true;
    _stop();
  }

  DuelGroup? get _duel {
    final v = _ref.read(myDuelProvider);
    return v.hasValue ? v.value : null;
  }

  DuelApi? get _api {
    final api = _ref.read(duelApiProvider);
    return api == null || api.userId == null ? null : api;
  }

  // The cached duel must be today's: an app kept alive over midnight must not
  // write live rows into yesterday's duel.
  bool get _shouldRun => !_disposed && _ref.read(isRecordingProvider) && _duel != null && _api != null && _duel!.day == _ref.read(liveDuelClockProvider)();

  void _evaluate() {
    if (_shouldRun) {
      if (_timer != null) return;
      _timer = Timer.periodic(interval, (_) => unawaited(_upsert()));
      unawaited(_upsert());
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lastSent = null;
    _lastRunId = null;
  }

  void _onLive(LiveState next) {
    if (_timer == null) return;
    final runId = next.lastRun?.id;
    if (runId == null || runId == _lastRunId) return;
    _lastRunId = runId;
    unawaited(_upsert());
  }

  LiveDayPayload _payload(DuelGroup duel, LiveState live) => LiveDayPayload(
        day: duel.day,
        resortId: _ref.read(settingsProvider).lastResortId,
        dropM: live.stats.dropM,
        runCount: live.stats.runCount,
        skiDistanceM: live.stats.skiDistanceM,
        maxSpeedMs: live.stats.maxSpeedMs,
      );

  Future<void> _upsert() async {
    if (_inFlight || !_shouldRun) return;
    final duel = _duel;
    final api = _api;
    if (duel == null || api == null) return;
    final payload = _payload(duel, _ref.read(liveStateProvider));
    final last = _lastSent;
    if (last != null && payload.sameNumbers(last)) return;
    _inFlight = true;
    try {
      await api.upsertLive(payload);
      _lastSent = payload;
      writes++;
    } on SocialError {
      // Offline on a chairlift: the next tick tries again.
    } catch (_) {
      // Never let a live write take the recording down.
    } finally {
      _inFlight = false;
    }
  }
}

/// The uploader, started; disposed with the container.
final liveDuelUploaderProvider = Provider<LiveDuelUploader>((ref) {
  final uploader = LiveDuelUploader(ref, interval: ref.watch(liveUploadIntervalProvider));
  ref.onDispose(uploader.dispose);
  uploader.start();
  return uploader;
});

/// Keeps [liveDuelUploaderProvider] alive (Riverpod 3 pauses unwatched
/// providers). Renders [child] — wrap the app shell once.
class LiveDuelSyncHost extends ConsumerWidget {
  const LiveDuelSyncHost({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(liveDuelUploaderProvider);
    return child ?? const SizedBox.shrink();
  }
}
