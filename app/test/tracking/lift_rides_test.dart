import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/synthetic.dart';
import 'package:slopetrack/tracking/tracking.dart';

import 'cable_support.dart';

/// Lift rides must never contribute to speed or skied distance (docs/TRACKING.md).
void main() {
  final allProfiles = <String, List<Phase>>{
    'chairlift': SkiProfiles.chairlift,
    'gondola down': SkiProfiles.gondolaDownAfterRun,
    'flat span': SkiProfiles.gondolaFlatSpan,
    'funicular': SkiProfiles.funicular,
    'tbar': SkiProfiles.tbar,
    'run only': SkiProfiles.runOnly,
    'real descent': SkiProfiles.realDescent,
    'queue': SkiProfiles.liftQueue,
    'default day': SyntheticDayGenerator.defaultDay,
  };

  group('gondola riding DOWN into the valley (the founder\'s case)', () {
    final withRide = day(SkiProfiles.gondolaDownAfterRun, dayId: 'down');
    final baseline = day(SkiProfiles.runOnly, dayId: 'base');

    test('the valley ride is a lift, not a run', () {
      final kinds = withRide.segments.map((s) => s.kind).toList();
      if (!descentRides) {
        // SHIPPED: the ride is not reclassified (TrackingConfig.descentRidesEnabled).
        // The 30 s stop at the top station is shorter than runStopAbsorbS, so the
        // segmenter never even ends the run — the descent and the cabin ride home
        // are one 12-minute "run" of 8,2 km. That is the documented price of the
        // switch-off (docs/TRACKING.md → Grenzen); what it buys is
        // ski_road_sweep_test.dart, 4.320 ski roads and not one deleted run.
        expect(kinds.where((k) => k == SegmentKind.run).length, 1, reason: describe(withRide.segments));
        expect(kinds.where((k) => k == SegmentKind.lift).length, 1, reason: 'only the way up — ${describe(withRide.segments)}');
        expect(withRide.stats.ascentM, closeTo(baseline.stats.ascentM, 2), reason: 'and a descent is never ascent');
        return;
      }
      expect(kinds.where((k) => k == SegmentKind.run).length, 1, reason: describe(withRide.segments));
      expect(kinds.where((k) => k == SegmentKind.lift).length, 2, reason: describe(withRide.segments));
      final valley = withRide.segments.lastWhere((s) => s.kind == SegmentKind.lift);
      expect(valley.durationMs, greaterThan(300000), reason: 'the whole 6 min ride is one lift');
      expect(valley.endAltM - valley.startAltM, lessThan(-500), reason: 'it goes down');
      expect(valley.dropM, 0, reason: 'a ride down adds no ascent');
      // the true ride speed is 7 m/s = 25 km/h; the measured value is inflated by
      // the 4 m GPS noise, but it stays inside the cable band either way
      expect(valley.avgSpeedMs, lessThan(TrackingConfig.cableMaxSpeedMs));
      expect(valley.distanceM, greaterThan(2000), reason: 'and 2.5 km of it');
      expect(valley.maxSpeedMs, 0, reason: 'a lift carries no top speed');
    });

    test('ski distance, drop and top speed against the day without the ride', () {
      if (!descentRides) {
        // The measured price, written out so it is never a surprise: the cabin's
        // 2,5 km and 600 m land in the ski numbers. What does *not* move is the
        // top speed — the real descent peaks at 21–22 m/s, far above the cabin's
        // 7 — and the ascent stays honest.
        expect(withRide.stats.skiDistanceM, closeTo(baseline.stats.skiDistanceM + 3350, 250),
            reason: 'the cabin\'s kilometres are booked as skiing — ${describe(withRide.segments)}');
        expect(withRide.stats.dropM, closeTo(baseline.stats.dropM + 600, 30), reason: 'and its 600 m as drop');
        expect(withRide.stats.maxSpeedMs, closeTo(baseline.stats.maxSpeedMs, 0.01),
            reason: 'but never the top speed: the descent is three times faster');
        expect(withRide.stats.liftCount, baseline.stats.liftCount);
        expect(withRide.stats.ascentM, closeTo(baseline.stats.ascentM, 2));
        return;
      }
      // Tolerance 20 m, not 0: with the ride the run ends at the standstill in
      // the top station, without it the run simply runs to the end of the day,
      // so the two differ by the metre or two of GPS noise that the standstill
      // itself accumulates. 20 m is 0.4 % of a 4.8 km descent.
      expect(withRide.stats.runCount, baseline.stats.runCount);
      expect(withRide.stats.skiDistanceM, closeTo(baseline.stats.skiDistanceM, 20));
      expect(withRide.stats.dropM, closeTo(baseline.stats.dropM, 2));
      expect(withRide.stats.maxSpeedMs, closeTo(baseline.stats.maxSpeedMs, 0.01));
      expect(withRide.stats.avgSkiSpeedMs, closeTo(baseline.stats.avgSkiSpeedMs, 0.05));
      expect(withRide.stats.liftDistanceM, greaterThan(baseline.stats.liftDistanceM + 2000), reason: 'the ride counts as lift distance');
      // the raw numbers, so a regression is obvious at a glance (seed 21)
      expect(withRide.stats.skiDistanceM, closeTo(4795, 20), reason: 'one real descent, ~4.8 km');
      expect(withRide.stats.maxSpeedMs, closeTo(21.7, 1), reason: 'the descent, ~78 km/h — not the ride\'s 7 m/s');
      expect(withRide.stats.liftCount, baseline.stats.liftCount + 1);
      expect(withRide.stats.ascentM, closeTo(baseline.stats.ascentM, 1), reason: 'a ride down is not ascent');
    });

    test('the day max speed is always a run max speed', () {
      if (descentRides) {
        final valley = withRide.segments.lastWhere((s) => s.kind == SegmentKind.lift);
        expect(withRide.stats.maxSpeedSegmentId, isNot(valley.id));
      }
      expect(withRide.stats.maxSpeedMs, maxOverRuns(withRide.segments));
      for (final l in withRide.segments.where((s) => s.kind == SegmentKind.lift)) {
        expect(l.maxSpeedMs, 0, reason: 'a lift never carries a max speed');
      }
    });

    test('live == offline for the ride', () {
      final offline = TrackingEngine.computeDay('down', withRide.points);
      expect(offline.segments.map((s) => s.kind).toList(), withRide.segments.map((s) => s.kind).toList());
      for (var i = 0; i < offline.segments.length; i++) {
        expect(offline.segments[i].startTs, withRide.segments[i].startTs);
        expect(offline.segments[i].endTs, withRide.segments[i].endTs);
      }
      expect(offline.stats.maxSpeedMs, closeTo(withRide.stats.maxSpeedMs, 0.01));
      expect(offline.stats.skiDistanceM, closeTo(withRide.stats.skiDistanceM, 0.01));
    });
  });

  test('chairlift 2.5 m/s, +400 m in 5 min → one lift, no ski metres, no top speed', () {
    final r = day(SkiProfiles.chairlift, dayId: 'chair');
    expect(r.stats.liftCount, 1, reason: describe(r.segments));
    expect(r.stats.runCount, 0);
    expect(r.stats.skiDistanceM, 0);
    expect(r.stats.maxSpeedMs, 0);
    expect(r.stats.ascentM, closeTo(400, 30));
    expect(r.stats.liftDistanceM, greaterThan(500));
  });

  test('gondola 6 m/s with a 40 s flat mid-span → ONE lift segment, not three', () {
    final r = day(SkiProfiles.gondolaFlatSpan, dayId: 'flat');
    final lifts = r.segments.where((s) => s.kind == SegmentKind.lift).toList();
    expect(lifts.length, 1, reason: describe(r.segments));
    expect(lifts.single.durationMs, greaterThan(250000), reason: 'the flat span stays inside the ride');
    expect(r.stats.runCount, 0);
    expect(r.stats.skiDistanceM, 0);
    expect(r.stats.maxSpeedMs, 0);
  });

  test('T-bar 3 m/s, +250 m → lift, no ski metres', () {
    final r = day(SkiProfiles.tbar, dayId: 'tbar');
    expect(r.stats.liftCount, 1, reason: describe(r.segments));
    expect(r.stats.runCount, 0);
    expect(r.stats.skiDistanceM, 0);
    expect(r.stats.maxSpeedMs, 0);
    expect(r.stats.ascentM, closeTo(250, 25));
    expect(r.stats.liftDistanceM, greaterThan(1000));
  });

  test('funicular 10 m/s → lift, not a vehicle-flagged OTHER', () {
    final r = day(SkiProfiles.funicular, dayId: 'funi');
    expect(r.stats.liftCount, 1, reason: describe(r.segments));
    expect(r.stats.vehicleFlag, isFalse);
    expect(r.stats.runCount, 0);
    expect(r.stats.skiDistanceM, 0);
    expect(r.stats.otherMs, lessThan(120000), reason: 'the ride itself is not OTHER');
  });

  test('a real descent (8–19 m/s, turns) stays a run and keeps its top speed', () {
    final gen = SyntheticDayGenerator(seed: 21).generate(SkiProfiles.realDescent);
    final r = runLiveDay(gen, dayId: 'real');
    expect(r.stats.runCount, 1, reason: describe(r.segments));
    expect(r.stats.liftCount, 1);
    expect(r.stats.dropM, closeTo(650, 40));
    expect(r.stats.skiDistanceM, greaterThan(3000));
    expect(r.stats.maxSpeedMs, closeTo(gen.expectedMaxSpeedMs, gen.expectedMaxSpeedMs * 0.15));
    expect(r.stats.maxSpeedMs, greaterThan(TrackingConfig.cableMaxSpeedMs), reason: 'a real descent is faster than any cable');
  });

  test('4 min of lift-queue shuffling: no ski distance and the two runs stay apart', () {
    final r = day(SkiProfiles.liftQueue, dayId: 'queue');
    expect(r.stats.runCount, 2, reason: describe(r.segments));
    final runs = r.segments.where((s) => s.kind == SegmentKind.run).toList();
    expect(runs.first.endTs, lessThan(runs.last.startTs));
    expect(r.stats.skiDistanceM, closeTo(runs.first.distanceM + runs.last.distanceM, 0.01));
    final queue = r.segments.where((s) => s.startTs >= runs.first.endTs && s.endTs <= runs.last.startTs).toList();
    expect(queue, isNotEmpty);
    expect(queue.every((s) => s.kind != SegmentKind.run), isTrue, reason: describe(r.segments));
    expect(r.stats.maxSpeedMs, maxOverRuns(r.segments));
  });

  test('DayStats.maxSpeedMs never exceeds the max over RUN segments', () {
    for (final (name, phases) in allProfiles.entries.map((e) => (e.key, e.value))) {
      for (final seed in [3, 21]) {
        final r = day(phases, seed: seed, dayId: 'inv');
        expect(r.stats.maxSpeedMs, lessThanOrEqualTo(maxOverRuns(r.segments)),
            reason: '$name (seed $seed): ${describe(r.segments)}');
        final lifts = r.segments.where((s) => s.kind == SegmentKind.lift);
        for (final l in lifts) {
          expect(l.maxSpeedMs, 0, reason: '$name: a lift never carries a max speed');
        }
      }
    }
  });

  test('live == offline for every profile', () {
    for (final (name, phases) in allProfiles.entries.map((e) => (e.key, e.value))) {
      final live = day(phases, dayId: 'lo');
      final offline = TrackingEngine.computeDay('lo', live.points);
      expect(offline.segments.length, live.segments.length,
          reason: '$name: live ${describe(live.segments)} | offline ${describe(offline.segments)}');
      for (var i = 0; i < live.segments.length; i++) {
        final a = live.segments[i], b = offline.segments[i];
        expect(b.kind, a.kind, reason: '$name segment $i');
        expect(b.startTs, a.startTs, reason: '$name segment $i');
        expect(b.endTs, a.endTs, reason: '$name segment $i');
        expect(b.distanceM, closeTo(a.distanceM, 0.01), reason: '$name segment $i');
        expect(b.maxSpeedMs, closeTo(a.maxSpeedMs, 1e-9), reason: '$name segment $i');
        expect(b.dropM, closeTo(a.dropM, 0.01), reason: '$name segment $i');
      }
      expect(offline.stats.runCount, live.stats.runCount, reason: name);
      expect(offline.stats.liftCount, live.stats.liftCount, reason: name);
      expect(offline.stats.skiDistanceM, closeTo(live.stats.skiDistanceM, 0.01), reason: name);
      expect(offline.stats.liftDistanceM, closeTo(live.stats.liftDistanceM, 0.01), reason: name);
      expect(offline.stats.maxSpeedMs, closeTo(live.stats.maxSpeedMs, 0.01), reason: name);
      expect(offline.stats.ascentM, closeTo(live.stats.ascentM, 0.01), reason: name);
      expect(offline.stats.avgSkiSpeedMs, closeTo(live.stats.avgSkiSpeedMs, 0.01), reason: name);
    }
  });

  test('the live top speed does not survive the reclassification', () {
    // Nothing but two gondola rides: up, and then down into the valley. The
    // segmenter needs ~1 min to be sure the descent is a cable, so the live
    // display does briefly see a candidate — it must be gone by the time
    // finalize has rewritten the ride as a lift, not frozen in for the day.
    final phases = [
      const Phase.stop(60),
      const Phase.cable(600, 300, avgSpeedMs: 5),
      const Phase.stop(30),
      const Phase.cable(-600, 360, avgSpeedMs: 7),
      const Phase.stop(60),
    ];
    final gen = SyntheticDayGenerator(seed: 21).generate(phases);
    final e = TrackingEngine(dayId: 'sticky');
    var fi = 0, pi = 0;
    var peak = 0.0;
    var lastLiveMax = 0.0;
    for (var ts = gen.pressures.first.ts; ts <= gen.pressures.last.ts; ts += 1000) {
      while (fi < gen.fixes.length && gen.fixes[fi].ts <= ts) {
        e.addFix(gen.fixes[fi++]);
      }
      while (pi < gen.pressures.length && gen.pressures[pi].ts <= ts) {
        e.addPressure(gen.pressures[pi++]);
      }
      final t = e.tick(ts);
      lastLiveMax = t.live.stats.maxSpeedMs;
      if (lastLiveMax > peak) peak = lastLiveMax;
    }
    final r = e.finish();
    // What this test is really about — the live number never keeps something the
    // finished day threw away — holds either way, and it is the assertion that
    // survives the switch-off.
    expect(lastLiveMax, closeTo(r.stats.maxSpeedMs, 0.01),
        reason: 'the live display must not keep a speed finalize threw away — ${describe(r.segments)}');
    expect(peak, lessThan(9), reason: 'and it can never exceed the ride speed (7 m/s)');
    if (!descentRides) {
      // SHIPPED: the ride home is a run of its own, so the day ends with the
      // cabin's 7 m/s as its top speed. Live and final agree on it.
      expect(r.stats.runCount, 1, reason: describe(r.segments));
      expect(r.stats.maxSpeedMs, greaterThan(6), reason: describe(r.segments));
      return;
    }
    expect(r.stats.runCount, 0, reason: describe(r.segments));
    expect(r.stats.skiDistanceM, 0);
    expect(r.stats.maxSpeedMs, 0);
    expect(lastLiveMax, 0);
  });

  test('over 10 seeds: the valley ride never touches the top speed or the ascent', () {
    for (final seed in [1, 2, 3, 5, 8, 13, 21, 34, 42, 99]) {
      final withRide = day(SkiProfiles.gondolaDownAfterRun, seed: seed, dayId: 'd$seed');
      final baseline = day(SkiProfiles.runOnly, seed: seed, dayId: 'b$seed');
      final why = 'seed $seed: ${describe(withRide.segments)}';
      // These three hold with the descending rule on *and* off, and they are the
      // ones the founder sees: the cabin is three times slower than his descent,
      // so it can never become his top speed, and a ride down is never ascent.
      expect(withRide.stats.maxSpeedMs, closeTo(baseline.stats.maxSpeedMs, 0.01), reason: why);
      expect(withRide.stats.ascentM, closeTo(baseline.stats.ascentM, 2), reason: why);
      expect(withRide.stats.maxSpeedMs, maxOverRuns(withRide.segments), reason: why);
      if (!descentRides) {
        // SHIPPED: the cabin's kilometres are booked as skiing (docs/TRACKING.md
        // → Grenzen), and there is no second lift.
        expect(withRide.stats.liftCount, baseline.stats.liftCount, reason: why);
        expect(withRide.stats.skiDistanceM, greaterThan(baseline.stats.skiDistanceM + 3000), reason: why);
        continue;
      }
      expect(withRide.stats.runCount, baseline.stats.runCount, reason: why);
      expect(withRide.stats.skiDistanceM, closeTo(baseline.stats.skiDistanceM, 20), reason: why);
      expect(withRide.stats.avgSkiSpeedMs, closeTo(baseline.stats.avgSkiSpeedMs, 0.05), reason: why);
      expect(withRide.stats.liftCount, baseline.stats.liftCount + 1, reason: why);
      // …and the false-positive guards hold for the same seed
      final real = day(SkiProfiles.realDescent, seed: seed, dayId: 'r$seed');
      expect(real.stats.runCount, 1, reason: 'seed $seed: ${describe(real.segments)}');
      expect(real.stats.maxSpeedMs, greaterThan(TrackingConfig.cableMaxSpeedMs), reason: 'seed $seed');
      expect(day(SkiProfiles.liftQueue, seed: seed, dayId: 'q$seed').stats.runCount, 2, reason: 'seed $seed');
    }
  });

  group('up and straight back down on the same gondola', () {
    // The purest form of the founder's case: the gondola *is* the way home, so
    // an ascent and a descent share one station. They must stay two rides — one
    // merged interval would have no net altitude change and the validity rule
    // would drop it, and its 5.7 km, into the "other" bucket.
    for (final pauseS in [30, 60, 120]) {
      test('${pauseS}s at the top station', () {
        final phases = [
          const Phase.stop(60),
          const Phase.cable(600, 300, avgSpeedMs: 5),
          Phase.stop(pauseS),
          const Phase.cable(-600, 360, avgSpeedMs: 7),
          const Phase.stop(60),
        ];
        for (final seed in [5, 21]) {
          final r = day(phases, seed: seed, dayId: 'both');
          final why = 'seed $seed: ${describe(r.segments)}';
          // True in both worlds: the way up is one lift, it is the *only* ascent
          // (the merged-interval trap this group was written for), live == offline.
          expect(r.stats.ascentM, closeTo(600, 40), reason: '$why — only the way up is ascent');
          final lifts = r.segments.where((s) => s.kind == SegmentKind.lift).toList();
          expect(lifts.first.endAltM - lifts.first.startAltM, greaterThan(500), reason: why);
          final offline = TrackingEngine.computeDay('both', r.points);
          expect(offline.segments.map((s) => s.kind).toList(), r.segments.map((s) => s.kind).toList(), reason: why);
          expect(offline.stats.ascentM, closeTo(r.stats.ascentM, 0.01), reason: why);
          if (!descentRides) {
            // SHIPPED: one lift up, one "run" home of 3,5 km.
            expect(lifts.length, 1, reason: why);
            expect(r.stats.runCount, 1, reason: why);
            expect(r.stats.dropM, closeTo(600, 40), reason: '$why — the way home counts as drop');
            continue;
          }
          expect(r.stats.liftCount, 2, reason: why);
          expect(r.stats.runCount, 0, reason: why);
          expect(r.stats.skiDistanceM, 0, reason: why);
          expect(r.stats.maxSpeedMs, 0, reason: why);
          expect(r.stats.liftDistanceM, greaterThan(5000), reason: why);
          expect(lifts.last.endAltM - lifts.last.startAltM, lessThan(-500), reason: why);
          expect(lifts.last.dropM, 0, reason: why);
        }
      });
    }
  });
}
