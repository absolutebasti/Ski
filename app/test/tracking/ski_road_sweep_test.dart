import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';

import 'cable_support.dart';

/// **The sweep that decided [TrackingConfig.descentRidesEnabled].**
///
/// A ski road (Ziehweg) between a standstill at the top station and a standstill
/// in the valley is an utterly normal end to a ski day, and under GPS it is the
/// same picture as a gondola riding down: constant speed, straight line,
/// altitude one way only. This sweep walks the whole ski-road band and asserts
/// that **not one of those runs is destroyed**.
///
/// 4.320 days through the live engine:
///
/// | axis | values |
/// | --- | --- |
/// | speed | 4, 5, 6, 7 m/s (14–25 km/h) |
/// | gradient | 9, 12, 18, 25 % |
/// | speed spread | 5, 8, 10, 12, 15 % |
/// | heading wander | 0, 0,3, 0,5 °/s |
/// | duration | 300, 420, 600 s |
/// | seeds | 3, 5, 7, 21, 33, 42 |
///
/// Every case sits between two 60 s standstills — the station pair the
/// descending rule looks for.
///
/// **What it measured with the descending rule ON:** 427 of the 4.320 days lost
/// their run to it. Straight roads at 5–7 m/s were eaten on 5–6 of 6 seeds up to
/// a spread of 12 %, and a curving road (0,3–0,5 °/s) at 7 m/s on 6 of 6. The
/// rule's own numbers on a 5 m/s / 18 % / 8 % road: smoothed spread 0,104–0,141
/// against a bound of 0,150, chord offset 12,9–13,4 m against 25, altitude
/// residual 0,9–1,0 m against 5 — i.e. *inside* every gondola's band. There is no
/// threshold that keeps the cabins and drops the roads, because the road band
/// contains the cabin band. So the rule is off, and this sweep is what holds it
/// off: flip [TrackingConfig.descentRidesEnabled] and it fails 427 times.
void main() {
  const seeds = [3, 5, 7, 21, 33, 42];
  const jitters = [0.05, 0.08, 0.10, 0.12, 0.15];
  const turns = [0.0, 0.3, 0.5];
  const durations = [300, 420, 600];

  /// Above this vertical speed the engine's own RUN entry
  /// ([TrackingConfig.runEnterVz10Ms] = 0,7 m/s) fires with margin, so the
  /// numbers can be held to the generator's truth. Below it the descent is too
  /// flat for a RUN at all — pre-existing behaviour, see `catTrackShallow` — and
  /// only "never a lift, never any invented ski number" is asserted.
  const vzForNumbers = 0.85;

  for (final v in [4.0, 5.0, 6.0, 7.0]) {
    for (final gradient in [0.09, 0.12, 0.18, 0.25]) {
      final vz = v * gradient;
      test('ski road ${v.toStringAsFixed(0)} m/s at ${(gradient * 100).round()} % '
          '(${vz.toStringAsFixed(2)} m/s vertical) stays a run', () {
        for (final j in jitters) {
          for (final t in turns) {
            for (final dur in durations) {
              final phases = [
                const Phase.stop(60),
                Phase.run(dur * v * gradient, dur, avgSpeedMs: v, jitter: j, turnRateDeg: t),
                const Phase.stop(60),
              ];
              for (final seed in seeds) {
                // 2.200 m of base altitude: the steepest, longest case loses
                // 1.050 m, and the gate rejects anything under
                // TrackingConfig.minAltitudeM — from 800 m the tail of the run
                // would arrive below sea level and turn into a signal loss.
                final gen = SyntheticDayGenerator(seed: seed, baseAltM: 2200).generate(phases);
                final r = runLiveDay(gen, dayId: 'road');
                final why = 'v=$v gradient=${(gradient * 100).round()}% jitter=$j turn=$t dur=${dur}s '
                    'seed=$seed: ${describe(r.segments)}';

                // 1. the road is never a ride. This is the assertion the whole
                //    sweep exists for: a lift here means a deleted run.
                expect(r.stats.liftCount, 0, reason: 'the run was rewritten as a ride — $why');
                expect(r.stats.ascentM, 0, reason: 'a descent cannot be ascent — $why');
                // …and the top speed of the day is always a run's top speed.
                expect(r.stats.maxSpeedMs, maxOverRuns(r.segments), reason: why);

                if (vz < vzForNumbers) {
                  // Too flat for the RUN entry on some seeds; nothing may be
                  // invented either way.
                  expect(r.stats.dropM, lessThanOrEqualTo(gen.expectedDropM + 15), reason: why);
                  continue;
                }

                // 2. one run, and the numbers are the generator's.
                expect(r.stats.runCount, greaterThanOrEqualTo(1), reason: 'the run disappeared — $why');
                expect(r.stats.dropM, closeTo(gen.expectedDropM, gen.expectedDropM * 0.08 + 15), reason: why);
                final path = fixPathInPhases(gen, phases);
                expect(r.stats.skiDistanceM, closeTo(path, path * 0.12 + 60), reason: why);
                expect(r.stats.maxSpeedMs, closeTo(gen.expectedMaxSpeedMs, 1.5), reason: why);
              }
            }
          }
        }
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  }

  test('and the sweep really is the reason: the rule is off', () {
    // A one-line guard so the sweep above cannot be read as proof that the
    // descending rule is safe — it is proof that it is *not*, and that it is off.
    expect(TrackingConfig.descentRidesEnabled, isFalse,
        reason: 'ski_road_sweep_test documents 427 destroyed runs with this on; '
            'turning it on means owning them');
  });
}
