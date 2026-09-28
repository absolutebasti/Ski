import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/features/recording/batch_writer.dart';

/// BatchWriter against an in-memory drift database.
void main() {
  late AppDatabase db;
  late DaysRepository repo;
  const dayId = 'd-bw';
  const t0 = 1735288800000;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DaysRepository(db);
    await repo.createActiveDay(id: dayId, startedAt: t0);
  });
  tearDown(() => db.close());

  TrackPoint pt(int i, {bool accepted = true}) => TrackPoint(ts: t0 + i * 1000, lat: 47.4, lon: 12.3, hAccM: 5, accepted: accepted);

  test('empty buffer is never due', () {
    final w = BatchWriter(repo, dayId);
    expect(w.due(t0), isFalse);
    expect(w.due(t0 + 60000), isFalse);
    expect(w.buffered, 0);
  });

  group('due by point count', () {
    for (final (n, expected) in [(1, false), (TrackingConfig.batchFlushPoints - 1, false), (TrackingConfig.batchFlushPoints, true), (TrackingConfig.batchFlushPoints + 3, true)]) {
      test('$n buffered points → due $expected', () {
        final w = BatchWriter(repo, dayId);
        for (var i = 0; i < n; i++) {
          w.add(pt(i));
        }
        expect(w.due(t0 + n * 1000), expected);
      });
    }
  });

  group('due by age', () {
    for (final (seconds, expected) in [(0, false), (TrackingConfig.batchFlushS - 1, false), (TrackingConfig.batchFlushS, true), (30, true)]) {
      test('one point, $seconds s since the first due() → due $expected', () {
        final w = BatchWriter(repo, dayId);
        w.add(pt(0));
        expect(w.due(t0), isFalse, reason: 'first call arms the timer');
        expect(w.due(t0 + seconds * 1000), expected);
      });
    }
  });

  test('flush persists the points in order and empties the buffer', () async {
    final w = BatchWriter(repo, dayId);
    for (var i = 0; i < 4; i++) {
      w.add(pt(i, accepted: i != 2));
    }
    await w.flush(t0 + 4000);
    expect(w.buffered, 0);
    final stored = await repo.pointsRaw(dayId);
    expect(stored.map((p) => p.ts), [t0, t0 + 1000, t0 + 2000, t0 + 3000]);
    expect(stored.where((p) => p.accepted).length, 3);
    expect((await repo.day(dayId))!.lastFixAt, t0 + 3000, reason: 'last accepted fix');
    expect(w.due(t0 + 4000), isFalse);
  });

  test('flush carries the latest stats and stream restarts to the day row', () async {
    final w = BatchWriter(repo, dayId);
    w.add(pt(0), stats: const DayStats(runCount: 1, dropM: 100), streamRestarts: 1);
    w.add(pt(1), stats: const DayStats(runCount: 2, dropM: 250), streamRestarts: 2);
    await w.flush(t0 + 2000);
    final d = (await repo.day(dayId))!;
    expect(d.stats.runCount, 2);
    expect(d.stats.dropM, 250);
    expect(d.streamRestarts, 2);
  });

  test('flush with nothing pending is a no-op; stats alone still write', () async {
    final w = BatchWriter(repo, dayId);
    await w.flush(t0);
    expect((await repo.pointsRaw(dayId)), isEmpty);
    w.add(pt(0));
    await w.flush(t0 + 1000);
    w.add(pt(1), stats: const DayStats(runCount: 7));
    await w.flush(t0 + 2000);
    expect((await repo.day(dayId))!.stats.runCount, 7);
    expect((await repo.pointsRaw(dayId)).length, 2);
  });

  test('overlapping flushes serialise: every point stored once', () async {
    final w = BatchWriter(repo, dayId);
    for (var i = 0; i < 10; i++) {
      w.add(pt(i));
    }
    final f1 = w.flush(t0 + 10000);
    for (var i = 10; i < 15; i++) {
      w.add(pt(i));
    }
    final f2 = w.flush(t0 + 15000);
    await Future.wait([f1, f2]);
    final stored = await repo.pointsRaw(dayId);
    expect(stored.length, 15);
    expect(stored.map((p) => p.ts).toSet().length, 15);
  });

  test('a burst of 1 Hz ticks with due()-driven flushes stores everything', () async {
    final w = BatchWriter(repo, dayId);
    for (var i = 0; i < 37; i++) {
      w.add(pt(i));
      final now = t0 + i * 1000;
      if (w.due(now)) await w.flush(now);
    }
    await w.flush(t0 + 37000);
    expect((await repo.pointsRaw(dayId)).length, 37);
  });
}
