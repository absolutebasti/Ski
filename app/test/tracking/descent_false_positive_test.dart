import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'cable_support.dart';

/// The band where real skiing actually lives must survive the descending-cable
/// rule. Nothing in here may become a lift, and every run must keep its drop,
/// its distance and its top speed.
///
/// Why this suite exists: the first version of the rule read a straight, steady
/// 5–11 m/s descent as a gondola and the whole run vanished — 0 runs, 0 ski
/// metres, 0 km/h, 0 m of drop. Speed constancy was the only real discriminator
/// and it sits right in the middle of ordinary skiing.
const _t0 = t0;

/// Runs the day and asserts it is still skiing: one run, no lift where the run
/// is, and drop / distance / top speed within the stated tolerances.
///
/// [numbers] false only for the 2 m/s case, where the engine's *own* RUN entry
/// floor (runEnterSpeedMs = 2 m/s) trims the first ~35 s of the descent into
/// OTHER before any cable rule is consulted. That is pre-existing behaviour and
/// not what this suite is about; the run, the lift veto and the top speed are
/// still asserted there.
void _expectStaysARun(List<Phase> phases, int seed, {required int runPhase, bool numbers = true}) {
  final gen = SyntheticDayGenerator(seed: seed, startTs: _t0).generate(phases);
  final r = runLiveDay(gen, dayId: 'fp');
  final why = 'seed $seed: ${describe(r.segments)}';
  final (ws, we) = phaseWindow(phases, runPhase);

  // 1. the descent is still a RUN, and no lift covers it
  final runs = r.segments.where((s) => s.kind == SegmentKind.run && s.startTs < we && s.endTs > ws).toList();
  expect(runs, isNotEmpty, reason: 'the descent disappeared — $why');
  for (final s in r.segments.where((s) => s.kind == SegmentKind.lift)) {
    final overlap = (s.endTs < we ? s.endTs : we) - (s.startTs > ws ? s.startTs : ws);
    if (overlap <= 0) continue;
    expect(s.endAltM, greaterThan(s.startAltM), reason: 'a ride *down* was booked over the run — $why');
    // The ascending lift in front may reach into the run by up to the
    // turning-point snap; a descending one may not reach in at all.
    expect(overlap, lessThanOrEqualTo(20000), reason: 'a lift covers the run — $why');
  }

  if (numbers) {
    // 2. drop within 8 % + 12 m of the generator truth (barometric noise, and
    //    the boundary snap moves the first and last second or two)
    expect(r.stats.dropM, closeTo(gen.expectedDropM, gen.expectedDropM * 0.08 + 12), reason: why);

    // 3. skied distance within 12 % + 40 m of the GPS path of the run phases
    final path = fixPathInPhases(gen, phases);
    expect(r.stats.skiDistanceM, closeTo(path, path * 0.12 + 40), reason: why);
  } else {
    expect(r.stats.dropM, greaterThan(gen.expectedDropM * 0.6), reason: why);
    expect(r.stats.skiDistanceM, greaterThan(fixPathInPhases(gen, phases) * 0.5), reason: why);
  }

  // 4. top speed: the confirmed maximum (2 of 3 candidates within 15 %, on a
  //    Doppler signal with 0.3 m/s of noise) lands within 1.5 m/s of the truth
  //    and is never lost altogether.
  expect(r.stats.maxSpeedMs, greaterThan(gen.expectedMaxSpeedMs - 1.5), reason: why);
  expect(r.stats.maxSpeedMs, lessThan(gen.expectedMaxSpeedMs + 1.5), reason: why);
  expect(r.stats.maxSpeedMs, maxOverRuns(r.segments), reason: 'the day max is a run max — $why');
}

