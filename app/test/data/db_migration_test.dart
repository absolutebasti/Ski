import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';

import 'sync/sync_fixtures.dart';

/// Schema v2 → v3 (SYNC-2): `days.track_path`.
///
/// The v2 file is made from the current schema by taking the new column out
/// again and turning `user_version` back — exactly what a phone with the
/// previous build has on disk.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('slopetrack-migration');
    file = File('${dir.path}/slopetrack.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<List<String>> columns(AppDatabase db, String table) async =>
      [for (final r in await db.customSelect('PRAGMA table_info($table)').get()) r.read<String>('name')];

  Future<int> userVersion(AppDatabase db) async => (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

  test('the schema is at version 3', () async {
    final db = memoryDb();
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
    expect(await columns(db, 'days'), contains('track_path'));
  });

  test('v2 → v3 adds days.track_path and keeps every day, point and outbox entry', () async {
    // a phone on the previous build: one finished day with a track, queued for push
    var db = AppDatabase(NativeDatabase(file));
    final repo = DaysRepository(db);
    await seedFinishedDay(repo, points: samplePoints());
    await db.customStatement('ALTER TABLE days DROP COLUMN track_path');
    await db.customStatement('PRAGMA user_version = 2');
    expect(await columns(db, 'days'), isNot(contains('track_path')));
    await db.close();

    // the update opens the same file
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await columns(db, 'days'), contains('track_path'));
    expect(await userVersion(db), 3);

    final upgraded = DaysRepository(db);
    final day = await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle();
    expect(day.trackPath, isNull);
    expect(day.status, DayStatus.finished.dbValue);
    expect(day.runCount, sampleStats.runCount);
    expect(day.dropM, sampleStats.dropM);
    expect(await upgraded.pointCount('d1'), 5);
    expect((await upgraded.outbox()).single.dayId, 'd1');

    // and the new column works
    await upgraded.setTrackPath('d1', 'u1/d1.json.gz');
    expect(await upgraded.trackPathOf('d1'), 'u1/d1.json.gz');
  });

  test('v1 → v3 runs both steps', () async {
    var db = AppDatabase(NativeDatabase(file));
    await DaysRepository(db).createActiveDay(id: 'old', startedAt: sampleStartedAt);
    await db.customStatement('DROP TABLE sync_outbox');
    for (final column in ['track_path', 'synced_at', 'remote_updated_at']) {
      await db.customStatement('ALTER TABLE days DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await columns(db, 'days'), containsAll(['synced_at', 'remote_updated_at', 'track_path']));
    expect(await userVersion(db), 3);
    final repo = DaysRepository(db);
    expect((await repo.day('old'))?.status, DayStatus.active);
    await (db.update(db.days)..where((d) => d.id.equals('old'))).write(const DaysCompanion(trackPath: Value('p')));
    await repo.enqueue('old', SyncOp.upsert);
    expect(await repo.outboxCount(), 1);
  });
}
