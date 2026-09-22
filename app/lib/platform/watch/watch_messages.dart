import '../../core/core.dart';

/// Wire format between phone and the SwiftUI watch app (WP-13).
///
/// Phone → watch: an application context (latest value wins, delivered even
/// when the watch app is in the background).
/// Watch → phone: messages `{cmd: 'start'|'end'}` and `{hr: <bpm>}`.
///
/// Every value must survive a property-list round trip, so only `String`,
/// `num` and `bool` are used and null fields are omitted.
class WatchLivePayload {
  const WatchLivePayload({
    required this.status,
    this.dayId,
    this.dropM = 0,
    this.runCount = 0,
    this.maxSpeedMs = 0,
    this.elapsedMs = 0,
    this.speedMs = 0,
    this.altM,
  });

  /// `recording` while a day is running, `idle` otherwise.
  final String status;
  final String? dayId;
  final double dropM;
  final int runCount;
  final double maxSpeedMs;
  final int elapsedMs;
  final double speedMs;
  final double? altM;

  static const statusRecording = 'recording';
  static const statusIdle = 'idle';

  bool get isRecording => status == statusRecording;

  /// The context sent while a day runs.
  factory WatchLivePayload.recording(LiveState s, {String? dayId}) => WatchLivePayload(
        status: statusRecording,
        dayId: dayId,
        dropM: s.stats.dropM,
        runCount: s.stats.runCount,
        maxSpeedMs: s.stats.maxSpeedMs,
        elapsedMs: s.stats.elapsedMs,
        speedMs: s.speedMs,
        altM: s.altM,
      );

  /// The context sent when no day is running.
  static const idle = WatchLivePayload(status: statusIdle);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'status': status,
        if (dayId != null) 'dayId': dayId,
        'dropM': dropM,
        'runCount': runCount,
        'maxSpeedMs': maxSpeedMs,
        'elapsedMs': elapsedMs,
        'speedMs': speedMs,
        if (altM != null) 'altM': altM,
      };

  factory WatchLivePayload.fromMap(Map<String, dynamic> m) => WatchLivePayload(
        status: m['status'] as String? ?? statusIdle,
        dayId: m['dayId'] as String?,
        dropM: _d(m['dropM']),
        runCount: _i(m['runCount']),
        maxSpeedMs: _d(m['maxSpeedMs']),
        elapsedMs: _i(m['elapsedMs']),
        speedMs: _d(m['speedMs']),
        altM: m['altM'] == null ? null : _d(m['altM']),
      );

  static double _d(Object? v) => v is num ? v.toDouble() : 0;
  static int _i(Object? v) => v is num ? v.toInt() : 0;

  /// True when the watch must be told immediately, throttle or not.
  bool differsStructurally(WatchLivePayload? other) =>
      other == null || other.status != status || other.dayId != dayId;

  @override
  String toString() => 'WatchLivePayload($status, dayId: $dayId, runs: $runCount, drop: $dropM)';
}

/// A command sent from the wrist.
enum WatchCommand { start, end }

/// Parses `{cmd: 'start'|'end'}`; returns null for anything else.
WatchCommand? watchCommandFrom(Map<String, dynamic> message) => switch (message['cmd']) {
      'start' => WatchCommand.start,
      'end' => WatchCommand.end,
      _ => null,
    };

/// Parses `{hr: <bpm>}`; returns null when absent or out of a plausible range.
int? watchHeartRateFrom(Map<String, dynamic> message) {
  final v = message['hr'];
  if (v is! num) return null;
  final bpm = v.round();
  if (bpm < 20 || bpm > 250) return null;
  return bpm;
}
