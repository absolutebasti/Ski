import 'dart:convert';
import 'dart:io';

import '../../core/core.dart';
import 'gpx_exporter.dart';

/// gzip JSON `{ day, segments, points[], engineVersion, device }` for the
/// hidden Diagnose section (docs/PLAN.md §3, §9). Raw points, rejected ones
/// included — the point is to replay the engine offline.
class DiagnosticsBundle {
  const DiagnosticsBundle._();

  static const int formatVersion = 1;

  static String fileName(String dayId) => 'slopetrack-diag-${GpxExporter.shortId(dayId)}.json.gz';

  static Map<String, Object?> toJson({
    required DayRecord day,
    required List<Segment> segments,
    required List<TrackPoint> points,
    String? device,
  }) =>
      {
        'format': formatVersion,
        'app': 'slopetrack',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'engineVersion': TrackingConfig.engineVersion,
        'device': device ?? Platform.operatingSystemVersion,
        'day': dayToJson(day),
        'segments': [for (final s in segments) segmentToJson(s)],
        'points': [for (final p in points) p.toJson()],
      };

  static List<int> encode(Map<String, Object?> json) => gzip.encode(utf8.encode(jsonEncode(json)));

  static Map<String, Object?> decode(List<int> bytes) => jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;

  static Map<String, Object?> dayToJson(DayRecord d) => {
        'id': d.id,
        'startedAt': d.startedAt,
        'endedAt': d.endedAt,
        'status': d.status.name,
        'resortId': d.resortId,
        'resortName': d.resortName,
        'lastFixAt': d.lastFixAt,
        'engineVersion': d.engineVersion,
        'streamRestarts': d.streamRestarts,
        'weatherJson': d.weatherJson,
        'mapThumbPath': d.mapThumbPath,
        'trackedOnWatch': d.trackedOnWatch,
        'stats': statsToJson(d.stats),
      };

  static Map<String, Object?> statsToJson(DayStats s) => {
        'elapsedMs': s.elapsedMs, 'skiMs': s.skiMs, 'liftMs': s.liftMs, 'pauseMs': s.pauseMs,
        'signalLossMs': s.signalLossMs, 'otherMs': s.otherMs, 'runCount': s.runCount, 'liftCount': s.liftCount,
        'dropM': s.dropM, 'ascentM': s.ascentM, 'skiDistanceM': s.skiDistanceM, 'liftDistanceM': s.liftDistanceM,
        'totalDistanceM': s.totalDistanceM, 'maxSpeedMs': s.maxSpeedMs, 'avgSkiSpeedMs': s.avgSkiSpeedMs,
        'maxAltM': s.maxAltM, 'minAltM': s.minAltM, 'maxSpeedSegmentId': s.maxSpeedSegmentId,
        'longestRunSegmentId': s.longestRunSegmentId, 'acceptedFixes': s.acceptedFixes,
        'rejectedFixes': s.rejectedFixes, 'hasBarometer': s.hasBarometer, 'vehicleFlag': s.vehicleFlag,
        'avgHeartRateBpm': s.avgHeartRateBpm, 'maxHeartRateBpm': s.maxHeartRateBpm,
      };

  static Map<String, Object?> segmentToJson(Segment s) => {
        'id': s.id, 'dayId': s.dayId, 'kind': s.kind.name, 'idx': s.idx, 'runNumber': s.runNumber,
        'startTs': s.startTs, 'endTs': s.endTs, 'startAltM': s.startAltM, 'endAltM': s.endAltM,
        'dropM': s.dropM, 'distanceM': s.distanceM, 'movingMs': s.movingMs, 'maxSpeedMs': s.maxSpeedMs,
        'maxSpeedAtTs': s.maxSpeedAtTs, 'avgSpeedMs': s.avgSpeedMs, 'avgGradientPct': s.avgGradientPct,
        'steepest100mPct': s.steepest100mPct, 'startPointTs': s.startPointTs, 'endPointTs': s.endPointTs,
        'flags': s.flags, 'pisteName': s.pisteName, 'pisteOsmId': s.pisteOsmId, 'liftName': s.liftName,
      };
}
