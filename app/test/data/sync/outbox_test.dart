import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';

import 'sync_fixtures.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
  });
  tearDown(() => db.close());

  test('finishDay queues an upsert', () async {
    await seedFinishedDay(repo);
    final queue = await repo.outbox();
    expect(queue, hasLength(1));
    expect(queue.single.dayId, 'd1');
    expect(queue.single.op, 'upsert');
    expect(queue.single.attempts, 0);
  });

  test('softDeleteDay replaces the pending upsert with a delete and drops the track', () async {
    await seedFinishedDay(repo, points: samplePoints());
    await repo.finishDay('d1', endedAt: sampleStartedAt + 1, stats: sampleStats, segments: [
      Segment(id: 's1', dayId: 'd1', kind: SegmentKind.run, idx: 0, startTs: sampleStartedAt, endTs: sampleStartedAt + 1000),
    ]);
    expect(await repo.pointCount('d1'), 5);
    expect(await repo.segmentsOf('d1'), hasLength(1));

    await repo.softDeleteDay('d1');
    final queue = await repo.outbox();
    expect(queue, hasLength(1));
    expect(queue.single.op, 'delete');
    expect(await repo.pointCount('d1'), 0);
    expect(await repo.pointsRaw('d1'), isEmpty);
    expect(await repo.segmentsOf('d1'), isEmpty);
    // the aggregates row stays for the tombstone push
    final row = await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(row.runCount, sampleStats.runCount);
  });

  test('enqueue keeps one entry per day and markSynced clears it', () async {
    await seedFinishedDay(repo);
    await repo.enqueue('d1', SyncOp.upsert);
    await repo.enqueue('d1', SyncOp.upsert);
    expect(await repo.outboxCount(), 1);

    await repo.markSynced('d1', 1700000000000);
    expect(await repo.outbox(), isEmpty);
    final row = await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle();
    expect(row.remoteUpdatedAt, 1700000000000);
    expect(row.syncedAt, isNotNull);
  });

  test('bumpAttempt counts failures, stores the error and resetAttempts clears it', () async {
    await seedFinishedDay(repo);
    final entry = (await repo.outbox()).single;
    expect(await repo.bumpAttempt(entry.id, 'boom'), 1);
    expect(await repo.bumpAttempt(entry.id, 'boom again'), 2);
    final after = (await repo.outbox()).single;
    expect(after.attempts, 2);
    expect(after.lastError, 'boom again');
    expect(await repo.bumpAttempt(9999, 'gone'), 0);

    await repo.resetAttempts();
    expect((await repo.outbox()).single.attempts, 0);
  });

  test('updateResort re-queues a synced day', () async {
    await seedFinishedDay(repo);
    await repo.markSynced('d1', 1);
    expect(await repo.outbox(), isEmpty);
    await repo.updateResort('d1', 'skiwelt', 'SkiWelt');
    final queue = await repo.outbox();
    expect(queue.single.op, 'upsert');
    expect((await repo.day('d1'))?.resortId, 'skiwelt');
  });

  test('requeueUnsynced queues never-pushed and changed days only', () async {
    await seedFinishedDay(repo, id: 'never');
    await seedFinishedDay(repo, id: 'pushed', startedAt: sampleStartedAt + 1);
    await seedFinishedDay(repo, id: 'changed', startedAt: sampleStartedAt + 2);
    await seedFinishedDay(repo, id: 'gone', startedAt: sampleStartedAt + 3);
    await repo.markSynced('pushed', 1);
    await repo.markSynced('changed', 1);
    await repo.markSynced('gone', 1);
    await (db.update(db.days)..where((d) => d.id.equals('changed'))).write(const DaysCompanion(updatedAt: Value(9999999999999)));
    await repo.softDeleteDay('gone');
    await repo.markSynced('gone', 2);
    await repo.clearOutbox();

    expect(await repo.requeueUnsynced(), 2);
    final queue = await repo.outbox();
    expect(queue.map((e) => e.dayId).toSet(), {'never', 'changed'});
  });

  test('outbox survives several days, oldest first', () async {
    await seedFinishedDay(repo, id: 'a', startedAt: sampleStartedAt);
    await seedFinishedDay(repo, id: 'b', startedAt: sampleStartedAt + 86400000);
    expect((await repo.outbox()).map((e) => e.dayId), ['a', 'b']);
  });
}
