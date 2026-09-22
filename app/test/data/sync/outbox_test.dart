import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/data/db/database.dart';
import 'package:dropline/data/db/days_repository.dart';

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

  test('softDeleteDay replaces the pending upsert with a delete', () async {
    await seedFinishedDay(repo);
    await repo.softDeleteDay('d1');
    final queue = await repo.outbox();
    expect(queue, hasLength(1));
    expect(queue.single.op, 'delete');
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

  test('bumpAttempt counts failures and stores the error', () async {
    await seedFinishedDay(repo);
    final entry = (await repo.outbox()).single;
    await repo.bumpAttempt(entry.id, 'boom');
    await repo.bumpAttempt(entry.id, 'boom again');
    final after = (await repo.outbox()).single;
    expect(after.attempts, 2);
    expect(after.lastError, 'boom again');
  });

  test('outbox survives several days, oldest first', () async {
    await seedFinishedDay(repo, id: 'a', startedAt: sampleStartedAt);
    await seedFinishedDay(repo, id: 'b', startedAt: sampleStartedAt + 86400000);
    expect((await repo.outbox()).map((e) => e.dayId), ['a', 'b']);
  });
}
