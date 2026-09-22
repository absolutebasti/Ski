import 'day_stats.dart';
import 'enums.dart';
import 'segment.dart';
import 'track_point.dart';

/// The `days` row without points.
class DayRecord {
  const DayRecord({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.stats,
    this.endedAt,
    this.resortId,
    this.resortName,
    this.lastFixAt,
    this.engineVersion = 1,
    this.streamRestarts = 0,
    this.weatherJson,
    this.mapThumbPath,
    this.trackedOnWatch = false,
  });

  final String id;
  final int startedAt;
  final int? endedAt;
  final DayStatus status;
  final String? resortId;
  final String? resortName;
  final int? lastFixAt;
  final int engineVersion;
  final int streamRestarts;
  final String? weatherJson;
  final String? mapThumbPath;
  final bool trackedOnWatch;
  final DayStats stats;

  DateTime get startedAtLocal => DateTime.fromMillisecondsSinceEpoch(startedAt);
}

/// What the Tage list needs — never loads points.
class DaySummary {
  const DaySummary({
    required this.id,
    required this.startedAt,
    required this.stats,
    this.endedAt,
    this.resortName,
    this.mapThumbPath,
    this.isTopSpeedPb = false,
    this.isBiggestDayPb = false,
  });

  final String id;
  final int startedAt;
  final int? endedAt;
  final String? resortName;
  final String? mapThumbPath;
  final DayStats stats;
  final bool isTopSpeedPb;
  final bool isBiggestDayPb;
}

/// Everything the Tag detail screen renders.
class DayDetail {
  const DayDetail({required this.day, required this.segments, required this.points});
  final DayRecord day;
  final List<Segment> segments;
  /// Accepted points in ts order (may be downsampled to ≤ 5 000 for rendering).
  final List<TrackPoint> points;

  Iterable<Segment> get runs => segments.where((s) => s.kind == SegmentKind.run);
  Iterable<Segment> get lifts => segments.where((s) => s.kind == SegmentKind.lift);
}

class SeasonTotals {
  const SeasonTotals({
    required this.seasonKey,
    this.dayCount = 0,
    this.runCount = 0,
    this.dropM = 0,
    this.skiDistanceM = 0,
    this.maxSpeedMs = 0,
  });
  final String seasonKey;
  final int dayCount;
  final int runCount;
  final double dropM;
  final double skiDistanceM;
  final double maxSpeedMs;
}

class PersonalBests {
  const PersonalBests({this.topSpeedMs, this.topSpeedDayId, this.biggestDayDropM, this.biggestDayId, this.longestRunDropM, this.longestRunDayId});
  final double? topSpeedMs;
  final String? topSpeedDayId;
  final double? biggestDayDropM;
  final String? biggestDayId;
  final double? longestRunDropM;
  final String? longestRunDayId;
}
