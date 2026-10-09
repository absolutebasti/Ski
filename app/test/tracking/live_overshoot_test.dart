import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

import 'cable_support.dart';

/// The live top speed may **lag**, it may never **overshoot**: a number the
/// finished day throws away must not have been on the screen.
///
/// Two cases where it still did, and by how much this suite holds them:
///
/// * **the ski bus.** The road guard cannot classify anything before
///   [TrackingConfig.roadMinDurationS] = 240 s — it needs two hairpins over
///   400 m of path each, and those take minutes. Until then the bus is a
///   provisional RUN showing 40 km/h. Fixed by evaluating the *same* geometry on
///   the open interval from [TrackingConfig.roadLiveMinDurationS] on and holding
///   its peaks back. Nothing is reclassified early; only the number waits.
/// * **the funicular in a tunnel.** The cabin drops out of GPS after 30 s. The
///   open RUN interval then keeps growing in wall-clock time while its fixes stand
///   still, so it crosses `runMinDurationS` on time it has no evidence for and
///   shows 32 km/h — which the finished day, cutting the interval back to the last
///   fix, throws away. Fixed by measuring a run's validity against the span its
///   fixes actually **cover**.
class _Trace {
  _Trace(this.result, this.liveMax);
  final DayComputation result;
  final List<double> liveMax;

  double get peak => liveMax.fold(0, (m, v) => v > m ? v : m);

  /// Seconds the screen showed a top speed above [v].
  int secondsAbove(double v) => liveMax.where((x) => x > v).length;
}

_Trace _trace(List<Phase> phases, int seed) {
  final gen = SyntheticDayGenerator(seed: seed).generate(phases);
  final e = TrackingEngine(dayId: 'over');
  var fi = 0, pi = 0;
  final liveMax = <double>[];
  for (var t = gen.pressures.first.ts; t <= gen.pressures.last.ts; t += 1000) {
    while (fi < gen.fixes.length && gen.fixes[fi].ts <= t) {
      e.addFix(gen.fixes[fi++]);
    }
    while (pi < gen.pressures.length && gen.pressures[pi].ts <= t) {
      e.addPressure(gen.pressures[pi++]);
    }
    liveMax.add(e.tick(t).live.stats.maxSpeedMs);
  }
  return _Trace(e.finish(), liveMax);
}

