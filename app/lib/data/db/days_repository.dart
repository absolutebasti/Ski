import 'package:drift/drift.dart';

import '../../core/core.dart';
import 'database.dart';
import 'mappers.dart';

/// Single source of truth for days, segments and points.
class DaysRepository {
  DaysRepository(this.db);
  final AppDatabase db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> createActiveDay({required String id, required int startedAt, String? resortId, String? resortName}) async {
    final now = _now();
    await db.into(db.days).insert(DaysCompanion.insert(
          id: id, startedAt: startedAt, status: DayStatus.active.dbValue, resortId: Value(resortId),
          resortName: Value(resortName), engineVersion: const Value(TrackingConfig.engineVersion),
          createdAt: now, updatedAt: now,
        ));
  }

  Future<void> reopenDay(String id) => (db.update(db.days)..where((d) => d.id.equals(id))).write(
        DaysCompanion(status: Value(DayStatus.active.dbValue), endedAt: const Value(null), updatedAt: Value(_now())),
      );

  Future<void> setResort(String id, {required String? resortId, required String? resortName}) =>
      (db.update(db.days)..where((d) => d.id.equals(id))).write(
        DaysCompanion(resortId: Value(resortId), resortName: Value(resortName), updatedAt: Value(_now())),
      );

  /// Batch insert + running aggregates in one transaction (crash safety, PLAN §6).
  Future<void> appendPoints(String dayId, List<TrackPoint> points, {DayStats? stats, int? streamRestarts}) async {
    if (points.isEmpty && stats == null) return;
    await db.transaction(() async {
      if (points.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.points, points.map((p) => pointToCompanion(dayId, p))));
      }
      int? lastFix;
      for (final p in points) {
        if (p.accepted) lastFix = p.ts;
      }
      var c = DaysCompanion(updatedAt: Value(_now()));
      if (lastFix != null) c = c.copyWith(lastFixAt: Value(lastFix));
      if (stats != null) c = statsToCompanion(stats).copyWith(updatedAt: Value(_now()), lastFixAt: lastFix != null ? Value(lastFix) : const Value.absent());
      if (streamRestarts != null) c = c.copyWith(streamRestarts: Value(streamRestarts));
      await (db.update(db.days)..where((d) => d.id.equals(dayId))).write(c);
    });
  }

  Future<void> replaceSegments(String dayId, List<Segment> segments) async {
    await db.transaction(() async {
      await (db.delete(db.segments)..where((s) => s.dayId.equals(dayId))).go();
      if (segments.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.segments, segments.map(segmentToCompanion)));
      }
    });
  }

  Future<void> finishDay(String dayId, {required int endedAt, required DayStats stats, required List<Segment> segments, bool trackedOnWatch = false}) async {
    await db.transaction(() async {
      await (db.delete(db.segments)..where((s) => s.dayId.equals(dayId))).go();
      if (segments.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.segments, segments.map(segmentToCompanion)));
      }
      await (db.update(db.days)..where((d) => d.id.equals(dayId))).write(
        statsToCompanion(stats).copyWith(
          status: Value(DayStatus.finished.dbValue), endedAt: Value(endedAt), updatedAt: Value(_now()),
          trackedOnWatch: Value(trackedOnWatch), engineVersion: const Value(TrackingConfig.engineVersion),
        ),
      );
    });
  }

  Future<void> discardDay(String dayId) async {
    await db.transaction(() async {
      await (db.delete(db.points)..where((p) => p.dayId.equals(dayId))).go();
      await (db.delete(db.segments)..where((s) => s.dayId.equals(dayId))).go();
      await (db.delete(db.days)..where((d) => d.id.equals(dayId))).go();
    });
  }

  Future<DayRecord?> activeDay() async {
    final row = await (db.select(db.days)..where((d) => d.status.equals(DayStatus.active.dbValue) & d.deletedAt.isNull())..orderBy([(d) => OrderingTerm.desc(d.startedAt)])..limit(1)).getSingleOrNull();
    return row == null ? null : dayFromRow(row);
  }

  Future<DayRecord?> day(String id) async {
    final row = await (db.select(db.days)..where((d) => d.id.equals(id))).getSingleOrNull();
    return row == null ? null : dayFromRow(row);
  }

  /// Most recent finished day at [resortId] that ended within [window] (restart merge).
  Future<DayRecord?> recentFinishedDay({required String? resortId, required Duration window}) async {
    final since = _now() - window.inMilliseconds;
    final q = db.select(db.days)
      ..where((d) => d.status.equals(DayStatus.finished.dbValue) & d.deletedAt.isNull() & d.endedAt.isBiggerOrEqualValue(since))
      ..orderBy([(d) => OrderingTerm.desc(d.endedAt)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    if (row == null) return null;
    if (resortId != null && row.resortId != null && row.resortId != resortId) return null;
    return dayFromRow(row);
  }

  Future<List<Segment>> segmentsOf(String dayId) async {
    final rows = await (db.select(db.segments)..where((s) => s.dayId.equals(dayId))..orderBy([(s) => OrderingTerm.asc(s.idx)])).get();
    return rows.map(segmentFromRow).toList();
  }

  Future<List<TrackPoint>> pointsRaw(String dayId) async {
    final rows = await (db.select(db.points)..where((p) => p.dayId.equals(dayId))..orderBy([(p) => OrderingTerm.asc(p.ts)])).get();
    return rows.map(pointFromRow).toList();
  }

  /// Points after [afterTs] (for resume: rebuild the engine from the tail).
  Future<List<TrackPoint>> pointsAfter(String dayId, int afterTs) async {
    final rows = await (db.select(db.points)..where((p) => p.dayId.equals(dayId) & p.ts.isBiggerThanValue(afterTs))..orderBy([(p) => OrderingTerm.asc(p.ts)])).get();
    return rows.map(pointFromRow).toList();
  }

  Future<DayDetail?> dayDetail(String id, {int maxPoints = 5000}) async {
    final d = await day(id);
    if (d == null) return null;
    final segs = await segmentsOf(id);
    final rows = await (db.select(db.points)..where((p) => p.dayId.equals(id) & p.accepted.equals(true))..orderBy([(p) => OrderingTerm.asc(p.ts)])).get();
    List<PointRow> picked = rows;
    if (rows.length > maxPoints) {
      final step = rows.length / maxPoints;
      picked = [for (var i = 0; i < maxPoints; i++) rows[(i * step).floor()]];
      if (picked.last != rows.last) picked.add(rows.last);
    }
    return DayDetail(day: d, segments: segs, points: picked.map(pointFromRow).toList());
  }

  Future<void> softDeleteDay(String id) => (db.update(db.days)..where((d) => d.id.equals(id))).write(
        DaysCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
      );

  Future<void> deleteAll() async {
    await db.transaction(() async {
      await db.delete(db.points).go();
      await db.delete(db.segments).go();
      await db.delete(db.days).go();
    });
  }

  Future<void> updateMapThumb(String dayId, String path) =>
      (db.update(db.days)..where((d) => d.id.equals(dayId))).write(DaysCompanion(mapThumbPath: Value(path), updatedAt: Value(_now())));

  Future<void> setWeather(String dayId, WeatherSnapshot w) => (db.update(db.days)..where((d) => d.id.equals(dayId)))
      .write(DaysCompanion(weatherJson: Value(_encode(w.toJson())), updatedAt: Value(_now())));

  Future<void> setStreamRestarts(String dayId, int n) =>
      (db.update(db.days)..where((d) => d.id.equals(dayId))).write(DaysCompanion(streamRestarts: Value(n)));

  SimpleSelectStatement<$DaysTable, DayRow> _finishedQuery() => db.select(db.days)
    ..where((d) => d.status.equals(DayStatus.finished.dbValue) & d.deletedAt.isNull())
    ..orderBy([(d) => OrderingTerm.desc(d.startedAt)]);

  Stream<List<DaySummary>> watchDays() => _finishedQuery().watch().map((rows) {
        double maxSpeed = 0, maxDrop = 0;
        for (final r in rows) {
          if (r.maxSpeedMs > maxSpeed) maxSpeed = r.maxSpeedMs;
          if (r.dropM > maxDrop) maxDrop = r.dropM;
        }
        return [
          for (final r in rows)
            DaySummary(
              id: r.id, startedAt: r.startedAt, endedAt: r.endedAt, resortName: r.resortName,
              mapThumbPath: r.mapThumbPath, stats: statsFromRow(r),
              isTopSpeedPb: r.maxSpeedMs > 0 && r.maxSpeedMs == maxSpeed,
              isBiggestDayPb: r.dropM > 0 && r.dropM == maxDrop,
            ),
        ];
      });

  Stream<List<SeasonTotals>> watchSeasonTotals() => _finishedQuery().watch().map((rows) {
        final by = <String, List<DayRow>>{};
        for (final r in rows) {
          by.putIfAbsent(seasonKeyFromMs(r.startedAt), () => []).add(r);
        }
        final out = by.entries.map((e) {
          var runs = 0;
          double drop = 0, dist = 0, max = 0;
          for (final r in e.value) {
            runs += r.runCount;
            drop += r.dropM;
            dist += r.skiDistanceM;
            if (r.maxSpeedMs > max) max = r.maxSpeedMs;
          }
          return SeasonTotals(seasonKey: e.key, dayCount: e.value.length, runCount: runs, dropM: drop, skiDistanceM: dist, maxSpeedMs: max);
        }).toList()
          ..sort((a, b) => b.seasonKey.compareTo(a.seasonKey));
        return out;
      });

  Stream<PersonalBests> watchPersonalBests() => _finishedQuery().watch().asyncMap((rows) async {
        DayRow? speedDay, dropDay;
        for (final r in rows) {
          if (r.maxSpeedMs > 0 && (speedDay == null || r.maxSpeedMs > speedDay.maxSpeedMs)) speedDay = r;
          if (r.dropM > 0 && (dropDay == null || r.dropM > dropDay.dropM)) dropDay = r;
        }
        final longest = await (db.select(db.segments)
              ..where((s) => s.kind.equals(SegmentKind.run.dbValue))
              ..orderBy([(s) => OrderingTerm.desc(s.dropM)])
              ..limit(1))
            .getSingleOrNull();
        final deleted = rows.map((r) => r.id).toSet();
        return PersonalBests(
          topSpeedMs: speedDay?.maxSpeedMs, topSpeedDayId: speedDay?.id,
          biggestDayDropM: dropDay?.dropM, biggestDayId: dropDay?.id,
          longestRunDropM: longest != null && deleted.contains(longest.dayId) ? longest.dropM : null,
          longestRunDayId: longest != null && deleted.contains(longest.dayId) ? longest.dayId : null,
        );
      });

  static String _encode(Map<String, Object?> m) => _json(m);
}

String _json(Map<String, Object?> m) {
  // tiny JSON encoder without importing dart:convert in the interface file
  final sb = StringBuffer('{');
  var first = true;
  m.forEach((k, v) {
    if (!first) sb.write(',');
    first = false;
    sb.write('"$k":');
    if (v == null) {
      sb.write('null');
    } else if (v is num || v is bool) {
      sb.write(v);
    } else {
      sb.write('"${v.toString().replaceAll('"', '\\"')}"');
    }
  });
  sb.write('}');
  return sb.toString();
}
