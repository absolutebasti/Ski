import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

import 'cable_support.dart';

/// **The freeze margin.** The live engine only re-finalizes the tail behind a
/// frozen prefix, so per-tick cost stays bounded over a ten-hour day. The prefix
/// is cut [TrackingConfig.finalizeLookbackS] before the open interval — which is
/// only safe if no finalize rule reaches further back than that.
///
/// Round 2 shipped a **negative** margin: `finalizeLookbackS` was a hard-coded
/// 90 s while the descending pass reached `descentMaxRideS +
/// descentStationLookbackS` = 1.845 s, minus 1.755 s of margin. Measured
/// consequence on `SkiProfiles.gondolaDownDropout`: the spliced tail never carved
/// the ride, so prefix+tail and a full pass disagreed by 3.754,9 m — 25 × the
/// 1 m, the same bound as every other profile.
///
/// The fix is structural: the window is now **derived** from the rules. It cannot
/// go stale, because the reach below is computed from the same constants and the
/// first test fails if it ever exceeds the window.
void main() {
  /// How far back each finalize rule can move a boundary, from the open interval.
  ///
  /// * rule 3b, the turning-point snap: a fixed 60 s lookback.
  /// * rule 1c, the cable start snap: [TrackingConfig.cableStartSnapReachS].
  /// * the descending carve, **only while [TrackingConfig.descentRidesEnabled]**:
  ///   a ride may span `descentMaxRideS`, the station it left may sit
  ///   `descentStationLookbackS` earlier still, and rule 1c applies on top.
  int reachS() {
    const snap = 60;
    const cable = TrackingConfig.cableStartSnapReachS;
    final descent = TrackingConfig.descentRidesEnabled
        ? TrackingConfig.descentMaxRideS + TrackingConfig.descentStationLookbackS + cable
        : 0;
    return [snap, cable, descent].reduce((a, b) => a > b ? a : b);
  }

  test('the window covers every rule\'s reach, with a positive margin', () {
    final reach = reachS();
    final margin = TrackingConfig.finalizeLookbackS - reach;
    expect(margin, greaterThan(0),
        reason: 'finalizeLookbackS = ${TrackingConfig.finalizeLookbackS} s against a reach of $reach s: '
            'a frozen segment can be moved by a later pass');
    // Shipped: reach 80 s (the cable start snap), window 90 s, margin 10 s.
    // With descentRidesEnabled the window widens to 1.925 s together with the
    // reach — and the per-tick cost grows with it, which is one more reason the
    // flag is off.
    if (!descentRides) {
      expect(reach, 80);
      expect(TrackingConfig.finalizeLookbackS, 90);
      expect(margin, 10);
    } else {
      expect(TrackingConfig.finalizeLookbackS, greaterThanOrEqualTo(1925));
    }
  });

  group('prefix + tail equals a full recompute', () {
    /// Worst disagreement between what the engine shows on a tick where finalize
    /// actually ran and what a full pass over exactly those points says.
    (double, double, double, String) diverge(List<Phase> phases, int seed) {
      final gen = SyntheticDayGenerator(seed: seed).generate(phases);
      final e = TrackingEngine(dayId: 'freeze');
      var fi = 0, pi = 0, seen = 0, compared = 0;
      var worstSki = 0.0, worstDrop = 0.0, worstMax = 0.0;
      for (var t = gen.pressures.first.ts; t <= gen.pressures.last.ts; t += 1000) {
        while (fi < gen.fixes.length && gen.fixes[fi].ts <= t) {
          e.addFix(gen.fixes[fi++]);
        }
        while (pi < gen.pressures.length && gen.pressures[pi].ts <= t) {
          e.addPressure(gen.pressures[pi++]);
        }
        e.tick(t);
        if (e.recomputes == seen || e.points.length < 30) continue;
        seen = e.recomputes;
        compared++;
        final full = TrackingEngine.computeDay('full', e.points).stats;
        final dSki = (e.stats.skiDistanceM - full.skiDistanceM).abs();
        final dDrop = (e.stats.dropM - full.dropM).abs();
        final dMax = (e.stats.maxSpeedMs - full.maxSpeedMs).abs();
        if (dSki > worstSki) worstSki = dSki;
        if (dDrop > worstDrop) worstDrop = dDrop;
        if (dMax > worstMax) worstMax = dMax;
      }
      return (
        worstSki,
        worstDrop,
        worstMax,
        'seed $seed: worst Δski ${worstSki.toStringAsFixed(1)} m, Δdrop ${worstDrop.toStringAsFixed(1)} m, '
            'Δmax ${worstMax.toStringAsFixed(2)} m/s over $compared passes'
      );
    }

    /// Everything the case list names, plus the founder's day.
    final profiles = <String, List<Phase>>{
      'chairlift': SkiProfiles.chairlift,
      'gondolaFlatSpan': SkiProfiles.gondolaFlatSpan,
      'tbar': SkiProfiles.tbar,
      'funicular': SkiProfiles.funicular,
      'gondolaDownAfterRun': SkiProfiles.gondolaDownAfterRun,
      'runOnly': SkiProfiles.runOnly,
      'realDescent': SkiProfiles.realDescent,
      'gondolaDownMidStation': SkiProfiles.gondolaDownMidStation,
      'funicularTunnel': SkiProfiles.funicularTunnel,
      'beginnerGondolaHome': SkiProfiles.beginnerGondolaHome,
      'schuss': SkiProfiles.schuss,
      'catTrack': SkiProfiles.catTrack,
      'skiBus': SkiProfiles.skiBus,
      'liftQueue': SkiProfiles.liftQueue,
      'magicCarpet': SkiProfiles.magicCarpet,
    };

    for (final e in profiles.entries) {
      test(e.key, () {
        for (final seed in [5, 21, 42]) {
          final (ski, drop, max, why) = diverge(e.value, seed);
          // 1 m / 1 m / 0,01 m/s: the splice is exact on every one of these
          // profiles, not merely close. Anything above this bound means a rule
          // reached behind the freeze line.
          expect(ski, lessThanOrEqualTo(1), reason: '${e.key} $why');
          expect(drop, lessThanOrEqualTo(1), reason: '${e.key} $why');
          expect(max, lessThanOrEqualTo(0.01), reason: '${e.key} $why');
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
    }

    test('gondolaDownDropout: the profile finding C was measured on', () {
      // Round 2 diverged by 3.754,9 m here, because the ride the descending pass
      // carves starts 1.845 s before the pass could see it — behind the freeze
      // line. It is exact now, and it stays exact whichever way the flag goes:
      // with the rule off nothing reaches that far, with it on the window does.
      for (final seed in [5, 21, 42]) {
        final (ski, drop, max, why) = diverge(SkiProfiles.gondolaDownDropout, seed);
        expect(ski, lessThanOrEqualTo(1), reason: why);
        expect(drop, lessThanOrEqualTo(1), reason: why);
        expect(max, lessThanOrEqualTo(0.01), reason: why);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('the default day, around a signal loss, no longer diverges', () {
      // Before the freeze was moved to a raw-interval boundary two intervals
      // behind the window, the segment in front of a five-minute barometric
      // lift inside a GPS hole could still be trimmed by a later full pass
      // (up to ~95 m of ski distance). An independent review measured 0 m on
      // seeds 3, 5, 21 and 42 after the rework, so this pins the exact case
      // instead of allowing it. The finished day is always exact, which the
      // last two expectations check.
      for (final seed in [3, 5, 21, 42]) {
        final (ski, drop, max, why) = diverge(SyntheticDayGenerator.defaultDay, seed);
        expect(ski, lessThanOrEqualTo(1), reason: why);
        expect(drop, lessThanOrEqualTo(1), reason: why);
        expect(max, lessThanOrEqualTo(0.01), reason: 'the top speed never diverges — $why');
      }
      final live = day(SyntheticDayGenerator.defaultDay, seed: 21, dayId: 'dd');
      final offline = TrackingEngine.computeDay('dd', live.points);
      expect(offline.stats.skiDistanceM, closeTo(live.stats.skiDistanceM, 0.01));
      expect(offline.stats.dropM, closeTo(live.stats.dropM, 0.01));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