void main() {
  const seeds = [3, 5, 21, 33, 42];

  test('the ski bus: the 40 km/h on the screen is cut to at most 150 s', () {
    // Before the live road candidate: 40–41 km/h for ~180 s on every seed
    // (roadMinDurationS = 240 s minus the seconds before the run opened).
    for (final seed in seeds) {
      final t = _trace(SkiProfiles.skiBus, seed);
      final why = 'seed $seed: peak ${(t.peak * 3.6).toStringAsFixed(1)} km/h for '
          '${t.secondsAbove(TrackingConfig.roadMinSpeedMs)} s — ${describe(t.result.segments)}';
      // The finished day has no run at all: a bus is OTHER.
      expect(t.result.stats.maxSpeedMs, 0, reason: why);
      expect(t.result.stats.runCount, 0, reason: why);
      // …so every second of a live top speed here is an overshoot. Bounded, and
      // the bound is what improved: the live road candidate fires at
      // roadLiveMinDurationS instead of roadMinDurationS.
      expect(t.secondsAbove(TrackingConfig.roadMinSpeedMs), lessThanOrEqualTo(150), reason: why);
      expect(t.liveMax.last, 0, reason: 'and it is gone by the end of the day — $why');
      // It never exceeds the bus's own speed either.
      expect(t.peak, lessThan(13), reason: why);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the funicular in a tunnel leaks at most two seconds of top speed', () {
    // Before the moving-span rule: 32,2 km/h for ~17 s per seed, because the open
    // RUN interval kept growing on wall-clock time — through the GPS hole in the
    // tunnel and through the standstill in the valley station — until it crossed
    // runMinDurationS on time it had no motion for. Now the two or three seconds
    // in which the cabin's own deceleration still counts as moving are all that is
    // left; closing those means predicting the STOP before the segmenter sees it.
    for (final seed in seeds) {
      final t = _trace(SkiProfiles.funicularTunnel, seed);
      final why = 'seed $seed: peak ${(t.peak * 3.6).toStringAsFixed(1)} km/h for '
          '${t.secondsAbove(0.01)} s — ${describe(t.result.segments)}';
      expect(t.result.stats.maxSpeedMs, 0, reason: why);
      expect(t.result.stats.runCount, 0, reason: why);
      expect(t.secondsAbove(0.01), lessThanOrEqualTo(3), reason: 'measured 17 s before the fix — $why');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a real run is not delayed by either guard', () {
    // Both fixes may only ever *hold back*, so the counter-case matters: a fast,
    // long, hairpin-free valley run-out must show its speed as it happens, and a
    // schuss must too.
    for (final (name, phases, truth) in [
      ('schuss', SkiProfiles.schuss, 19.0),
      ('run-out 10 m/s', [const Phase.stop(60), const Phase.run(400, 420, avgSpeedMs: 10, jitter: 0.12, turnRateDeg: 4), const Phase.stop(60)], 10.0),
    ]) {
      for (final seed in seeds) {
        final t = _trace(phases, seed);
        final why = '$name seed $seed: ${describe(t.result.segments)}';
        expect(t.result.stats.runCount, 1, reason: why);
        expect(t.result.stats.maxSpeedMs, greaterThan(truth - 1.5), reason: why);
        expect(t.liveMax.last, closeTo(t.result.stats.maxSpeedMs, 0.01), reason: 'live == final — $why');
        // The screen has the number well before the day ends: within 60 s of the
        // run's own end, not at finish().
        final runEnd = t.result.segments.lastWhere((s) => s.kind == SegmentKind.run).endTs;
        final firstTs = t.result.points.first.ts;
        final idx = ((runEnd - firstTs) ~/ 1000).clamp(0, t.liveMax.length - 1);
        expect(t.liveMax[idx], closeTo(t.result.stats.maxSpeedMs, 0.01),
            reason: 'the top speed was on the screen when the run ended — $why');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('no profile ever shows a top speed the finished day does not have', () {
    final profiles = <String, List<Phase>>{
      'chairlift': SkiProfiles.chairlift,
      'gondolaFlatSpan': SkiProfiles.gondolaFlatSpan,
      'tbar': SkiProfiles.tbar,
      'funicular': SkiProfiles.funicular,
      'gondolaDownAfterRun': SkiProfiles.gondolaDownAfterRun,
      'gondolaDownMidStation': SkiProfiles.gondolaDownMidStation,
      'gondolaDownDropout': SkiProfiles.gondolaDownDropout,
      'beginnerGondolaHome': SkiProfiles.beginnerGondolaHome,
      'realDescent': SkiProfiles.realDescent,
      'catTrack': SkiProfiles.catTrack,
      'liftQueue': SkiProfiles.liftQueue,
      'magicCarpet': SkiProfiles.magicCarpet,
      'defaultDay': SyntheticDayGenerator.defaultDay,
    };
    for (final e in profiles.entries) {
      for (final seed in [5, 21]) {
        final t = _trace(e.value, seed);
        final finalMax = t.result.stats.maxSpeedMs;
        expect(t.peak, lessThanOrEqualTo(finalMax + 0.01),
            reason: '${e.key} seed $seed: live ${(t.peak * 3.6).toStringAsFixed(1)} km/h vs final '
                '${(finalMax * 3.6).toStringAsFixed(1)} km/h — ${describe(t.result.segments)}');
        expect(finalMax, maxOverRuns(t.result.segments), reason: '${e.key} seed $seed');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
