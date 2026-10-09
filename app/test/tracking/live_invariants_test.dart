import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

import 'cable_support.dart';

/// What the live screen shows during the day, against what the finished day says.
///
/// The hero number is the top speed. It may lag, it may never overshoot: a number
/// the day's end throws away must not have been on screen.
class _Trace {
  _Trace(this.result, this.liveMax, this.liveSki, this.liveDrop, this.ts);
  final DayComputation result;
  final List<double> liveMax, liveSki, liveDrop;
  final List<int> ts;
}

_Trace _trace(List<Phase> phases, int seed, {void Function(TrackingEngine e, int i)? at}) {
  final gen = SyntheticDayGenerator(seed: seed).generate(phases);
  final e = TrackingEngine(dayId: 'live');
  var fi = 0, pi = 0, i = 0;
  final liveMax = <double>[], liveSki = <double>[], liveDrop = <double>[];
  final ts = <int>[];
  for (var t = gen.pressures.first.ts; t <= gen.pressures.last.ts; t += 1000, i++) {
    while (fi < gen.fixes.length && gen.fixes[fi].ts <= t) {
      e.addFix(gen.fixes[fi++]);
    }
    while (pi < gen.pressures.length && gen.pressures[pi].ts <= t) {
      e.addPressure(gen.pressures[pi++]);
    }
    final tick = e.tick(t);
    liveMax.add(tick.live.stats.maxSpeedMs);
    liveSki.add(tick.live.stats.skiDistanceM);
    liveDrop.add(tick.live.stats.dropM);
    ts.add(t);
    at?.call(e, i);
  }
  return _Trace(e.finish(), liveMax, liveSki, liveDrop, ts);
}

