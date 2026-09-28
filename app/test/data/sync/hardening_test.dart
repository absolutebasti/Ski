import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/sync/sync_service.dart';
import 'package:slopetrack/data/sync/sync_store.dart';
import 'package:slopetrack/data/sync/track_restore.dart';
import 'package:slopetrack/features/share/diagnostics_bundle.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import 'sync_fixtures.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;
  late FakeSyncApi api;
  late MemorySyncStore store;
  late int clock;

  SyncService service({MemorySyncStore? withStore}) {
    store = withStore ?? MemorySyncStore();
    return SyncService(repo: repo, api: api, store: store, now: () => clock);
  }

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
    api = FakeSyncApi();
    clock = DateTime.now().millisecondsSinceEpoch;
  });
  tearDown(() => db.close());

  group('401', () {
    test('a 401 refreshes the session once and retries the push', () async {
      await seedFinishedDay(repo);
      api.failure = const AuthException('JWT expired', statusCode: '401');
      api.onRefresh = () => api.failure = null;
      final s = service();
      await s.syncNow();

      expect(api.refreshCalls, 1);
      expect(api.upserts, hasLength(1));
      expect(await repo.outbox(), isEmpty);
      expect(s.current.state, SyncState.idle);
      expect(s.current.needsSignIn, isFalse);
    });

    test('a second 401 yields error(needsSignIn) and no attempt bump', () async {
      await seedFinishedDay(repo);
      api.failure = PostgrestException(message: 'JWT expired', code: 'PGRST301');
      final s = service();
      final seen = <SyncStatus>[];
      final sub = s.status.listen(seen.add);
      await s.syncNow();
      await pumpEventQueue();
      await sub.cancel();

      expect(api.refreshCalls, 1);
      expect(api.upserts, isEmpty);
      expect(api.fetchCursors, isEmpty, reason: 'no pull without a session');
      expect(s.current.state, SyncState.error);
      expect(s.current.needsSignIn, isTrue);
      expect(s.current.pending, 1);
      expect(seen.last.needsSignIn, isTrue);
      final entry = (await repo.outbox()).single;
      expect(entry.attempts, 0);
      expect(s.nextAttemptAt(entry.id), isNull);
    });

    test('a failed refresh yields needsSignIn as well', () async {
      await seedFinishedDay(repo);
      api.failure = const AuthException('invalid token', statusCode: '401');
      api.refreshResult = false;
      final s = service();
      await s.syncNow();
      expect(api.refreshCalls, 1);
      expect(s.current.needsSignIn, isTrue);
      expect((await repo.outbox()).single.attempts, 0);
    });

    test('a 401 on pull is handled the same way', () async {
      api.failure = const AuthException('JWT expired', statusCode: '401');
      final s = service();
      await s.syncNow();
      expect(api.refreshCalls, 1);
      expect(api.fetchCursors, hasLength(2), reason: 'first try + one retry after the refresh');
      expect(s.current.needsSignIn, isTrue);
    });

    test('the next successful sync clears needsSignIn', () async {
      await seedFinishedDay(repo);
      api.failure = const AuthException('JWT expired', statusCode: '401');
      final s = service();
      await s.syncNow();
      expect(s.current.needsSignIn, isTrue);
      api.failure = null;
      await s.syncNow();
      expect(s.current.needsSignIn, isFalse);
      expect(s.current.state, SyncState.idle);
      expect(await repo.outbox(), isEmpty);
    });
  });

  group('cursor per user', () {
    test('switching A → B starts B at epoch and keeps A\'s cursor', () async {
      api.remoteDays = [remoteRow(id: 'a1', deviceUpdatedAt: sampleStartedAt + 1000)];
      final s = service();
      await s.syncNow();
      expect(store.cursors['u1'], sampleStartedAt + 1000);
      expect(await store.lastUserId(), 'u1');

      api.userId = 'u2';
      api.remoteDays = [remoteRow(id: 'b1', deviceUpdatedAt: sampleStartedAt + 500)];
      api.fetchCursors.clear();
      await s.syncNow();
      expect(api.fetchCursors, [null], reason: 'B has never synced on this device');
      expect(store.cursors['u2'], sampleStartedAt + 500);
      expect(store.cursors['u1'], sampleStartedAt + 1000, reason: 'A\'s cursor is untouched');
      expect(s.current.lastSyncAt, sampleStartedAt + 500);

      api.userId = 'u1';
      api.fetchCursors.clear();
      await s.syncNow();
      expect(api.fetchCursors, [sampleStartedAt + 1000], reason: 'A resumes where it left off');
    });

    test('A\'s unsynced outbox entries are not pushed under B by default', () async {
      final s = service();
      await s.syncNow(); // binds the device to u1
      api.offline = true;
      await seedFinishedDay(repo, id: 'local');
      await s.syncNow();
      expect(await repo.outboxCount(), 1);

      api.offline = false;
      api.userId = 'u2';
      await s.syncNow();
      expect(api.upserts, isEmpty, reason: 'the day stays local');
      expect(await repo.outbox(), isEmpty, reason: 'entry parked — re-queued only on explicit confirm');
      expect(await repo.day('local'), isNotNull, reason: 'local data untouched');
      expect(await store.lastUserId(), 'u2');
    });

    test('days recorded while signed out go to the first Konto', () async {
      await seedFinishedDay(repo, id: 'local');
      final s = service();
      await s.syncNow();
      expect(api.upserts.single['user_id'], 'u1');
    });

    test('with the confirm flag the entries follow the new Konto', () async {
      final s = service(withStore: MemorySyncStore(lastUserId: 'u1', migrateOutbox: true));
      await seedFinishedDay(repo, id: 'local');
      api.userId = 'u2';
      await s.syncNow();
      expect(api.upserts.single['user_id'], 'u2');
    });

    test('migrateLocalDays re-queues and pushes under the current Konto', () async {
      final s = service();
      await s.syncNow();
      api.offline = true;
      await seedFinishedDay(repo, id: 'local');
      await s.syncNow();
      api.offline = false;
      api.userId = 'u2';
      await s.syncNow();
      expect(api.upserts, isEmpty);

      await s.migrateLocalDays();
      expect(api.upserts.single['id'], 'local');
      expect(api.upserts.single['user_id'], 'u2');
      expect(await store.migrateOutboxOnUserChange(), isTrue);
    });
  });

  group('pagination', () {
    test('1200 rows pull all three pages and set the cursor to the last row', () async {
      api.remoteDays = [
        for (var i = 0; i < 1200; i++) remoteRow(id: 'r$i', deviceUpdatedAt: sampleStartedAt + i * 1000),
      ];
      final s = service();
      await s.syncNow();
      expect(api.fetchOffsets, [0, 500, 1000]);
      expect(api.fetchCursors, [null, null, null], reason: 'every page uses the cursor from before the pull');
      expect(store.cursors['u1'], sampleStartedAt + 1199 * 1000);
      final n = await (db.select(db.days)).get();
      expect(n, hasLength(1200));
    });

    test('exactly one full page fetches a second, empty one', () async {
      api.remoteDays = [
        for (var i = 0; i < 500; i++) remoteRow(id: 'r$i', deviceUpdatedAt: sampleStartedAt + i * 1000),
      ];
      await service().syncNow();
      expect(api.fetchOffsets, [0, 500]);
    });

    test('a smaller page size is honoured', () async {
      api.remoteDays = [for (var i = 0; i < 7; i++) remoteRow(id: 'r$i', deviceUpdatedAt: sampleStartedAt + i)];
      final s = SyncService(repo: repo, api: api, store: MemorySyncStore(), now: () => clock, pageSize: 3);
      await s.pullAll();
      expect(api.fetchOffsets, [0, 3, 6]);
      expect((await (db.select(db.days)).get()), hasLength(7));
    });
  });

  group('track', () {
    test('pushDelete pushes the tombstone and removes the storage object', () async {
      await seedFinishedDay(repo, points: samplePoints());
      final s = service();
      await s.pushDay('d1');
      expect(api.storage.keys, ['u1/d1.json.gz']);

      await repo.softDeleteDay('d1');
      await s.pushDelete('d1');
      expect(api.upserts.last['deleted_at'], isA<String>());
      expect(api.removed, ['d1']);
      expect(api.storage, isEmpty);
      expect(await repo.outbox(), isEmpty);
    });

    test('syncNow drains a delete entry through removeTrack too', () async {
      await seedFinishedDay(repo, points: samplePoints());
      final s = service();
      await s.syncNow();
      await repo.softDeleteDay('d1');
      await s.syncNow();
      expect(api.removed, ['d1']);
    });

    test('a failing removeTrack does not fail the push', () async {
      await seedFinishedDay(repo);
      await repo.softDeleteDay('d1');
      final s = service();
      // the upsert succeeds, then the storage delete throws
      api.failure = null;
      final throwing = _RemoveThrows(api);
      final t = SyncService(repo: repo, api: throwing, store: MemorySyncStore(), now: () => clock);
      await t.syncNow();
      expect(await repo.outbox(), isEmpty);
      expect(t.current.state, SyncState.idle);
      expect(s.current.state, SyncState.idle);
    });

    test('restore: pulled day with track_path and 0 points gets points, segments and recomputed stats', () async {
      // a device recorded a real day and backed it up
      final c = _synth('d1');
      await repo.createActiveDay(id: 'd1', startedAt: c.points.first.ts, resortId: 'kitzbuehel', resortName: 'Kitzbühel');
      await repo.appendPoints('d1', c.points, stats: c.stats);
      await repo.finishDay('d1', endedAt: c.points.last.ts, stats: c.stats, segments: c.segments);
      await service().pushDay('d1');
      expect(api.trackPaths['d1'], 'u1/d1.json.gz');
      final pushed = api.upserts.single;

      // this phone only knows the aggregates
      await repo.discardDay('d1');
      final remote = {...pushed, 'updated_at': pushed['device_updated_at'], 'track_path': 'u1/d1.json.gz'};
      api.remoteDays = [remote];
      final s2 = service();
      await s2.pullAll();
      var day = (await repo.day('d1'))!;
      expect(await repo.pointCount('d1'), 0);
      expect(day.stats.signalLossMs, 0, reason: 'the backend has no signal-loss column');
      expect(day.stats.acceptedFixes, 0);

      final restorer = TrackRestoreService(repo: repo, api: api);
      expect(await restorer.hasRemoteTrack('d1'), isTrue);
      expect(await restorer.restore('d1'), isTrue);

      expect(await repo.pointCount('d1'), c.points.length);
      final segs = await repo.segmentsOf('d1');
      expect(segs, hasLength(c.segments.length));
      expect(segs.map((s) => s.id), c.segments.map((s) => s.id));
      day = (await repo.day('d1'))!;
      expect(day.stats.signalLossMs, c.stats.signalLossMs);
      expect(day.stats.acceptedFixes, c.stats.acceptedFixes);
      expect(day.stats.rejectedFixes, c.stats.rejectedFixes);
      expect(day.stats.runCount, c.stats.runCount);
      expect(day.stats.dropM, closeTo(c.stats.dropM, 0.01));
      expect(day.stats.maxSpeedSegmentId, c.stats.maxSpeedSegmentId);
      expect(day.lastFixAt, isNotNull);
      final detail = await repo.dayDetail('d1');
      expect(detail!.points, isNotEmpty);
      // the restore is not a local edit: nothing goes back to the backend
      expect(await repo.outbox(), isEmpty);
      // second call is a no-op
      expect(await restorer.hasRemoteTrack('d1'), isFalse);
      expect(await restorer.restore('d1'), isFalse);
    });

    test('restore is a no-op without a backup, signed out or on an active day', () async {
      await repo.upsertFromRemote(remoteRow(id: 'r', deviceUpdatedAt: sampleStartedAt + 1));
      final restorer = TrackRestoreService(repo: repo, api: api);
      expect(await restorer.hasRemoteTrack('r'), isFalse);
      expect(await restorer.restore('r'), isFalse);

      api.trackPaths['r'] = 'u1/r.json.gz';
      expect(await restorer.hasRemoteTrack('r'), isTrue);
      expect(await restorer.restore('r'), isFalse, reason: 'path set but no object');

      api.userId = null;
      expect(await restorer.hasRemoteTrack('r'), isFalse);
      expect(await TrackRestoreService(repo: repo, api: null).restore('r'), isFalse);

      api.userId = 'u1';
      await repo.createActiveDay(id: 'act', startedAt: sampleStartedAt);
      api.trackPaths['act'] = 'u1/act.json.gz';
      expect(await restorer.hasRemoteTrack('act'), isFalse);
    });

    test('decodeBundle replays segments through the engine when the bundle has none', () {
      final c = _synth('x');
      final day = DayRecord(id: 'x', startedAt: c.points.first.ts, status: DayStatus.finished, stats: c.stats);
      final bytes = DiagnosticsBundle.encode(DiagnosticsBundle.toJson(day: day, segments: const [], points: c.points, device: 'test'));
      final out = TrackRestoreService.decodeBundle('x', bytes);
      expect(out.points, hasLength(c.points.length));
      expect(out.segments, hasLength(c.segments.length));
      expect(out.stats.runCount, c.stats.runCount);
    });

    test('segmentFromJson round-trips every field', () {
      const seg = Segment(
        id: 's1', dayId: 'd', kind: SegmentKind.lift, idx: 3, runNumber: null, startTs: 10, endTs: 20, startAltM: 1000,
        endAltM: 1500, dropM: 500, distanceM: 1200, movingMs: 9000, maxSpeedMs: 4.5, maxSpeedAtTs: 15, avgSpeedMs: 4,
        avgGradientPct: 41.6, steepest100mPct: 55.1, startPointTs: 10, endPointTs: 20, flags: 2, pisteName: null,
        pisteOsmId: null, liftName: 'Hahnenkammbahn',
      );
      final back = TrackRestoreService.segmentFromJson(DiagnosticsBundle.segmentToJson(seg), dayId: 'd');
      expect(DiagnosticsBundle.segmentToJson(back), DiagnosticsBundle.segmentToJson(seg));
    });
  });

  group('resume', () {
    test('syncOnResume is debounced to five minutes', () async {
      final s = service();
      await s.syncOnResume();
      expect(api.fetchCursors, hasLength(1), reason: 'never synced → runs');
      clock += const Duration(minutes: 4).inMilliseconds;
      await s.syncOnResume();
      expect(api.fetchCursors, hasLength(1), reason: 'too soon');
      clock += const Duration(minutes: 1, seconds: 1).inMilliseconds;
      await s.syncOnResume();
      expect(api.fetchCursors, hasLength(2));
    });

    test('a failed run does not count as synced', () async {
      api.offline = true;
      final s = service();
      await s.syncOnResume();
      expect(s.current.state, SyncState.offline);
      api.offline = false;
      await s.syncOnResume();
      expect(s.current.state, SyncState.idle, reason: 'ran again although the gap is < 5 min');
      expect(api.fetchCursors, hasLength(2));
    });
  });
}

DayComputation _synth(String id, {int seed = 7}) {
  final day = SyntheticDayGenerator(seed: seed).generate();
  final e = TrackingEngine(dayId: id);
  var fi = 0, pi = 0;
  for (var ts = day.pressures.first.ts; ts <= day.pressures.last.ts; ts += 1000) {
    while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
      e.addFix(day.fixes[fi++]);
    }
    while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
      e.addPressure(day.pressures[pi++]);
    }
    e.tick(ts);
  }
  return e.finish();
}

/// Delegates to a [FakeSyncApi] but blows up on the storage delete.
class _RemoveThrows extends FakeSyncApi {
  _RemoveThrows(this.inner) : super(userId: inner.userId);
  final FakeSyncApi inner;

  @override
  Future<void> upsertDay(Map<String, Object?> row) => inner.upsertDay(row);

  @override
  Future<void> removeTrack(String dayId) async => throw StateError('storage down');
}
