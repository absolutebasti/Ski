import 'enums.dart';

/// A run, lift ride, stop, "other" movement or signal-loss gap inside a day.
class Segment {
  const Segment({
    required this.id,
    required this.dayId,
    required this.kind,
    required this.idx,
    required this.startTs,
    required this.endTs,
    this.runNumber,
    this.startAltM = 0,
    this.endAltM = 0,
    this.dropM = 0,
    this.distanceM = 0,
    this.movingMs = 0,
    this.maxSpeedMs = 0,
    this.maxSpeedAtTs,
    this.avgSpeedMs = 0,
    this.avgGradientPct = 0,
    this.steepest100mPct,
    this.startPointTs,
    this.endPointTs,
    this.flags = 0,
    this.pisteName,
    this.pisteOsmId,
    this.liftName,
  });

  final String id;
  final String dayId;
  final SegmentKind kind;
  /// Order within the day, 0-based.
  final int idx;
  /// 1-based run counter, only for runs.
  final int? runNumber;
  final int startTs;
  final int endTs;
  final double startAltM;
  final double endAltM;
  /// Positive metres descended (runs) or ascended (lifts).
  final double dropM;
  final double distanceM;
  final int movingMs;
  final double maxSpeedMs;
  final int? maxSpeedAtTs;
  final double avgSpeedMs;
  final double avgGradientPct;
  final double? steepest100mPct;
  final int? startPointTs;
  final int? endPointTs;
  /// Bit flags: 1 = vehicle, 2 = gpsOnlyAltitude, 4 = merged.
  final int flags;
  final String? pisteName;
  final String? pisteOsmId;
  final String? liftName;

  int get durationMs => endTs - startTs;
  bool get isVehicle => flags & 1 != 0;

  Segment copyWith({
    SegmentKind? kind, int? idx, int? runNumber, int? startTs, int? endTs, double? startAltM, double? endAltM,
    double? dropM, double? distanceM, int? movingMs, double? maxSpeedMs, int? maxSpeedAtTs, double? avgSpeedMs,
    double? avgGradientPct, double? steepest100mPct, int? flags, String? pisteName, String? liftName,
  }) => Segment(
        id: id, dayId: dayId, kind: kind ?? this.kind, idx: idx ?? this.idx, runNumber: runNumber ?? this.runNumber,
        startTs: startTs ?? this.startTs, endTs: endTs ?? this.endTs, startAltM: startAltM ?? this.startAltM,
        endAltM: endAltM ?? this.endAltM, dropM: dropM ?? this.dropM, distanceM: distanceM ?? this.distanceM,
        movingMs: movingMs ?? this.movingMs, maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
        maxSpeedAtTs: maxSpeedAtTs ?? this.maxSpeedAtTs, avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
        avgGradientPct: avgGradientPct ?? this.avgGradientPct, steepest100mPct: steepest100mPct ?? this.steepest100mPct,
        startPointTs: startPointTs, endPointTs: endPointTs, flags: flags ?? this.flags,
        pisteName: pisteName ?? this.pisteName, pisteOsmId: pisteOsmId, liftName: liftName ?? this.liftName,
      );
}