void main() {
  const seeds = [1, 3, 5, 7, 21, 33, 42, 99];

  group('finding 4 — the live top speed never overshoots the finished day', () {
    // Tolerance 0.01 m/s: both numbers come from the same per-segment
    // MaxSpeedTracker, so they are the same double or they are a bug.
    const tol = 0.01;

    test('the beginner whose gondola home is faster than anything they ski', () {
      for (final seed in seeds) {
        final t = _trace(SkiProfiles.beginnerGondolaHome, seed);
        final finalMax = t.result.stats.maxSpeedMs;
        for (var i = 0; i < t.liveMax.length; i++) {
          expect(t.liveMax[i], lessThanOrEqualTo(finalMax + tol),
              reason: 'seed $seed, tick $i: live ${(t.liveMax[i] * 3.6).toStringAsFixed(1)} km/h vs final '
                  '${(finalMax * 3.6).toStringAsFixed(1)} km/h — ${describe(t.result.segments)}');
        }
        expect(t.liveMax.last, closeTo(finalMax, tol), reason: 'seed $seed: and it arrives at the final number');
        if (!descentRides) {
          // SHIPPED (TrackingConfig.descentRidesEnabled): the gondola home *is*
          // the beginner's top speed — 9 m/s, 35 km/h, on a day whose fastest
          // real skiing was 5 m/s. This is the worst single consequence of
          // switching the descending rule off, and it is the one written down in
          // docs/TRACKING.md → Grenzen. What the test still guarantees is that the
          // screen never showed a number the day's end took back.
          expect(finalMax, closeTo(9.7, 1.0), reason: 'seed $seed: ${describe(t.result.segments)}');
          continue;
        }
        // …and the gondola home (9 m/s) never became the beginner's top speed.
        expect(finalMax, lessThan(8.5), reason: 'seed $seed: ${describe(t.result.segments)}');
      }
    });

    test('finding 4 repro verbatim: [stop, cable up, run, stop, cable down 10 m/s, stop]', () {
      // The reviewers measured a live peak of 38.5–39.7 km/h against a final
      // 26.5–27.7 km/h on all 8 seeds. The 150 s / 400 m descent is below
      // descentMinDurationS, so it stays a RUN by design — but whatever the
      // classification, the live number may never exceed the final one.
      const phases = [
        Phase.stop(60),
        Phase.cable(400, 200, avgSpeedMs: 6),
        Phase.run(120, 150, avgSpeedMs: 5, jitter: 0.06, speedWaveAmp: 0.35, speedWaveS: 40, turnRateDeg: 6),
        Phase.stop(30),
        Phase.cable(-400, 150, avgSpeedMs: 10),
        Phase.stop(30),
      ];
      for (final seed in seeds) {
        final t = _trace(phases, seed);
        final finalMax = t.result.stats.maxSpeedMs;
        for (var i = 0; i < t.liveMax.length; i++) {
          expect(t.liveMax[i], lessThanOrEqualTo(finalMax + tol),
              reason: 'seed $seed, tick $i: ${(t.liveMax[i] * 3.6).toStringAsFixed(1)} vs '
                  '${(finalMax * 3.6).toStringAsFixed(1)} km/h — ${describe(t.result.segments)}');
        }
      }
    });

    test('and on the founder\'s profile, where the ride IS reclassified', () {
      for (final seed in seeds) {
        final t = _trace(SkiProfiles.gondolaDownAfterRun, seed);
        final finalMax = t.result.stats.maxSpeedMs;
        for (var i = 0; i < t.liveMax.length; i++) {
          expect(t.liveMax[i], lessThanOrEqualTo(finalMax + tol), reason: 'seed $seed, tick $i');
        }
        expect(t.liveMax.last, closeTo(finalMax, tol), reason: 'seed $seed');
      }
    });
  });

  test('finding 5 — a valley ride with a five-minute GPS dropout donates nothing', () {
    // Steel cabins lose GPS routinely. The ride must still be one lift and the
    // ski numbers must be the ones from the day without it.
    for (final seed in seeds) {
      final withRide = day(SkiProfiles.gondolaDownDropout, seed: seed, dayId: 'drop');
      final base = day(SkiProfiles.runOnly, seed: seed, dayId: 'base');
      final why = 'seed $seed: ${describe(withRide.segments)}';
      // True either way, and these are the numbers the founder looks at: the
      // cabin is slower than his descent, so it never becomes his top speed, and
      // a ride down is never ascent.
      expect(withRide.stats.maxSpeedMs, closeTo(base.stats.maxSpeedMs, 0.01), reason: why);
      expect(withRide.stats.ascentM, closeTo(base.stats.ascentM, 2), reason: 'a ride down is not ascent — $why');
      expect(withRide.stats.maxSpeedMs, maxOverRuns(withRide.segments), reason: why);
      if (!descentRides) {
        // SHIPPED: the ride is two runs with the steel cabin's GPS hole between
        // them, and its 8,5 km are ski kilometres. The dropout *is* a hole in the
        // day now — which is the honest reading once the ride is not a ride.
        expect(withRide.stats.liftCount, base.stats.liftCount, reason: why);
        expect(withRide.stats.runCount, greaterThanOrEqualTo(base.stats.runCount), reason: why);
        expect(withRide.stats.skiDistanceM, greaterThan(base.stats.skiDistanceM + 3000), reason: why);
        expect(withRide.stats.signalLossMs, greaterThan(250000), reason: why);
        continue;
      }
      expect(withRide.stats.runCount, base.stats.runCount, reason: why);
      expect(withRide.stats.skiDistanceM, closeTo(base.stats.skiDistanceM, 20), reason: why);
      expect(withRide.stats.dropM, closeTo(base.stats.dropM, 2), reason: why);
      expect(withRide.stats.liftCount, base.stats.liftCount + 1, reason: why);
      expect(withRide.stats.signalLossMs, 0, reason: 'the dropout is inside the ride, not a hole in the day — $why');
      final valley = withRide.segments.lastWhere((s) => s.kind == SegmentKind.lift);
      expect(valley.durationMs, greaterThan(650000), reason: 'one ride, dropout and all — $why');
      expect(valley.maxSpeedMs, 0, reason: why);
    }
  });

  // finding 6 — the spliced prefix+tail against a full recompute — moved to
  // `freeze_margin_test.dart`, which derives the freeze window from the rules'
  // own reach and compares the splice on *every* profile instead of four.
}
