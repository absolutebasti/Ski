import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/data/db/database.dart';
import 'package:schwung/data/db/days_repository.dart';

import 'sync_fixtures.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
  });
  tearDown(() => db.close());

  Future<DayRow> row(String id) => (db.select(db.days)..where((d) => d.id.equals(id))).getSingle();

  test('inserts an unknown remote day', () async {
    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: sampleStartedAt + 90000000));
    expect(changed, isTrue);
    final r = await row('d1');
    expect(r.status, DayStatus.finished.dbValue);
    expect(r.resortName, 'Remote-Gebiet');
    expect(r.dropM, 5000);
    expect(r.totalDistanceM, 50000);
    expect(r.remoteUpdatedAt, sampleStartedAt + 90000000);
    expect(r.deletedAt, isNull);
  });

  test('never overwrites the day that is being recorded', () async {
    await repo.createActiveDay(id: 'd1', startedAt: sampleStartedAt, resortName: 'Lokal');
    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: DateTime.now().millisecondsSinceEpoch));
    expect(changed, isFalse);
    final r = await row('d1');
    expect(r.status, DayStatus.active.dbValue);
    expect(r.resortName, 'Lokal');
  });

  test('last writer wins: a newer remote row overwrites the local one', () async {
    await seedFinishedDay(repo);
    final local = await row('d1');
    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: local.updatedAt + 60000, dropM: 9999));
    expect(changed, isTrue);
    expect((await row('d1')).dropM, 9999);
  });

  test('last writer wins: an older remote row is ignored', () async {
    await seedFinishedDay(repo);
    final local = await row('d1');
    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: local.updatedAt - 60000, dropM: 1));
    expect(changed, isFalse);
    expect((await row('d1')).dropM, sampleStats.dropM);
  });

  test('keeps local-only fields the backend does not know', () async {
    await seedFinishedDay(repo);
    await repo.updateMapThumb('d1', '/tmp/thumb.png');
    final local = await row('d1');
    await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: local.updatedAt + 60000));
    final merged = await row('d1');
    expect(merged.mapThumbPath, '/tmp/thumb.png');
    expect(merged.acceptedFixes, local.acceptedFixes);
  });

  test('a remote tombstone soft-deletes locally without queueing a push', () async {
    await seedFinishedDay(repo);
    await repo.markSynced('d1', sampleStartedAt);
    final deletedAt = sampleStartedAt + 99000000;
    expect(await repo.softDeleteFromRemote('d1', remoteUpdatedAt: deletedAt), isTrue);
    expect((await row('d1')).deletedAt, isNotNull);
    expect(await repo.outbox(), isEmpty);
    expect(await repo.watchDays().first, isEmpty);
  });

  test('a remote tombstone leaves an active day alone', () async {
    await repo.createActiveDay(id: 'd1', startedAt: sampleStartedAt);
    expect(await repo.softDeleteFromRemote('d1'), isFalse);
    expect((await row('d1')).deletedAt, isNull);
  });

  test('a remote row with deleted_at lands as a tombstone', () async {
    final at = sampleStartedAt + 90000000;
    await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: at, deletedAt: at));
    expect((await row('d1')).deletedAt, at);
    expect(await repo.watchDays().first, isEmpty);
  });
}
