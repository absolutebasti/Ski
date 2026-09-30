import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/sync/sync_service.dart';
import 'package:slopetrack/data/sync/sync_store.dart';

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

  // ---------------------------------------------------------------- SYNC-2

  test('an older offline edit loses against a newer online edit — and is not pushed any more', () async {
    await seedFinishedDay(repo);
    await repo.markSynced('d1', sampleStartedAt);
    // offline on the chairlift: the resort is corrected here …
    await repo.updateResort('d1', 'skiwelt', 'SkiWelt (offline)');
    final offlineEdit = sampleStartedAt + 1000;
    await stampUpdatedAt(db, 'd1', offlineEdit);
    expect(await repo.outboxCount(), 1);

    // … and a minute later on the other phone, which is online.
    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: offlineEdit + 60000, resortName: 'Kitzbühel (online)'));
    expect(changed, isTrue);
    final merged = await row('d1');
    expect(merged.resortName, 'Kitzbühel (online)');
    expect(merged.updatedAt, offlineEdit + 60000);
    expect(await repo.outbox(), isEmpty, reason: 'the edit that lost must not overwrite the winner on the server');
  });

  test('a newer offline edit wins against an older online edit and stays queued', () async {
    await seedFinishedDay(repo);
    await repo.updateResort('d1', 'skiwelt', 'SkiWelt (offline)');
    final offlineEdit = sampleStartedAt + 120000;
    await stampUpdatedAt(db, 'd1', offlineEdit);

    final changed = await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: offlineEdit - 60000, resortName: 'Kitzbühel (online)'));
    expect(changed, isFalse);
    expect((await row('d1')).resortName, 'SkiWelt (offline)');
    expect(await repo.outboxCount(), 1);
  });

  test('the version this phone already holds is left alone (own push coming back)', () async {
    await seedFinishedDay(repo, points: samplePoints());
    final local = await row('d1');
    await repo.markSynced('d1', local.updatedAt);
    final before = await row('d1');
    // same device_updated_at, but the backend knows less than the phone
    expect(await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: local.updatedAt, dropM: 1)), isFalse);
    final after = await row('d1');
    expect(after.dropM, sampleStats.dropM);
    expect(after.syncedAt, before.syncedAt, reason: 'not even a write — no rebuild of every list');
  });

  test('a tombstone removes points, segments and a pending push', () async {
    await seedFinishedDay(repo, points: samplePoints());
    await repo.replaceSegments('d1', [
      Segment(id: 's1', dayId: 'd1', kind: SegmentKind.run, idx: 0, startTs: sampleStartedAt, endTs: sampleStartedAt + 1000),
    ]);
    await repo.setTrackPath('d1', 'u1/d1.json.gz');
    expect(await repo.pointCount('d1'), 5);
    expect(await repo.outboxCount(), 1);

    final at = sampleStartedAt + 99000000;
    expect(await repo.softDeleteFromRemote('d1', remoteUpdatedAt: at), isTrue);
    expect(await repo.pointCount('d1'), 0);
    expect(await repo.pointsRaw('d1'), isEmpty);
    expect(await repo.segmentsOf('d1'), isEmpty);
    expect(await repo.outbox(), isEmpty);
    final r = await row('d1');
    expect(r.deletedAt, at);
    expect(r.trackPath, isNull, reason: 'the backup went with the delete');
    expect(r.runCount, sampleStats.runCount, reason: 'the aggregates row stays as the tombstone');

    // the same tombstone again (next pull) changes nothing
    expect(await repo.softDeleteFromRemote('d1', remoteUpdatedAt: at), isFalse);
  });

  test('thumbnail and weather are local-only: they do not make the row look edited', () async {
    await seedFinishedDay(repo);
    await stampUpdatedAt(db, 'd1', sampleStartedAt + 1000);
    await repo.updateMapThumb('d1', '/tmp/thumb.png');
    await repo.setWeather('d1', const WeatherSnapshot(fetchedAt: sampleStartedAt + 500000, tempBaseC: -4, wmoCode: 71));
    final r = await row('d1');
    expect(r.updatedAt, sampleStartedAt + 1000);
    expect(r.mapThumbPath, '/tmp/thumb.png');
    // so an edit from the other phone a second later still wins
    expect(await repo.upsertFromRemote(remoteRow(deviceUpdatedAt: sampleStartedAt + 2000, resortName: 'Neu')), isTrue);
    expect((await row('d1')).mapThumbPath, '/tmp/thumb.png');
  });

  group('two phones, one backend', () {
    late AppDatabase dbB;
    late DaysRepository repoB;
    late FakeSyncApi server;
    late SyncService phoneA;
    late SyncService phoneB;
    var clock = sampleStartedAt + 86400000;

    Future<DayRow> rowB(String id) => (dbB.select(dbB.days)..where((d) => d.id.equals(id))).getSingle();
    Map<String, Object?> onServer(String id) => server.remoteDays.singleWhere((r) => r['id'] == id);

    setUp(() async {
      dbB = memoryDb();
      repoB = DaysRepository(dbB);
      server = FakeSyncApi(serverMode: true);
      phoneA = SyncService(repo: repo, api: server, store: MemorySyncStore(), now: () => clock);
      phoneB = SyncService(repo: repoB, api: server, store: MemorySyncStore(), now: () => clock);
      // A records the day and syncs; B pulls it.
      await seedFinishedDay(repo);
      await stampUpdatedAt(db, 'd1', sampleStartedAt + 1000);
      await phoneA.syncNow();
      await phoneB.syncNow();
      expect((await rowB('d1')).resortName, 'Kitzbühel');
    });
    tearDown(() => dbB.close());

    test('A edits offline first, B edits online later: B wins on the backend and on both phones', () async {
      await repo.updateResort('d1', 'skiwelt', 'SkiWelt (A, offline)');
      await stampUpdatedAt(db, 'd1', sampleStartedAt + 5000);
      await repoB.updateResort('d1', 'saalbach', 'Saalbach (B, online)');
      await stampUpdatedAt(dbB, 'd1', sampleStartedAt + 9000);
      await phoneB.syncNow();
      expect(onServer('d1')['resort_name'], 'Saalbach (B, online)');

      // A is back in the valley three days later
      clock += const Duration(days: 3).inMilliseconds;
      final pushesBefore = server.upsertCalls;
      await phoneA.syncNow();
      expect(server.upsertCalls, pushesBefore, reason: 'A\'s older edit is never sent');
      expect(onServer('d1')['resort_name'], 'Saalbach (B, online)');
      expect((await row('d1')).resortName, 'Saalbach (B, online)');
      expect(await repo.outbox(), isEmpty);
      expect(phoneA.current.state, SyncState.idle);

      await phoneB.syncNow();
      expect((await rowB('d1')).resortName, 'Saalbach (B, online)');
    });

    test('A edits offline last: A wins although B was pushed first', () async {
      await repoB.updateResort('d1', 'saalbach', 'Saalbach (B, online)');
      await stampUpdatedAt(dbB, 'd1', sampleStartedAt + 5000);
      await phoneB.syncNow();
      await repo.updateResort('d1', 'skiwelt', 'SkiWelt (A, offline)');
      await stampUpdatedAt(db, 'd1', sampleStartedAt + 9000);

      clock += const Duration(days: 3).inMilliseconds;
      await phoneA.syncNow();
      expect(onServer('d1')['resort_name'], 'SkiWelt (A, offline)');
      expect(remoteTsOf(onServer('d1')['device_updated_at']), sampleStartedAt + 9000, reason: 'the edit time, not the push time');
      await phoneB.syncNow();
      expect((await rowB('d1')).resortName, 'SkiWelt (A, offline)');
      expect(await repoB.outbox(), isEmpty);
    });

    test('a delete on B takes the track off A', () async {
      await repo.appendPoints('d1', samplePoints());
      expect(await repo.pointCount('d1'), 5);
      await repoB.softDeleteDay('d1');
      await phoneB.syncNow();
      expect(onServer('d1')['deleted_at'], isNotNull);

      await phoneA.syncNow();
      expect(await repo.pointCount('d1'), 0);
      expect((await row('d1')).deletedAt, isNotNull);
      expect(await repo.watchDays().first, isEmpty);
    });

    test('the own tombstone coming back is not applied a second time', () async {
      await repoB.softDeleteDay('d1');
      await phoneB.syncNow();
      final before = await rowB('d1');
      expect(before.deletedAt, isNotNull);
      // the next pull brings B's own tombstone back
      await phoneB.syncNow();
      final after = await rowB('d1');
      expect(after.syncedAt, before.syncedAt, reason: 'no rewrite');
      expect(after.updatedAt, before.updatedAt, reason: 'the edit time stays the device time');
    });

    test('both phones settle: a second round sends and changes nothing', () async {
      await repoB.updateResort('d1', 'saalbach', 'Saalbach');
      await phoneB.syncNow();
      await phoneA.syncNow();
      final calls = server.upsertCalls;
      final a = await row('d1');
      await phoneA.syncNow();
      await phoneB.syncNow();
      await phoneA.syncNow();
      expect(server.upsertCalls, calls, reason: 'no ping-pong');
      expect((await row('d1')).syncedAt, a.syncedAt, reason: 'the row that comes back is not rewritten');
    });
  });

  group('keyset paging', () {
    late FakeSyncApi api;

    setUp(() => api = FakeSyncApi());

    SyncService service({int pageSize = 3}) =>
        SyncService(repo: repo, api: api, store: MemorySyncStore(), now: () => sampleStartedAt, pageSize: pageSize);

    test('every row arrives although one of them changes in the middle of the pull', () async {
      api.remoteDays = [for (var i = 0; i < 9; i++) remoteRow(id: 'r$i', deviceUpdatedAt: sampleStartedAt + i * 1000)];
      // After page 1 (r0 r1 r2) another phone edits r1: its updated_at jumps to
      // the end. With offset paging the window would slide — r3 moves to
      // position 2 and `offset 3` skips it for good.
      api.afterFetch = (page) {
        if (page != 1) return;
        final i = api.remoteDays.indexWhere((r) => r['id'] == 'r1');
        api.remoteDays[i] = remoteRow(id: 'r1', deviceUpdatedAt: sampleStartedAt + 60000, resortName: 'Geändert');
      };
      final s = service();
      await s.pullAll();

      final rows = await db.select(db.days).get();
      expect(rows.map((r) => r.id).toSet(), {for (var i = 0; i < 9; i++) 'r$i'}, reason: 'r3 is there');
      // r1 comes back on the fourth page (after r8), which is short → done.
      expect(api.fetchKeys.map((k) => k?.id), [null, 'r2', 'r5', 'r8']);
      expect((await row('r1')).resortName, 'Geändert', reason: 'the changed row comes round again at the end');
      expect(s.current.lastSyncAt, sampleStartedAt + 60000);
    });

    test('rows with the same updated_at are split across pages by id', () async {
      // one bulk write on the server: five rows, one timestamp
      api.remoteDays = [
        for (final id in ['e', 'c', 'a', 'd', 'b']) remoteRow(id: id, deviceUpdatedAt: sampleStartedAt + 1000),
      ];
      await service(pageSize: 2).pullAll();
      expect((await db.select(db.days).get()).map((r) => r.id).toSet(), {'a', 'b', 'c', 'd', 'e'});
      expect(api.fetchKeys.map((k) => k?.id), [null, 'b', 'd']);
    });

    test('the next pull continues after the cursor', () async {
      api.remoteDays = [for (var i = 0; i < 4; i++) remoteRow(id: 'r$i', deviceUpdatedAt: sampleStartedAt + i * 1000)];
      final store = MemorySyncStore();
      final s = SyncService(repo: repo, api: api, store: store, now: () => sampleStartedAt, pageSize: 3);
      await s.pullAll();
      expect(store.cursors['u1'], sampleStartedAt + 3000);
      api.remoteDays.add(remoteRow(id: 'r9', deviceUpdatedAt: sampleStartedAt + 9000));
      api.fetchCursors.clear();
      await s.pullAll();
      expect(api.fetchCursors, [sampleStartedAt + 3000]);
      expect(await db.select(db.days).get(), hasLength(5));
    });
  });
}

int? remoteTsOf(Object? v) => v is String ? DateTime.tryParse(v)?.millisecondsSinceEpoch : null;
