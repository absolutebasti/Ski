import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'cable_support.dart';

/// **The uphill mirror of `ski_road_sweep_test.dart`.**
///
/// A skier who comes off a run, skates or poles up a rising connector and skis on
/// may never be booked as a cable LIFT. That is what the rolling 45 s window did:
/// it measures straightness over *slice centroids*, and averaging hides a wander,
/// so a person at T-bar speed scored a straightness of 0,99 and got a phantom
/// 1,7 km of lift distance with the run around it split in two.
///
/// Two shapes, because they are not the same claim:
///
/// * **the connector** — `[stop, run, uphill, run, stop]`, the reviewer's repro
///   and the realistic shape. A connector is something you ski into and out of.
///   Here the claim is absolute: **never a LIFT.**
/// * **bracketed** — `[stop, uphill, stop]`: a standstill, then a straight,
///   machine-constant climb, then a standstill. Where that climb is dead straight
///   this is *not* a claim the engine can honour, and the reason is in the shipped
///   green tests themselves: `lift_scenarios_test.dart` requires
///   `Phase.lift(200, 300, avgSpeedMs: 3, jitter: 0.1)` — 3 m/s, 22 %, 10 % speed
///   spread, a standstill in front of it — to *be* a T-bar. The generator emits
///   exactly the same samples for `Phase.other` with those parameters. The two
///   populations are one population. So the sweep below measures the boundary
///   instead of pretending it away, and `expectedBracketedLifts` is the number it
///   found. See docs/TRACKING.md → Grenzen.
///
/// And a genuine T-bar (spread ≤ 5 %, no wander) has to stay a LIFT, in the same
/// sweep, so the boundary is visible from both sides.
void main() {
  const seeds = [3, 5, 21, 33, 42];
  const speeds = [1.5, 2.2, 3.0];
  const gradients = [0.08, 0.13, 0.20];
  const jitters = [0.10, 0.15, 0.25];
  const turns = [0.0, 1.0, 3.0];
  const durations = [120, 240, 360];

  /// A climb this fast is a machine on the *barometer's* word alone: the
  /// segmenter's rule 2 opens a LIFT at [TrackingConfig.liftEnterGained60M] per
  /// minute, with no cable signature involved, and the pre-change engine did the
  /// same (verified against the zz_head snapshot: `v = 3 m/s` at 20 % is one lift
  /// of 1.7–1.8 km before *and* after this change). 0,425 m/s = 25,5 m per
  /// minute, which is rule 2's 30 m less the barometric noise margin.
  bool baroOwnsIt(double v, double gradient) => v * gradient >= TrackingConfig.liftEnterGained60M / 60 * 0.85;

  List<Phase> connector(double v, double gradient, double j, double t, int dur) => [
        const Phase.stop(30),
        Phase.realRun(300, 150, avgSpeedMs: 12),
        Phase.other(dur * v * gradient, dur, avgSpeedMs: v, jitter: j, turnRateDeg: t),
        Phase.realRun(300, 150, avgSpeedMs: 12),
        const Phase.stop(30),
      ];

  List<Phase> bracketed(double v, double gradient, double j, double t, int dur) => [
        const Phase.stop(60),
        Phase.other(dur * v * gradient, dur, avgSpeedMs: v, jitter: j, turnRateDeg: t),
        const Phase.stop(60),
      ];

  group('a person on a rising connector is never a LIFT', () {
    for (final v in speeds) {
      for (final gradient in gradients) {
        if (baroOwnsIt(v, gradient)) continue;
        test('$v m/s at ${(gradient * 100).round()} % '
            '(${(v * gradient * 60).round()} m per minute)', () {
          for (final j in jitters) {
            for (final t in turns) {
              for (final dur in durations) {
                for (final seed in seeds) {
                  final gen = SyntheticDayGenerator(seed: seed).generate(connector(v, gradient, j, t, dur));
                  final r = runLiveDay(gen, dayId: 'conn');
                  final why = 'v=$v gradient=${(gradient * 100).round()}% jitter=$j turn=$t '
                      'dur=${dur}s seed=$seed: ${describe(r.segments)}';
                  expect(r.stats.liftCount, 0, reason: 'skating uphill became a lift — $why');
                  expect(r.stats.liftDistanceM, 0, reason: 'phantom lift kilometres — $why');
                  expect(r.stats.ascentM, 0, reason: 'phantom ascent — $why');
                  // …and the two runs around it keep their drop. Where the
                  // connector is short or gentle enough that the segmenter never
                  // leaves RUN, the two runs are one and the climb is netted off
                  // its drop — which is exactly what the pre-change engine did
                  // (one run, no lift). Both answers are honest; inventing a lift
                  // is not.
                  final gain = dur * v * gradient;
                  expect(r.stats.dropM, greaterThan(600 - gain - 40), reason: why);
                  expect(r.stats.dropM, lessThan(660), reason: why);
                }
              }
            }
          }
        }, timeout: const Timeout(Duration(minutes: 10)));
      }
    }
  });

  test('the barometric corner is not this rule\'s and is not new', () {
    // 30 m of climb per minute opens a LIFT from the barometer alone
    // (liftEnterGained60M), with no cable signature: 3 m/s at 20 % is 36 m per
    // minute = 2.160 m/h, which no human sustains. The pre-change engine booked it
    // as a lift too. Asserting it here keeps the group above honest about *why* it
    // skips these cases.
    for (final seed in seeds) {
      final r = runLiveDay(SyntheticDayGenerator(seed: seed).generate(connector(3.0, 0.20, 0.15, 0.0, 240)), dayId: 'baro');
      expect(r.stats.liftCount, 1, reason: 'seed $seed: ${describe(r.segments)}');
    }
    expect(baroOwnsIt(3.0, 0.20), isTrue);
    expect(baroOwnsIt(2.2, 0.13), isFalse, reason: 'the reviewer\'s repro is in the strict space');
  });

  test('the measured boundary of the bracketed shape', () {
    // Standstill → dead-straight machine-constant climb → standstill. Counted,
    // not wished away. Every lift in here is a case whose samples the generator
    // cannot distinguish from `SkiProfiles.tbar`; what the rule *did* remove is
    // the wander (turnRateDeg 1 and 3 above two minutes) and the loudest spreads.
    var slots = 0, lifts = 0;
    final byTurn = <double, int>{0.0: 0, 1.0: 0, 3.0: 0};
    for (final v in speeds) {
      for (final gradient in gradients) {
        if (baroOwnsIt(v, gradient)) continue;
        for (final j in jitters) {
          for (final t in turns) {
            for (final dur in durations) {
              for (final seed in seeds) {
                slots++;
                final r = runLiveDay(SyntheticDayGenerator(seed: seed).generate(bracketed(v, gradient, j, t, dur)), dayId: 'br');
                if (r.stats.liftCount > 0) {
                  lifts++;
                  byTurn[t] = byTurn[t]! + 1;
                }
                // Whatever it is called, it is never skiing: an ascent has no
                // drop, no ski metres and no top speed.
                expect(r.stats.dropM, 0, reason: 'v=$v g=$gradient j=$j t=$t d=$dur seed=$seed: ${describe(r.segments)}');
                expect(r.stats.skiDistanceM, 0, reason: 'v=$v g=$gradient j=$j t=$t d=$dur seed=$seed');
                expect(r.stats.maxSpeedMs, 0, reason: 'v=$v g=$gradient j=$j t=$t d=$dur seed=$seed');
              }
            }
          }
        }
      }
    }
    expect(slots, 945, reason: 'the strict space of the bracketed shape');
    // 81 of 945. If a change moves this, it is a decision, not a detail: down is
    // better, up means a straight standstill-to-standstill climb newly reads as a
    // rope. Every one of the 81 is turn-free or a two-minute case.
    expect(lifts, lessThanOrEqualTo(81), reason: 'the boundary grew: $lifts of $slots, by wander $byTurn');
    expect(byTurn[3.0]!, lessThanOrEqualTo(12), reason: 'a 3 °/s wander is a person: $byTurn');
  }, timeout: const Timeout(Duration(minutes: 20)));

  group('a genuine T-bar in the same space is still a LIFT', () {
    // Spread ≤ 5 %, no wander, a station in front of it — a rope. Gradients are
    // the ones real T-bars have (20–40 %); at 13 % a T-bar is a magic carpet's
    // cousin and the barometric rules own it anyway.
    for (final v in [2.2, 3.0, 3.5]) {
      for (final gradient in [0.20, 0.30, 0.40]) {
        test('$v m/s at ${(gradient * 100).round()} %', () {
          for (final j in [0.03, 0.05]) {
            for (final dur in [120, 240, 360]) {
              for (final seed in seeds) {
                final r = runLiveDay(
                    SyntheticDayGenerator(seed: seed).generate([
                      const Phase.stop(60),
                      Phase.cable(dur * v * gradient, dur, avgSpeedMs: v, jitter: j),
                      const Phase.stop(60),
                    ]),
                    dayId: 'tbar');
                final why = 'v=$v gradient=${(gradient * 100).round()}% jitter=$j dur=${dur}s seed=$seed: '
                    '${describe(r.segments)}';
                expect(r.stats.liftCount, 1, reason: 'the T-bar was thrown away — $why');
                expect(r.stats.runCount, 0, reason: why);
                expect(r.stats.skiDistanceM, 0, reason: why);
                expect(r.stats.maxSpeedMs, 0, reason: why);
                expect(r.stats.ascentM, closeTo(dur * v * gradient, dur * v * gradient * 0.12 + 10), reason: why);
              }
            }
          }
        }, timeout: const Timeout(Duration(minutes: 10)));
      }
    }
  });
}
