import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

/// A 10 h synthetic day through the live engine: per-tick cost must stay
/// small and must not grow with the number of stored points.
void main() {
  test('10 h day: < 5 ms per tick on average, no quadratic growth, live == offline', () {
    final phases = <Phase>[];
    for (var i = 0; i < 20; i++) {
      phases.addAll(const [Phase.stop(60), Phase.lift(600, 480), Phase.stop(40), Phase.run(600, 300), Phase.walk(40), Phase.stop(880)]);
    }
    final day = SyntheticDayGenerator(seed: 5).generate(phases);
    final start = day.pressures.first.ts, end = day.pressures.last.ts;
    final ticks = (end - start) ~/ 1000 + 1;
    expect(ticks, greaterThanOrEqualTo(36000));

    final e = TrackingEngine(dayId: 'stress');
    var fi = 0, pi = 0;
    final quarter = ticks ~/ 4;
    final quarterMs = List<int>.filled(4, 0);
    final sw = Stopwatch();
    var i = 0;
    for (var ts = start; ts <= end; ts += 1000, i++) {
      while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
        e.addFix(day.fixes[fi++]);
      }
      while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
        e.addPressure(day.pressures[pi++]);
      }
      sw
        ..reset()
        ..start();
      e.tick(ts);
      sw.stop();
      quarterMs[(i ~/ quarter).clamp(0, 3)] += sw.elapsedMicroseconds;
    }
    final totalMs = quarterMs.reduce((a, b) => a + b) / 1000;
    final perTickMs = totalMs / ticks;
    final firstQ = quarterMs[0] / quarter, lastQ = quarterMs[3] / (ticks - 3 * quarter);
    // ignore: avoid_print
    print('stress: $ticks ticks, ${totalMs.toStringAsFixed(0)} ms total, ${(perTickMs * 1000).toStringAsFixed(1)} µs/tick, '
        'Q1 ${(firstQ).toStringAsFixed(1)} µs, Q4 ${(lastQ).toStringAsFixed(1)} µs, full recomputes ${e.fullRecomputes}');
    expect(perTickMs, lessThan(5), reason: 'average per-tick cost');
    expect(lastQ, lessThan(firstQ * 3 + 100), reason: 'last quarter must not be materially slower than the first (quadratic growth)');
    expect(e.fullRecomputes, lessThan(ticks / 20), reason: 'full finalize passes are event-driven, not per tick');
    expect(e.points.length, ticks);

    final live = e.finish();
    expect(live.stats.runCount, day.expectedRuns);
    expect(live.stats.liftCount, day.expectedLifts);
    expect(live.stats.dropM, closeTo(day.expectedDropM, day.expectedDropM * 0.03));

    final offline = TrackingEngine.computeDay('stress', live.points);
    expect(offline.segments.length, live.segments.length);
    for (var k = 0; k < live.segments.length; k++) {
      expect(offline.segments[k].kind, live.segments[k].kind);
      expect(offline.segments[k].startTs, live.segments[k].startTs);
      expect(offline.segments[k].endTs, live.segments[k].endTs);
    }
    expect(offline.stats.dropM, closeTo(live.stats.dropM, 0.01));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('provisional live stats converge to the final result within one transition', () {
    final day = SyntheticDayGenerator(seed: 9).generate();
    final e = TrackingEngine(dayId: 'conv');
    var fi = 0, pi = 0;
    final start = day.pressures.first.ts, end = day.pressures.last.ts;
    var maxRunCount = 0;
    for (var ts = start; ts <= end; ts += 1000) {
      while (fi < day.fixes.length && day.fixes[fi].ts <= ts) {
        e.addFix(day.fixes[fi++]);
      }
      while (pi < day.pressures.length && day.pressures[pi].ts <= ts) {
        e.addPressure(day.pressures[pi++]);
      }
      final t = e.tick(ts);
      if (t.live.stats.runCount > maxRunCount) maxRunCount = t.live.stats.runCount;
      for (var k = 1; k < e.segments.length; k++) {
        expect(e.segments[k].idx, e.segments[k - 1].idx + 1, reason: 'spliced tail keeps idx contiguous');
        expect(e.segments[k].startTs, greaterThanOrEqualTo(e.segments[k - 1].endTs));
      }
    }
    final r = e.finish();
    expect(r.stats.runCount, day.expectedRuns);
    expect(maxRunCount, lessThanOrEqualTo(day.expectedRuns + 1), reason: 'the provisional count may overshoot by one merge at most');
  });
}