void main() {
  const seeds = [3, 5, 7, 21, 33, 42];
  const lift = Phase.cable(400, 200, avgSpeedMs: 5);

  group('straight, steady descents at 2–11 m/s stay RUNs', () {
    // Gradient: at least 1 m/s of vertical speed, so the engine's RUN entry
    // (runEnterVz10Ms = 0.7 m/s) fires at every one of these speeds — at 2 m/s
    // that means a steep pitch side-slipped, which is what 2 m/s downhill is.
    // 240 s of *continuous* descent, dead straight, is already longer than any
    // real skier holds one line; above descentMinDurationS (300 s) such a
    // descent between two standstills carries no measurable property that a
    // cabin does not also carry (see the documented limit at the bottom of this
    // file and docs/TRACKING.md).
    for (final v in [2.0, 3.0, 5.0, 8.0, 10.0, 11.0]) {
      for (final j in [0.05, 0.07, 0.09]) {
        test('$v m/s, jitter $j, with and without a lift in front', () {
          final drop = 240 * (v * 0.25 < 1.0 ? 1.0 : v * 0.25);
          final run = Phase.run(drop, 240, avgSpeedMs: v, jitter: j);
          final numbers = v > 2.0;
          for (final seed in seeds) {
            _expectStaysARun([const Phase.stop(60), run, const Phase.stop(60)], seed, runPhase: 1, numbers: numbers);
            _expectStaysARun([const Phase.stop(60), lift, const Phase.stop(30), run, const Phase.stop(60)], seed,
                runPhase: 3, numbers: numbers);
          }
        });
      }
    }
  });

  group('five-minute descents skied the way people ski stay RUNs', () {
    // The same speed band, but 300 s long and with turns and a speed wave — a
    // real skier. Here the full-resolution geometry carries the decision: the
    // offset from the start-end chord is hundreds of metres, a cable's is a few.
    for (final v in [3.0, 5.0, 8.0, 11.0]) {
      for (final j in [0.05, 0.09]) {
        test('$v m/s, jitter $j over 300 s', () {
          final drop = 300 * (v * 0.25 < 1.0 ? 1.0 : v * 0.25);
          final run = Phase.run(drop, 300, avgSpeedMs: v, jitter: j, turnRateDeg: 4, speedWaveAmp: 0.25, speedWaveS: 40);
          for (final seed in seeds.take(5)) {
            _expectStaysARun([const Phase.stop(60), lift, const Phase.stop(30), run, const Phase.stop(60)], seed, runPhase: 3);
          }
        });
      }
    }
  });

  group('regressions from the reviewers', () {
    test('finding 1: a straight steady 10 m/s descent after a lift is a RUN, not a ride', () {
      // Verbatim repro. Before the fix: 0 runs, 0 ski metres, 0 km/h, 0 m drop.
      const phases = [
        Phase.stop(60),
        Phase.cable(400, 200, avgSpeedMs: 5),
        Phase.run(300, 120, avgSpeedMs: 10, jitter: 0.06),
        Phase.stop(30),
      ];
      for (final seed in [5, 7, 21, 33]) {
        final r = day(phases, seed: seed, dayId: 'f1');
        final why = 'seed $seed: ${describe(r.segments)}';
        expect(r.stats.runCount, 1, reason: why);
        expect(r.stats.liftCount, 1, reason: why);
        expect(r.stats.skiDistanceM, greaterThan(1300), reason: why);
        expect(r.stats.maxSpeedMs * 3.6, greaterThan(36), reason: why);
        expect(r.stats.dropM, closeTo(300, 20), reason: why);
      }
    });

    test('finding 2: slow real skiing is not unprotected by an absolute speed floor', () {
      // Verbatim repro: 5 m/s with 8 % spread after a lift. The old rule had a
      // 0.42 m/s absolute floor under the allowed spread, which at 5 m/s meant a
      // permitted CV of 8.4 % — exactly here.
      const phases = [
        Phase.stop(60),
        Phase.cable(400, 200, avgSpeedMs: 5),
        Phase.run(150, 120, avgSpeedMs: 5, jitter: 0.08),
        Phase.stop(30),
      ];
      for (final seed in [5, 21, 33]) {
        final r = day(phases, seed: seed, dayId: 'f2');
        final why = 'seed $seed: ${describe(r.segments)}';
        expect(r.stats.runCount, 1, reason: why);
        expect(r.stats.liftCount, 1, reason: why);
        expect(r.stats.skiDistanceM, greaterThan(900), reason: why);
        expect(r.stats.maxSpeedMs, greaterThan(4.5), reason: why);
        expect(r.stats.dropM, closeTo(150, 15), reason: why);
      }
    });
  });

  test('the descent that decided the switch: a six-minute ski road stays a RUN', () {
    // This case *was* read as a valley ride, and it is why
    // [TrackingConfig.descentRidesEnabled] is false. A 360 s descent at exactly
    // 5 m/s with 5 % spread on a straight line between two standstills carries no
    // measurable property that a valley gondola does not also carry: same chord
    // offset (both pure GPS noise), same altitude linearity, same speed spread.
    // With the rule on it lost its run; ski_road_sweep_test.dart found 426 more
    // like it. With the rule off it is a run, which is the whole point.
    const phases = [Phase.stop(60), Phase.run(450, 360, avgSpeedMs: 5, jitter: 0.05), Phase.stop(60)];
    for (final seed in [5, 21, 42]) {
      final r = day(phases, seed: seed, dayId: 'limit');
      final why = 'seed $seed: ${describe(r.segments)}';
      if (descentRides) {
        // The documented boundary of the rule when it is on.
        expect(r.stats.liftCount, 1, reason: why);
        expect(r.stats.runCount, 0, reason: why);
      } else {
        expect(r.stats.liftCount, 0, reason: why);
        expect(r.stats.runCount, 1, reason: why);
        expect(r.stats.dropM, closeTo(450, 30), reason: why);
        expect(r.stats.skiDistanceM, greaterThan(1700), reason: why);
      }
    }
    // …and one turn per 15 s — the least a skier ever does — keeps it a run in
    // either configuration, which is the property the rule was narrowed on.
    const turned = [
      Phase.stop(60),
      Phase.run(450, 360, avgSpeedMs: 5, jitter: 0.05, turnRateDeg: 2),
      Phase.stop(60),
    ];
    for (final seed in [5, 21, 42]) {
      final t = day(turned, seed: seed, dayId: 'turned');
      expect(t.stats.liftCount, 0, reason: 'seed $seed: ${describe(t.segments)}');
      expect(t.stats.runCount, 1, reason: 'seed $seed: ${describe(t.segments)}');
    }
  });
}
