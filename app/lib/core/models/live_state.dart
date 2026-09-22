import 'day_stats.dart';
import 'enums.dart';
import 'segment.dart';

/// What the live Heute screen and the Watch render, refreshed ≈1 Hz.
class LiveState {
  const LiveState({
    this.stats = DayStats.empty,
    this.speedMs = 0,
    this.altM,
    this.state = MotionState.unknown,
    this.gps = GpsQuality.none,
    this.lastRun,
    this.batteryEtaTs,
    this.batteryPct,
    this.heartRateBpm,
    this.lastFixTs,
  });

  static const empty = LiveState();

  final DayStats stats;
  final double speedMs;
  final double? altM;
  final MotionState state;
  final GpsQuality gps;
  final Segment? lastRun;
  final int? batteryEtaTs;
  final int? batteryPct;
  final int? heartRateBpm;
  final int? lastFixTs;

  LiveState copyWith({
    DayStats? stats, double? speedMs, double? altM, MotionState? state, GpsQuality? gps, Segment? lastRun,
    int? batteryEtaTs, int? batteryPct, int? heartRateBpm, int? lastFixTs,
  }) => LiveState(
        stats: stats ?? this.stats, speedMs: speedMs ?? this.speedMs, altM: altM ?? this.altM,
        state: state ?? this.state, gps: gps ?? this.gps, lastRun: lastRun ?? this.lastRun,
        batteryEtaTs: batteryEtaTs ?? this.batteryEtaTs, batteryPct: batteryPct ?? this.batteryPct,
        heartRateBpm: heartRateBpm ?? this.heartRateBpm, lastFixTs: lastFixTs ?? this.lastFixTs,
      );
}

class RecordingState {
  const RecordingState({this.status = RecordingStatus.idle, this.dayId, this.startedAt});
  static const idle = RecordingState();
  final RecordingStatus status;
  final String? dayId;
  final int? startedAt;
  bool get isRecording => status == RecordingStatus.recording;
}
