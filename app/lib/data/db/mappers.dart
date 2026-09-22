import 'package:drift/drift.dart';

import '../../core/core.dart';
import 'database.dart';

DayStats statsFromRow(DayRow r) => DayStats(
      elapsedMs: r.elapsedMs, skiMs: r.skiMs, liftMs: r.liftMs, pauseMs: r.pauseMs, signalLossMs: r.signalLossMs,
      otherMs: r.otherMs, runCount: r.runCount, liftCount: r.liftCount, dropM: r.dropM, ascentM: r.ascentM,
      skiDistanceM: r.skiDistanceM, liftDistanceM: r.liftDistanceM, totalDistanceM: r.totalDistanceM,
      maxSpeedMs: r.maxSpeedMs, avgSkiSpeedMs: r.avgSkiSpeedMs, maxAltM: r.maxAltM, minAltM: r.minAltM,
      maxSpeedSegmentId: r.maxSpeedSegmentId, longestRunSegmentId: r.longestRunSegmentId,
      acceptedFixes: r.acceptedFixes, rejectedFixes: r.rejectedFixes, hasBarometer: r.hasBarometer,
      vehicleFlag: r.vehicleFlag, avgHeartRateBpm: r.avgHeartRateBpm, maxHeartRateBpm: r.maxHeartRateBpm,
    );

DayRecord dayFromRow(DayRow r) => DayRecord(
      id: r.id, startedAt: r.startedAt, endedAt: r.endedAt, status: DayStatusX.fromDb(r.status),
      resortId: r.resortId, resortName: r.resortName, lastFixAt: r.lastFixAt, engineVersion: r.engineVersion,
      streamRestarts: r.streamRestarts, weatherJson: r.weatherJson, mapThumbPath: r.mapThumbPath,
      trackedOnWatch: r.trackedOnWatch, stats: statsFromRow(r),
    );

DaysCompanion statsToCompanion(DayStats s) => DaysCompanion(
      elapsedMs: Value(s.elapsedMs), skiMs: Value(s.skiMs), liftMs: Value(s.liftMs), pauseMs: Value(s.pauseMs),
      signalLossMs: Value(s.signalLossMs), otherMs: Value(s.otherMs), runCount: Value(s.runCount),
      liftCount: Value(s.liftCount), dropM: Value(s.dropM), ascentM: Value(s.ascentM),
      skiDistanceM: Value(s.skiDistanceM), liftDistanceM: Value(s.liftDistanceM),
      totalDistanceM: Value(s.totalDistanceM), maxSpeedMs: Value(s.maxSpeedMs), avgSkiSpeedMs: Value(s.avgSkiSpeedMs),
      maxAltM: Value(s.maxAltM), minAltM: Value(s.minAltM), maxSpeedSegmentId: Value(s.maxSpeedSegmentId),
      longestRunSegmentId: Value(s.longestRunSegmentId), acceptedFixes: Value(s.acceptedFixes),
      rejectedFixes: Value(s.rejectedFixes), hasBarometer: Value(s.hasBarometer), vehicleFlag: Value(s.vehicleFlag),
      avgHeartRateBpm: Value(s.avgHeartRateBpm), maxHeartRateBpm: Value(s.maxHeartRateBpm),
    );

Segment segmentFromRow(SegmentRow r) => Segment(
      id: r.id, dayId: r.dayId, kind: SegmentKindX.fromDb(r.kind), idx: r.idx, runNumber: r.runNumber,
      startTs: r.startTs, endTs: r.endTs, startAltM: r.startAltM, endAltM: r.endAltM, dropM: r.dropM,
      distanceM: r.distanceM, movingMs: r.movingMs, maxSpeedMs: r.maxSpeedMs, maxSpeedAtTs: r.maxSpeedAtTs,
      avgSpeedMs: r.avgSpeedMs, avgGradientPct: r.avgGradientPct, steepest100mPct: r.steepest100mPct,
      startPointTs: r.startPointTs, endPointTs: r.endPointTs, flags: r.flags, pisteName: r.pisteName,
      pisteOsmId: r.pisteOsmId, liftName: r.liftName,
    );

SegmentsCompanion segmentToCompanion(Segment s) => SegmentsCompanion.insert(
      id: s.id, dayId: s.dayId, kind: s.kind.dbValue, idx: s.idx, runNumber: Value(s.runNumber),
      startTs: s.startTs, endTs: s.endTs, startAltM: Value(s.startAltM), endAltM: Value(s.endAltM),
      dropM: Value(s.dropM), distanceM: Value(s.distanceM), movingMs: Value(s.movingMs),
      maxSpeedMs: Value(s.maxSpeedMs), maxSpeedAtTs: Value(s.maxSpeedAtTs), avgSpeedMs: Value(s.avgSpeedMs),
      avgGradientPct: Value(s.avgGradientPct), steepest100mPct: Value(s.steepest100mPct),
      startPointTs: Value(s.startPointTs), endPointTs: Value(s.endPointTs), flags: Value(s.flags),
      pisteName: Value(s.pisteName), pisteOsmId: Value(s.pisteOsmId), liftName: Value(s.liftName),
    );

TrackPoint pointFromRow(PointRow r) => TrackPoint(
      ts: r.ts, lat: r.lat, lon: r.lon, hAccM: r.hAccM, gpsAltM: r.gpsAltM, vAccM: r.vAccM, speedMs: r.speedMs,
      speedAccMs: r.speedAccMs, courseDeg: r.courseDeg, pressureHpa: r.pressureHpa, fusedAltM: r.fusedAltM,
      accepted: r.accepted,
      rejectReason: RejectReason.values.firstWhere((e) => e.name == r.rejectReason, orElse: () => RejectReason.none),
      state: MotionState.values.firstWhere((e) => e.name == r.state, orElse: () => MotionState.unknown),
      heartRateBpm: r.heartRateBpm,
    );

PointsCompanion pointToCompanion(String dayId, TrackPoint p) => PointsCompanion.insert(
      dayId: dayId, ts: p.ts, lat: Value(p.lat), lon: Value(p.lon), hAccM: Value(p.hAccM), gpsAltM: Value(p.gpsAltM),
      vAccM: Value(p.vAccM), speedMs: Value(p.speedMs), speedAccMs: Value(p.speedAccMs), courseDeg: Value(p.courseDeg),
      pressureHpa: Value(p.pressureHpa), fusedAltM: Value(p.fusedAltM), accepted: Value(p.accepted),
      rejectReason: Value(p.rejectReason.name), state: Value(p.state.name), heartRateBpm: Value(p.heartRateBpm),
    );
