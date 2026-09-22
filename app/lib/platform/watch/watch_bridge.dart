import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../features/recording/live_state_provider.dart';
import '../../features/recording/recording_controller.dart';
import 'watch_messages.dart';
import 'watch_transport.dart';

/// What the bridge last did — the recording screen and the diagnostics bundle
/// can read it, and the tests assert on it.
class WatchBridgeState {
  const WatchBridgeState({
    this.active = false,
    this.lastSent,
    this.lastSentMs,
    this.sent = 0,
    this.throttled = 0,
    this.lastCommand,
    this.lastHeartRateBpm,
  });

  static const idle = WatchBridgeState();

  /// True between [WatchBridge.start] and [WatchBridge.stop].
  final bool active;
  final WatchLivePayload? lastSent;
  final int? lastSentMs;
  final int sent;
  final int throttled;
  final WatchCommand? lastCommand;
  final int? lastHeartRateBpm;

  WatchBridgeState copyWith({
    bool? active,
    WatchLivePayload? lastSent,
    int? lastSentMs,
    int? sent,
    int? throttled,
    WatchCommand? lastCommand,
    int? lastHeartRateBpm,
  }) =>
      WatchBridgeState(
        active: active ?? this.active,
        lastSent: lastSent ?? this.lastSent,
        lastSentMs: lastSentMs ?? this.lastSentMs,
        sent: sent ?? this.sent,
        throttled: throttled ?? this.throttled,
        lastCommand: lastCommand ?? this.lastCommand,
        lastHeartRateBpm: lastHeartRateBpm ?? this.lastHeartRateBpm,
      );
}

/// Phone side of the Apple Watch companion (docs/PLAN.md §0 A2).
///
/// * pushes `{status, dayId, dropM, runCount, maxSpeedMs, elapsedMs, speedMs,
///   altM}` as the WatchConnectivity application context, at most every
///   [minIntervalMs] while recording;
/// * turns `{cmd: 'start'|'end'}` from the wrist into [commands] / [onCommand];
/// * heart rate (`{hr: bpm}`) is consumed by `WatchHeartRateSource`, which the
///   recording controller injects through `heartRateSourceProvider`.
class WatchBridge extends Notifier<WatchBridgeState> {
  /// Apple delivers application contexts opportunistically; 2 s keeps the wrist
  /// numbers alive without draining either battery.
  static const minIntervalMs = 2000;

  ProviderSubscription<LiveState>? _liveSub;
  ProviderSubscription<RecordingState>? _recordingSub;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  final _commands = StreamController<WatchCommand>.broadcast();
  String? _dayId;

  /// Set by the app (one line in `main.dart`) to run Start / End from the wrist.
  void Function(WatchCommand command)? onCommand;

  /// Commands from the wrist, for listeners that prefer a stream.
  Stream<WatchCommand> get commands => _commands.stream;

  WatchTransport get _transport => ref.read(watchTransportProvider);
  int get _now => ref.read(watchClockProvider)();

  @override
  WatchBridgeState build() {
    ref.keepAlive();
    _msgSub = _transport.messages.listen(_onMessage, onError: (Object _) {});
    ref.onDispose(() {
      _liveSub?.close();
      _liveSub = null;
      _recordingSub?.close();
      _recordingSub = null;
      _msgSub?.cancel();
      _msgSub = null;
      _commands.close();
    });
    return WatchBridgeState.idle;
  }

  // ------------------------------------------------------------- lifecycle

  /// One call from `main.dart` wires the whole companion: the bridge follows
  /// the recording controller (start / stop) and runs Start / End commands from
  /// the wrist. Without it the bridge stays silent and the watch shows
  /// 'Warte auf iPhone'.
  void attach() {
    if (_recordingSub != null) return;
    _recordingSub = ref.listen<RecordingState>(recordingControllerProvider, (_, next) {
      if (next.isRecording && !state.active) {
        start(dayId: next.dayId);
      } else if (!next.isRecording && next.status != RecordingStatus.ending && state.active) {
        stop();
      }
    });
    onCommand ??= _runCommand;
    // Self-seed: a day resumed before attach() (crash relaunch) is already recording.
    final now = ref.read(recordingControllerProvider);
    if (now.isRecording && !state.active) start(dayId: now.dayId);
  }

  Future<void> _runCommand(WatchCommand command) async {
    final controller = ref.read(recordingControllerProvider.notifier);
    try {
      if (command == WatchCommand.start) {
        await controller.startDay();
      } else {
        await controller.endDay();
      }
    } catch (_) {
      // Permission or 'already recording' — tell the wrist where we really are
      // so its button stops spinning.
      _send(state.active ? WatchLivePayload.recording(ref.read(liveStateProvider), dayId: _dayId) : WatchLivePayload.idle, force: true);
    }
  }

  /// Called by the recording controller when a day starts. Subscribes to
  /// [liveStateProvider] and sends the first context right away.
  void start({String? dayId}) {
    _dayId = dayId;
    if (!state.active) {
      _liveSub = ref.listen<LiveState>(liveStateProvider, (_, next) => pushLive(next));
      state = state.copyWith(active: true);
    }
    _send(WatchLivePayload.recording(ref.read(liveStateProvider), dayId: dayId), force: true);
  }

  /// Called when the day ends or is discarded. Sends one final idle context.
  void stop() {
    _liveSub?.close();
    _liveSub = null;
    _dayId = null;
    state = state.copyWith(active: false);
    _send(WatchLivePayload.idle, force: true);
  }

  /// Push one live tick. Safe to call at 1 Hz — throttled to [minIntervalMs].
  void pushLive(LiveState live) => _send(WatchLivePayload.recording(live, dayId: _dayId));

  // ------------------------------------------------------------- internals

  void _send(WatchLivePayload payload, {bool force = false}) {
    final now = _now;
    final last = state.lastSentMs;
    final due = force || last == null || now - last >= minIntervalMs || payload.differsStructurally(state.lastSent);
    if (!due) {
      state = state.copyWith(throttled: state.throttled + 1);
      return;
    }
    state = state.copyWith(lastSent: payload, lastSentMs: now, sent: state.sent + 1);
    unawaited(_transport.updateContext(payload.toMap()));
  }

  void _onMessage(Map<String, dynamic> message) {
    final cmd = watchCommandFrom(message);
    if (cmd != null) {
      state = state.copyWith(lastCommand: cmd);
      _commands.add(cmd);
      onCommand?.call(cmd);
    }
    final hr = watchHeartRateFrom(message);
    if (hr != null) state = state.copyWith(lastHeartRateBpm: hr);
  }
}

final watchBridgeProvider = NotifierProvider<WatchBridge, WatchBridgeState>(WatchBridge.new);
