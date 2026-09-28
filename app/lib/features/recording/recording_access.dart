import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_state_provider.dart';

/// Whether the running recording can still read the location.
enum TrackingAccess { ok, serviceOff, permissionDenied }

class TrackingAccessState {
  const TrackingAccessState({this.access = TrackingAccess.ok, this.lostSinceMs});
  static const ok = TrackingAccessState();
  final TrackingAccess access;
  /// Wall clock (ms) when access was lost; null while [access] is ok.
  final int? lostSinceMs;
  bool get lost => access != TrackingAccess.ok;
}

class TrackingAccessNotifier extends Notifier<TrackingAccessState> {
  @override
  TrackingAccessState build() => TrackingAccessState.ok;
  void set(TrackingAccessState s) => state = s;
  void reset() => state = TrackingAccessState.ok;
}

/// Mid-day access state (service off / permission revoked) for the live view.
/// The controller owns it; `GpsQuality.none` in [LiveState] follows ~10 s later.
final trackingAccessProvider = NotifierProvider<TrackingAccessNotifier, TrackingAccessState>(TrackingAccessNotifier.new);

/// One-line hints raised at Start; each fires once per recording.
enum RecordingHint { motionDenied, lowPowerMode }

class RecordingHints {
  const RecordingHints({this.pending = const [], this.raised = const {}});
  static const none = RecordingHints();
  /// Not yet shown to the rider.
  final List<RecordingHint> pending;
  /// Every hint raised during this recording, shown or not.
  final Set<RecordingHint> raised;
}

class RecordingHintsNotifier extends Notifier<RecordingHints> {
  @override
  RecordingHints build() => RecordingHints.none;

  /// Adds [h] once per recording; later pushes of the same hint are ignored.
  void push(RecordingHint h) {
    if (state.raised.contains(h)) return;
    state = RecordingHints(pending: [...state.pending, h], raised: {...state.raised, h});
  }

  /// The UI took the pending hints over (toast, inline line); they stay raised.
  void consume() => state = RecordingHints(raised: state.raised);

  /// New recording: hints may fire again.
  void reset() => state = RecordingHints.none;
}

/// Hints for the Heute screen: show `pending` once, then `consume()`.
final recordingHintsProvider = NotifierProvider<RecordingHintsNotifier, RecordingHints>(RecordingHintsNotifier.new);

class LowPowerModeNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  void set(bool v) => state = v;
}

/// Last Low Power Mode reading (5-min battery sample); null before the first
/// sample. Diagnostics row.
final lowPowerModeProvider = NotifierProvider<LowPowerModeNotifier, bool?>(LowPowerModeNotifier.new);

/// True when altitude comes from GPS only: Motion & Fitness denied, or no
/// pressure sample arrived within the first 20 s of the day ('GPS-Höhe' badge).
final gpsAltitudeOnlyProvider = Provider<bool>((ref) {
  if (ref.watch(recordingHintsProvider.select((h) => h.raised.contains(RecordingHint.motionDenied)))) return true;
  final live = ref.watch(liveStateProvider);
  return !live.stats.hasBarometer && live.stats.elapsedMs >= 20000;
});
