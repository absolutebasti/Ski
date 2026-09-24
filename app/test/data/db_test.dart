import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DaysRepository(db);
  });
  tearDown(() => db.close());

  DayComputation synth(String id, {int seed = 7}) {
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

  test('round-trips a day with points and segments', () async {
    final c = synth('d1');
    await repo.createActiveDay(id: 'd1', startedAt: c.points.first.ts, resortId: 'kitzbuehel', resortName: 'Kitzbühel');
    expect((await repo.activeDay())?.id, 'd1');
    await repo.appendPoints('d1', c.points, stats: c.stats);
    await repo.finishDay('d1', endedAt: c.points.last.ts, stats: c.stats, segments: c.segments);
    expect(await repo.activeDay(), isNull);

    final detail = await repo.dayDetail('d1');
    expect(detail, isNotNull);
    expect(detail!.day.stats.runCount, c.stats.runCount);
    expect(detail.segments.length, c.segments.length);
    expect(detail.points.length, c.points.where((p) => p.accepted).length);
    expect(detail.day.status, DayStatus.finished);

    final raw = await repo.pointsRaw('d1');
    expect(raw.length, c.points.length);
    final recomputed = TrackingEngine.computeDay('d1', raw);
    expect(recomputed.stats.runCount, c.stats.runCount);
    expect(recomputed.stats.dropM, closeTo(c.stats.dropM, 0.5));
  });

  test('watchDays, season totals and personal bests', () async {
    final a = synth('a', seed: 1);
    final b = synth('b', seed: 2);
    for (final (id, c) in [('a', a), ('b', b)]) {
      await repo.createActiveDay(id: id, startedAt: c.points.first.ts + (id == 'b' ? 86400000 : 0));
      await repo.appendPoints(id, c.points, stats: c.stats);
      await repo.finishDay(id, endedAt: c.points.last.ts, stats: c.stats, segments: c.segments);
    }
    final days = await repo.watchDays().first;
    expect(days.length, 2);
    expect(days.first.id, 'b'); // newest first
    expect(days.where((d) => d.isTopSpeedPb).length, 1);
    final seasons = await repo.watchSeasonTotals().first;
    expect(seasons.single.dayCount, 2);
    expect(seasons.single.runCount, a.stats.runCount + b.stats.runCount);
    final pb = await repo.watchPersonalBests().first;
    expect(pb.topSpeedMs, greaterThan(0));
    expect(pb.longestRunDropM, greaterThan(0));

    await repo.softDeleteDay('b');
    expect((await repo.watchDays().first).length, 1);
    await repo.deleteAll();
    expect((await repo.watchDays().first), isEmpty);
  });

  test('discard removes everything', () async {
    final c = synth('x');
    await repo.createActiveDay(id: 'x', startedAt: c.points.first.ts);
    await repo.appendPoints('x', c.points);
    await repo.discardDay('x');
    expect(await repo.day('x'), isNull);
    expect(await repo.pointsRaw('x'), isEmpty);
  });

  test('resort lookup', () {
    final repo = ResortRepository([
      const Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.4467, lon: 12.3923, radiusKm: 12),
      const Resort(id: 'skiwelt', name: 'SkiWelt', country: 'AT', lat: 47.5040, lon: 12.1930, radiusKm: 10),
    ]);
    expect(repo.nearest(47.4491, 12.3913)?.id, 'kitzbuehel');
    expect(repo.nearest(52.52, 13.405), isNull);
    expect(repo.byId('skiwelt')?.name, 'SkiWelt');
  });
}
