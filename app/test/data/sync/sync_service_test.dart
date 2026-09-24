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
  late FakeSyncApi api;
  late MemorySyncStore store;
  late List<Duration> slept;

  SyncService service({int? lastSyncAt}) {
    store = MemorySyncStore(lastSyncAt);
    return SyncService(
      repo: repo,
      api: api,
      store: store,
      sleep: (d) async => slept.add(d),
    );
  }

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
    api = FakeSyncApi();
    slept = [];
  });
  tearDown(() => db.close());

  test('push maps every DayStats field the backend stores', () async {
    await seedFinishedDay(repo);
    await service().pushDay('d1');

    expect(api.upserts, hasLength(1));
    final row = api.upserts.single;
    expect(row['id'], 'd1');
    expect(row['user_id'], 'u1');
    expect(row['season_key'], '2025/26');
    expect(row['started_at'], '2026-01-15T08:00:00.000Z');
    expect(row['resort_id'], 'kitzbuehel');
    expect(row['resort_name'], 'Kitzbühel');
    expect(row['run_count'], sampleStats.runCount);
    expect(row['lift_count'], sampleStats.liftCount);
    expect(row['drop_m'], sampleStats.dropM);
    expect(row['ascent_m'], sampleStats.ascentM);
    expect(row['ski_distance_m'], sampleStats.skiDistanceM);
    expect(row['lift_distance_m'], sampleStats.liftDistanceM);
    expect(row['max_speed_ms'], sampleStats.maxSpeedMs);
    expect(row['avg_ski_speed_ms'], sampleStats.avgSkiSpeedMs);
    expect(row['ski_ms'], sampleStats.skiMs);
    expect(row['lift_ms'], sampleStats.liftMs);
    expect(row['pause_ms'], sampleStats.pauseMs);
    expect(row['elapsed_ms'], sampleStats.elapsedMs);
    expect(row['max_alt_m'], sampleStats.maxAltM);
    expect(row['min_alt_m'], sampleStats.minAltM);
    expect(row['engine_version'], TrackingConfig.engineVersion);
    expect(row['has_barometer'], isTrue);
    expect(row['vehicle_flag'], isTrue);
    expect(row['deleted_at'], isNull);
    expect(row['device_updated_at'], isA<String>());
    // server-generated columns must never be written
    expect(row.containsKey('suspicious'), isFalse);
    expect(row.containsKey('updated_at'), isFalse);
    // pushed day is marked and leaves the outbox
    expect(await repo.outbox(), isEmpty);
    expect((await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle()).syncedAt, isNotNull);
  });

  test('push backs up the raw track and stores the path', () async {
    await seedFinishedDay(repo, points: samplePoints());
    await service().pushDay('d1');
    expect(api.uploads, ['d1']);
    expect(api.trackPaths['d1'], 'u1/d1.json.gz');
  });

  test('a day without points uploads nothing', () async {
    await seedFinishedDay(repo);
    await service().pushDay('d1');
    expect(api.uploads, isEmpty);
  });

  test('a soft-deleted day pushes a tombstone', () async {
    await seedFinishedDay(repo);
    await repo.softDeleteDay('d1');
    await service().syncNow();
    expect(api.upserts.last['deleted_at'], isA<String>());
    expect(api.uploads, isEmpty);
    expect(await repo.outbox(), isEmpty);
  });

  test('syncNow drains the outbox and then pulls', () async {
    await seedFinishedDay(repo, id: 'local');
    api.remoteDays = [remoteRow(id: 'remote', deviceUpdatedAt: sampleStartedAt + 90000000)];

    final s = service(lastSyncAt: sampleStartedAt);
    await s.syncNow();

    expect(api.upserts.single['id'], 'local');
    expect(api.fetchCursors, [sampleStartedAt]);
    expect(await store.lastSyncAt(), sampleStartedAt + 90000000);
    final pulled = await (db.select(db.days)..where((d) => d.id.equals('remote'))).getSingle();
    expect(pulled.resortName, 'Remote-Gebiet');
    expect(s.current.state, SyncState.idle);
    expect(s.current.pending, 0);
    // the pulled day must not bounce straight back to the backend
    expect(api.upserts, hasLength(1));
  });

  test('pull without rows keeps the cursor (no device-clock drift)', () async {
    final s = service(lastSyncAt: sampleStartedAt);
    await s.pullAll();
    expect(await store.lastSyncAt(), sampleStartedAt);
  });

  test('offline leaves the outbox intact and reports offline', () async {
    await seedFinishedDay(repo);
    api.offline = true;
    final s = service();
    await s.syncNow();

    expect(api.upserts, isEmpty);
    expect(await repo.outboxCount(), 1);
    expect((await repo.outbox()).single.attempts, 0, reason: 'offline is not a failed attempt');
    expect(s.current.state, SyncState.offline);
    expect(s.current.pending, 1);

    api.offline = false;
    await s.syncNow();
    expect(api.upserts, hasLength(1));
    expect(await repo.outbox(), isEmpty);
    expect(s.current.state, SyncState.idle);
  });

  test('a failing push backs off and stops after 3 attempts', () async {
    await seedFinishedDay(repo);
    api.failure = StateError('server said no');
    final s = service();

    for (var i = 0; i < 3; i++) {
      await s.syncNow();
    }
    expect((await repo.outbox()).single.attempts, 3);
    expect(slept, [const Duration(seconds: 1), const Duration(seconds: 2), const Duration(seconds: 4)]);

    expect((await repo.outbox()).single.lastError, contains('server said no'));

    api.failure = null;
    await s.syncNow();
    expect(api.upserts, isEmpty, reason: 'no fourth attempt');
    expect((await repo.outbox()).single.attempts, 3);
    // the pull still runs — one stuck day must not block the rest of the sync
    expect(api.fetchCursors, hasLength(1));
  });

  test('status stream seeds late listeners and reports pending work', () async {
    await seedFinishedDay(repo);
    final s = service();
    expect(await s.status.first, const SyncStatus());
    await s.syncNow();
    final seen = await s.status.first;
    expect(seen.state, SyncState.idle);
    expect(seen.pending, 0);
    await s.dispose();
  });

  test('without a signed-in user nothing is pushed', () async {
    await seedFinishedDay(repo);
    api.userId = null;
    final s = service();
    await s.syncNow();
    await s.pushDay('d1');
    await s.pullAll();
    expect(api.upserts, isEmpty);
    expect(api.fetchCursors, isEmpty);
    expect(await repo.outboxCount(), 1);
    expect(s.current.state, SyncState.idle);
  });

  test('without a backend the service is a no-op', () async {
    await seedFinishedDay(repo);
    final s = SyncService(repo: repo, api: null, store: MemorySyncStore());
    await s.syncNow();
    await s.pushDay('d1');
    expect(s.current.state, SyncState.idle);
    expect(await repo.outboxCount(), 1);
  });
}
