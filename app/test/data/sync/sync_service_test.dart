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
  late int clock;

  SyncService service({int? lastSyncAt, CountryResolver? countryFor}) {
    store = MemorySyncStore(cursors: lastSyncAt == null ? null : {'u1': lastSyncAt}, lastUserId: 'u1');
    return SyncService(
      repo: repo,
      api: api,
      store: store,
      now: () => clock,
      countryFor: countryFor,
    );
  }

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
    api = FakeSyncApi();
    clock = DateTime.now().millisecondsSinceEpoch;
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

  test('push fills country_code from the resolver, null without one', () async {
    await seedFinishedDay(repo);
    final asked = <String?>[];
    await service(countryFor: (resortId) {
      asked.add(resortId);
      return resortId == 'kitzbuehel' ? 'AT' : 'DE';
    }).pushDay('d1');
    expect(asked, ['kitzbuehel']);
    expect(api.upserts.single['country_code'], 'AT');

    await seedFinishedDay(repo, id: 'd2', resortId: null, resortName: null);
    await service(countryFor: (resortId) => resortId == null ? 'de' : 'AT').pushDay('d2');
    expect(api.upserts.last['country_code'], 'DE', reason: 'unknown resort → the rider\'s own country, upper-cased');

    await seedFinishedDay(repo, id: 'd3');
    await service().pushDay('d3');
    expect(api.upserts.last['country_code'], isNull);
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
    expect(await store.lastSyncAt('u1'), sampleStartedAt + 90000000);
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
    expect(await store.lastSyncAt('u1'), sampleStartedAt);
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

  test('a failing push backs off exponentially and is retried once due', () async {
    await seedFinishedDay(repo);
    api.upsertFailure = StateError('server said no');
    final s = service();

    await s.syncNow();
    var entry = (await repo.outbox()).single;
    expect(entry.attempts, 1);
    expect(entry.lastError, contains('server said no'));
    expect(s.nextAttemptAt(entry.id), clock + 1000);

    // not due yet → skipped, no attempt bump, the pull still runs
    await s.syncNow();
    expect((await repo.outbox()).single.attempts, 1);
    expect(api.fetchCursors, hasLength(2), reason: 'one stuck day must not block the rest of the sync');

    clock += 1000;
    await s.syncNow();
    entry = (await repo.outbox()).single;
    expect(entry.attempts, 2);
    expect(s.nextAttemptAt(entry.id), clock + 2000);

    clock += 2000;
    await s.syncNow();
    entry = (await repo.outbox()).single;
    expect(entry.attempts, 3);
    expect(s.nextAttemptAt(entry.id), clock + 4000);

    // 4th failure still schedules a retry — no hard cap
    api.upsertFailure = null;
    clock += 4000;
    await s.syncNow();
    expect(api.upserts, hasLength(1), reason: 'retried after the backoff instead of skipped forever');
    expect(await repo.outbox(), isEmpty);
    expect(s.nextAttemptAt(entry.id), isNull);
  });

  test('backoff doubles and caps at one hour', () {
    expect(SyncService.backoffFor(0), const Duration(seconds: 1));
    expect(SyncService.backoffFor(1), const Duration(seconds: 1));
    expect(SyncService.backoffFor(2), const Duration(seconds: 2));
    expect(SyncService.backoffFor(3), const Duration(seconds: 4));
    expect(SyncService.backoffFor(12), const Duration(seconds: 2048));
    expect(SyncService.backoffFor(13), const Duration(hours: 1));
    expect(SyncService.backoffFor(40), const Duration(hours: 1));
  });

  test('resetAttempts on start makes a stuck entry due at once', () async {
    await seedFinishedDay(repo);
    api.upsertFailure = StateError('500');
    final s = service();
    for (var i = 0; i < 3; i++) {
      if (i > 0) clock += SyncService.backoffFor(i).inMilliseconds;
      await s.syncNow();
    }
    final entry = (await repo.outbox()).single;
    expect(entry.attempts, 3);
    expect(s.nextAttemptAt(entry.id), greaterThan(clock));

    api.upsertFailure = null;
    await s.syncFresh();
    expect((await repo.outbox()), isEmpty);
    expect(api.upserts, hasLength(1));
  });

  test('resetAttempts zeroes the persisted counter', () async {
    await seedFinishedDay(repo);
    final id = (await repo.outbox()).single.id;
    await repo.bumpAttempt(id, 'x');
    await repo.bumpAttempt(id, 'x');
    await service().resetAttempts();
    expect((await repo.outbox()).single.attempts, 0);
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
