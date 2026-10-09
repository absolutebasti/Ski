import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/sync/sync_service.dart';
import 'package:slopetrack/data/sync/sync_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'sync_fixtures.dart';

/// Launch audit 2026-10-09: the 30 s poll and the state after account deletion.
void main() {
  late AppDatabase db;
  late DaysRepository repo;
  late FakeSyncApi api;
  late int clock;

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
    api = FakeSyncApi();
    clock = DateTime.now().millisecondsSinceEpoch;
  });
  tearDown(() => db.close());

  test('an entry the server rejects is not due again until its backoff is over', () async {
    await seedFinishedDay(repo);
    api.upsertFailure = PostgrestException(message: 'too_many_days', code: 'P0004');
    final s = SyncService(repo: repo, api: api, store: MemorySyncStore(), now: () => clock);
    expect(await s.hasDueEntries(), isTrue);
    await s.syncNow();
    expect(await s.pendingCount(), 1);
    expect(await s.hasDueEntries(), isFalse, reason: 'the poll must not pull the whole account for it');
    clock += const Duration(hours: 2).inMilliseconds;
    expect(await s.hasDueEntries(), isTrue);
  });

  test('after account deletion the next sign-in is a fresh start, not a Konto switch', () async {
    final store = MemorySyncStore(lastUserId: 'deleted-user');
    final s = SyncService(repo: repo, api: api, store: store, now: () => clock);
    await seedFinishedDay(repo);
    await s.forgetAccount();
    expect(await store.lastUserId(), isNull);
    expect(await repo.outbox(), isEmpty);
    final row = await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle();
    expect(row.syncedAt, isNull);

    // A day recorded while signed out after the deletion …
    await seedFinishedDay(repo, id: 'after');
    // … uploads to the new account instead of being dropped as "another Konto".
    await s.syncNow();
    expect(api.upserts.map((u) => u['id']), contains('after'));
  });
}
