/// Aggregates of one ski day. Stored on the `days` row; recomputed by the engine.
class DayStats {
  const DayStats({
    this.elapsedMs = 0,
    this.skiMs = 0,
    this.liftMs = 0,
    this.pauseMs = 0,
    this.signalLossMs = 0,
    this.otherMs = 0,
    this.runCount = 0,
    this.liftCount = 0,
    this.dropM = 0,
    this.ascentM = 0,
    this.skiDistanceM = 0,
    this.liftDistanceM = 0,
    this.totalDistanceM = 0,
    this.maxSpeedMs = 0,
    this.avgSkiSpeedMs = 0,
    this.maxAltM,
    this.minAltM,
    this.maxSpeedSegmentId,
    this.longestRunSegmentId,
    this.acceptedFixes = 0,
    this.rejectedFixes = 0,
    this.hasBarometer = false,
    this.vehicleFlag = false,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
  });

  static const empty = DayStats();

  final int elapsedMs;
  final int skiMs;
  final int liftMs;
  final int pauseMs;
  final int signalLossMs;
  final int otherMs;
  final int runCount;
  final int liftCount;
  /// Σ run drops, metres.
  final double dropM;
  final double ascentM;
  final double skiDistanceM;
  final double liftDistanceM;
  final double totalDistanceM;
  final double maxSpeedMs;
  final double avgSkiSpeedMs;
  final double? maxAltM;
  final double? minAltM;
  final String? maxSpeedSegmentId;
  final String? longestRunSegmentId;
  final int acceptedFixes;
  final int rejectedFixes;
  final bool hasBarometer;
  final bool vehicleFlag;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;

  DayStats copyWith({
    int? elapsedMs, int? skiMs, int? liftMs, int? pauseMs, int? signalLossMs, int? otherMs, int? runCount,
    int? liftCount, double? dropM, double? ascentM, double? skiDistanceM, double? liftDistanceM,
    double? totalDistanceM, double? maxSpeedMs, double? avgSkiSpeedMs, double? maxAltM, double? minAltM,
    String? maxSpeedSegmentId, String? longestRunSegmentId, int? acceptedFixes, int? rejectedFixes,
    bool? hasBarometer, bool? vehicleFlag, int? avgHeartRateBpm, int? maxHeartRateBpm,
  }) => DayStats(
        elapsedMs: elapsedMs ?? this.elapsedMs, skiMs: skiMs ?? this.skiMs, liftMs: liftMs ?? this.liftMs,
        pauseMs: pauseMs ?? this.pauseMs, signalLossMs: signalLossMs ?? this.signalLossMs,
        otherMs: otherMs ?? this.otherMs, runCount: runCount ?? this.runCount, liftCount: liftCount ?? this.liftCount,
        dropM: dropM ?? this.dropM, ascentM: ascentM ?? this.ascentM, skiDistanceM: skiDistanceM ?? this.skiDistanceM,
        liftDistanceM: liftDistanceM ?? this.liftDistanceM, totalDistanceM: totalDistanceM ?? this.totalDistanceM,
        maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs, avgSkiSpeedMs: avgSkiSpeedMs ?? this.avgSkiSpeedMs,
        maxAltM: maxAltM ?? this.maxAltM, minAltM: minAltM ?? this.minAltM,
        maxSpeedSegmentId: maxSpeedSegmentId ?? this.maxSpeedSegmentId,
        longestRunSegmentId: longestRunSegmentId ?? this.longestRunSegmentId,
        acceptedFixes: acceptedFixes ?? this.acceptedFixes, rejectedFixes: rejectedFixes ?? this.rejectedFixes,
        hasBarometer: hasBarometer ?? this.hasBarometer, vehicleFlag: vehicleFlag ?? this.vehicleFlag,
        avgHeartRateBpm: avgHeartRateBpm ?? this.avgHeartRateBpm, maxHeartRateBpm: maxHeartRateBpm ?? this.maxHeartRateBpm,
      );
}
