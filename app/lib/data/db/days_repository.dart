import 'package:drift/drift.dart';

import '../../core/core.dart';
import 'database.dart';
import 'mappers.dart';

/// Pending backend operation for one day.
enum SyncOp { upsert, delete }

extension SyncOpX on SyncOp {
  static SyncOp fromDb(String v) => SyncOp.values.firstWhere((e) => e.name == v, orElse: () => SyncOp.upsert);
}

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

  /// 'Skigebiet ändern' on a finished day (UX-DAYS): rewrites the resort and
  /// re-queues the day so the backend row follows. Null clears to free terrain.
  Future<void> updateResort(String dayId, String? resortId, String? resortName) => db.transaction(() async {
        await setResort(dayId, resortId: resortId, resortName: resortName);
        await _enqueue(dayId, SyncOp.upsert);
      });

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
          // The track is final now: whatever backup exists (a day that was
          // reopened) is stale, the next push uploads again.
          trackPath: const Value(null),
        ),
      );
      await _enqueue(dayId, SyncOp.upsert);
    });
  }

  /// Drops the points after [ts] (trailing idle trimmed at an auto-end).
  Future<void> deletePointsAfter(String dayId, int ts) =>
      (db.delete(db.points)..where((p) => p.dayId.equals(dayId) & p.ts.isBiggerThanValue(ts))).go();

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
  Future<DayRecord?> recentFinishedDay({required int nowMs, required Duration window, String? resortId}) async {
    final since = nowMs - window.inMilliseconds;
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

  /// Hides the day and queues the tombstone. Points and segments go right
  /// away (SYNC-HARDENING): a deleted day must not keep megabytes of track on
  /// the phone; the aggregates stay for the backend round-trip.
  Future<void> softDeleteDay(String id) => db.transaction(() async {
        final now = _now();
        await (db.update(db.days)..where((d) => d.id.equals(id))).write(
          DaysCompanion(deletedAt: Value(now), updatedAt: Value(now), trackPath: const Value(null)),
        );
        await (db.delete(db.points)..where((p) => p.dayId.equals(id))).go();
        await (db.delete(db.segments)..where((s) => s.dayId.equals(id))).go();
        await _enqueue(id, SyncOp.delete);
      });

  /// Raw point count of a day (any accepted state) — cheap check for 'Spur laden'.
  Future<int> pointCount(String dayId) async {
    final n = db.points.id.count();
    final q = db.selectOnly(db.points)
      ..addColumns([n])
      ..where(db.points.dayId.equals(dayId));
    return (await q.getSingle()).read(n) ?? 0;
  }

  /// Writes a downloaded track back under a pulled day (SYNC-HARDENING):
  /// replaces points and segments and rewrites the DayStats columns with the
  /// recomputed values. Neither bumps `updatedAt` nor queues a push — the
  /// backend row stays the truth for the aggregates.
  Future<void> restoreTrack(String dayId, {required List<TrackPoint> points, required List<Segment> segments, required DayStats stats}) async {
    await db.transaction(() async {
      await (db.delete(db.points)..where((p) => p.dayId.equals(dayId))).go();
      await (db.delete(db.segments)..where((s) => s.dayId.equals(dayId))).go();
      if (points.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.points, points.map((p) => pointToCompanion(dayId, p))));
      }
      if (segments.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.segments, segments.map(segmentToCompanion)));
      }
      int? lastFix;
      for (final p in points) {
        if (p.accepted) lastFix = p.ts;
      }
      await (db.update(db.days)..where((d) => d.id.equals(dayId))).write(
        statsToCompanion(stats).copyWith(lastFixAt: lastFix != null ? Value(lastFix) : const Value.absent()),
      );
    });
  }

  Future<void> deleteAll() async {
    await db.transaction(() async {
      await db.delete(db.points).go();
      await db.delete(db.segments).go();
      await db.delete(db.days).go();
    });
  }

  /// Thumbnail and weather live on this phone only. Neither is an edit:
  /// `updatedAt` is what travels as `device_updated_at` and decides the
  /// two-device merge (SYNC-2), so a local-only write must not make this row
  /// look newer than a real edit from another device.
  Future<void> updateMapThumb(String dayId, String path) =>
      (db.update(db.days)..where((d) => d.id.equals(dayId))).write(DaysCompanion(mapThumbPath: Value(path)));

  Future<void> setWeather(String dayId, WeatherSnapshot w) => (db.update(db.days)..where((d) => d.id.equals(dayId)))
      .write(DaysCompanion(weatherJson: Value(_encode(w.toJson()))));

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
                                                                    resortId: r.resortId,
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


  // ---------------------------------------------------------------- sync (WP-14)

  /// Queues a backend write for [dayId]. The newest op for a day wins, so a
  /// finish followed by a delete leaves exactly one 'delete' entry.
  Future<void> enqueue(String dayId, SyncOp op) => db.transaction(() => _enqueue(dayId, op));

  Future<void> _enqueue(String dayId, SyncOp op) async {
    await (db.delete(db.syncOutbox)..where((o) => o.dayId.equals(dayId))).go();
    await db.into(db.syncOutbox).insert(SyncOutboxCompanion.insert(dayId: dayId, op: op.name, createdAt: _now()));
  }

  /// Pending backend writes, oldest first.
  Future<List<SyncOutboxRow>> outbox() =>
      (db.select(db.syncOutbox)..orderBy([(o) => OrderingTerm.asc(o.createdAt), (o) => OrderingTerm.asc(o.id)])).get();

  Future<int> outboxCount() async => (await outbox()).length;

  /// Marks a day as pushed and drops its outbox entries — only those with
  /// `id <= upToOutboxId` when given (SYNC-2): an edit that was queued while
  /// the push was in flight gets a higher id and must survive. Null drops
  /// every entry of the day.
  Future<void> markSynced(String dayId, int remoteUpdatedAt, {int? upToOutboxId}) => db.transaction(() async {
        await (db.update(db.days)..where((d) => d.id.equals(dayId))).write(
          DaysCompanion(syncedAt: Value(_now()), remoteUpdatedAt: Value(remoteUpdatedAt)),
        );
        final q = db.delete(db.syncOutbox)..where((o) => o.dayId.equals(dayId));
        if (upToOutboxId != null) q.where((o) => o.id.isSmallerOrEqualValue(upToOutboxId));
        await q.go();
      });

  /// Highest outbox id queued for [dayId], null when nothing is queued. Read
  /// before a push so [markSynced] leaves later entries alone.
  Future<int?> latestOutboxId(String dayId) async {
    final maxId = db.syncOutbox.id.max();
    final q = db.selectOnly(db.syncOutbox)
      ..addColumns([maxId])
      ..where(db.syncOutbox.dayId.equals(dayId));
    return (await q.getSingle()).read(maxId);
  }

  /// Local copy of `days.track_path`, null when unknown or without a backup.
  Future<String?> trackPathOf(String dayId) async =>
      (await (db.select(db.days)..where((d) => d.id.equals(dayId))).getSingleOrNull())?.trackPath;

  /// Remembers the storage path of the uploaded backup (SYNC-2). Not an edit:
  /// `updatedAt` stays, nothing is queued. With [ifUpdatedAt] the path is only
  /// kept when the row is still the one that was uploaded.
  Future<void> setTrackPath(String dayId, String? path, {int? ifUpdatedAt}) {
    final q = db.update(db.days)..where((d) => d.id.equals(dayId));
    if (ifUpdatedAt != null) q.where((d) => d.updatedAt.equals(ifUpdatedAt));
    return q.write(DaysCompanion(trackPath: Value(path)));
  }

  /// One failed attempt; returns the new count (0 when the entry is gone).
  /// The entry stays queued — SyncService spaces retries with a backoff.
  Future<int> bumpAttempt(int outboxId, String error) async {
    final row = await (db.select(db.syncOutbox)..where((o) => o.id.equals(outboxId))).getSingleOrNull();
    if (row == null) return 0;
    final attempts = row.attempts + 1;
    await (db.update(db.syncOutbox)..where((o) => o.id.equals(outboxId)))
        .write(SyncOutboxCompanion(attempts: Value(attempts), lastError: Value(_trim(error))));
    return attempts;
  }

  Future<void> dropFromOutbox(int outboxId) => (db.delete(db.syncOutbox)..where((o) => o.id.equals(outboxId))).go();

  /// App start / sign-in: every entry gets a fresh run of retries.
  Future<void> resetAttempts() => db.update(db.syncOutbox).write(const SyncOutboxCompanion(attempts: Value(0)));

  /// Re-queues every finished day that never reached the backend (or changed
  /// since its last push). Used when a Konto confirms taking over the local
  /// days recorded under another Konto.
  Future<int> requeueUnsynced() => db.transaction(() async {
        final rows = await (db.select(db.days)..where((d) => d.status.equals(DayStatus.finished.dbValue))).get();
        var n = 0;
        for (final r in rows) {
          final synced = r.syncedAt;
          if (synced != null && r.updatedAt <= synced) continue;
          await _enqueue(r.id, r.deletedAt == null ? SyncOp.upsert : SyncOp.delete);
          n++;
        }
        return n;
      });

  Future<void> clearOutbox() => db.delete(db.syncOutbox).go();

  /// Account deleted: no day is on any server any more.
  Future<void> resetSyncMarks() => db.update(db.days).write(
        const DaysCompanion(syncedAt: Value(null), remoteUpdatedAt: Value(null), trackPath: Value(null)),
      );

  /// Merges a remote `days` row (snake_case keys, as returned by the backend).
  ///
  /// Never touches an active local day and applies last-edit-wins on
  /// `device_updated_at` (remote) vs. `updatedAt` (local): the older edit
  /// loses, whichever device made it and however long it was offline. When
  /// the remote edit is strictly newer, a pending push of the local edit is
  /// dropped — it lost. A row this phone already holds in exactly that
  /// version (its own push coming back, or the last row of the previous pull)
  /// is left alone. Returns true when the local row changed.
  Future<bool> upsertFromRemote(Map<String, Object?> remote) => db.transaction(() => _upsertFromRemote(remote));

  Future<bool> _upsertFromRemote(Map<String, Object?> remote) async {
    final id = remote['id'] as String?;
    if (id == null || id.isEmpty) return false;
    final remoteUpdated = _ts(remote['device_updated_at']) ?? _ts(remote['updated_at']) ?? 0;
    final existing = await (db.select(db.days)..where((d) => d.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      // A day that is being recorded right now is always the local truth.
      if (existing.status == DayStatus.active.dbValue) return false;
      if (existing.updatedAt > remoteUpdated) return false;
      if (existing.updatedAt == remoteUpdated && existing.remoteUpdatedAt == remoteUpdated) return false;
      if (existing.updatedAt < remoteUpdated) {
        await (db.delete(db.syncOutbox)..where((o) => o.dayId.equals(id))).go();
      }
    }
    final remoteTrack = remote['track_path'] as String?;
    final deletedAt = _ts(remote['deleted_at']);
    final startedAt = _ts(remote['started_at']) ?? existing?.startedAt ?? remoteUpdated;
    final skiDistanceM = _d(remote['ski_distance_m']);
    final liftDistanceM = _d(remote['lift_distance_m']);
    final companion = DaysCompanion.insert(
      id: id,
      startedAt: startedAt,
      status: DayStatus.finished.dbValue,
      createdAt: existing?.createdAt ?? (_ts(remote['created_at']) ?? remoteUpdated),
      updatedAt: remoteUpdated,
      endedAt: Value(_ts(remote['ended_at'])),
      resortId: Value(remote['resort_id'] as String?),
      resortName: Value(remote['resort_name'] as String?),
      engineVersion: Value(_i(remote['engine_version'], fallback: existing?.engineVersion ?? 1)),
      mapThumbPath: Value(existing?.mapThumbPath),
      weatherJson: Value(existing?.weatherJson),
      lastFixAt: Value(existing?.lastFixAt),
      trackedOnWatch: Value(existing?.trackedOnWatch ?? false),
      elapsedMs: Value(_i(remote['elapsed_ms'])),
      skiMs: Value(_i(remote['ski_ms'])),
      liftMs: Value(_i(remote['lift_ms'])),
      pauseMs: Value(_i(remote['pause_ms'])),
      signalLossMs: Value(existing?.signalLossMs ?? 0),
      otherMs: Value(existing?.otherMs ?? 0),
      runCount: Value(_i(remote['run_count'])),
      liftCount: Value(_i(remote['lift_count'])),
      dropM: Value(_d(remote['drop_m'])),
      ascentM: Value(_d(remote['ascent_m'])),
      skiDistanceM: Value(skiDistanceM),
      liftDistanceM: Value(liftDistanceM),
      totalDistanceM: Value(skiDistanceM + liftDistanceM),
      maxSpeedMs: Value(_d(remote['max_speed_ms'])),
      avgSkiSpeedMs: Value(_d(remote['avg_ski_speed_ms'])),
      maxAltM: Value(_dn(remote['max_alt_m'])),
      minAltM: Value(_dn(remote['min_alt_m'])),
      acceptedFixes: Value(existing?.acceptedFixes ?? 0),
      rejectedFixes: Value(existing?.rejectedFixes ?? 0),
      hasBarometer: Value(remote['has_barometer'] == true),
      vehicleFlag: Value(remote['vehicle_flag'] == true),
      avgHeartRateBpm: Value(existing?.avgHeartRateBpm),
      maxHeartRateBpm: Value(existing?.maxHeartRateBpm),
      deletedAt: Value(deletedAt),
      syncedAt: Value(_now()),
      remoteUpdatedAt: Value(remoteUpdated),
      trackPath: Value(remoteTrack != null && remoteTrack.isNotEmpty ? remoteTrack : existing?.trackPath),
    );
    await db.into(db.days).insertOnConflictUpdate(companion);
    return true;
  }

  /// Remote tombstone: hide the day locally without queueing another push.
  /// Points and segments go too (SYNC-2) — same as a local delete — and a
  /// pending push of the day is dropped, the server already has the tombstone.
  /// A delete always wins, whatever the timestamps say: it was confirmed on
  /// the other device and its track backup is gone. Only the day that is
  /// being recorded right now is left alone. False when nothing changed.
  Future<bool> softDeleteFromRemote(String id, {int? remoteUpdatedAt}) async {
    final existing = await (db.select(db.days)..where((d) => d.id.equals(id))).getSingleOrNull();
    if (existing == null) return false;
    if (existing.status == DayStatus.active.dbValue) return false;
    // The same tombstone again (last row of the previous pull): already applied.
    if (existing.deletedAt != null && remoteUpdatedAt != null && existing.remoteUpdatedAt == remoteUpdatedAt) return false;
    final now = _now();
    await db.transaction(() async {
      await (db.update(db.days)..where((d) => d.id.equals(id))).write(DaysCompanion(
        deletedAt: Value(existing.deletedAt ?? (remoteUpdatedAt ?? now)),
        updatedAt: Value(remoteUpdatedAt ?? now),
        syncedAt: Value(now),
        remoteUpdatedAt: Value(remoteUpdatedAt ?? now),
        trackPath: const Value(null),
      ));
      await (db.delete(db.points)..where((p) => p.dayId.equals(id))).go();
      await (db.delete(db.segments)..where((s) => s.dayId.equals(id))).go();
      await (db.delete(db.syncOutbox)..where((o) => o.dayId.equals(id))).go();
    });
    return true;
  }

  static String _trim(String s) => s.length <= 500 ? s : s.substring(0, 500);

  /// Accepts ms epoch ints and ISO-8601 strings (Postgres `timestamptz`).
  static int? _ts(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is String) {
      final t = DateTime.tryParse(v);
      if (t != null) return t.millisecondsSinceEpoch;
      return int.tryParse(v);
    }
    return null;
  }

  static double _d(Object? v) => _dn(v) ?? 0;

  static double? _dn(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int _i(Object? v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

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
