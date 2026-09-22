import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/tracking/synthetic.dart';
import 'package:dropline/tracking/tracking.dart';

/// Feeds a synthetic day live (1 Hz ticks with the wall clock at each second).
DayComputation runLive(SyntheticDay day, TrackingEngine e) {
  final fixes = day.fixes;
  final press = day.pressures;
  var fi = 0, pi = 0;
  final start = (press.isNotEmpty ? press.first.ts : fixes.first.ts);
  final end = (press.isNotEmpty ? press.last.ts : fixes.last.ts);
  for (var ts = start; ts <= end; ts += 1000) {
    while (fi < fixes.length && fixes[fi].ts <= ts) {
      e.addFix(fixes[fi++]);
    }
    while (pi < press.length && press[pi].ts <= ts) {
      e.addPressure(press[pi++]);
    }
    e.tick(ts);
  }
  return e.finish();
}

void main() {
  group('synthetic day', () {
    final day = SyntheticDayGenerator(seed: 7).generate();

    test('generator expectations are sane', () {
      expect(day.expectedRuns, 3);
      expect(day.expectedLifts, 2);
      expect(day.expectedDropM, 1900);
    });

    test('live run/lift counts and vertical match the truth', () {
      final e = TrackingEngine(dayId: 'd1');
      final r = runLive(day, e);
      final runs = r.segments.where((s) => s.kind == SegmentKind.run).toList();
      final lifts = r.segments.where((s) => s.kind == SegmentKind.lift).toList();
      expect(runs.length, day.expectedRuns, reason: r.segments.map((s) => '${s.kind.name}:${s.durationMs ~/ 1000}s/${s.dropM.round()}m').join(', '));
      expect(lifts.length, day.expectedLifts);
      expect(r.stats.dropM, closeTo(day.expectedDropM, day.expectedDropM * 0.03));
      expect(r.stats.hasBarometer, isTrue);
      // confirmed max needs 2 of 3 candidates within 15 %, so it sits just under the single-second peak
      expect(r.stats.maxSpeedMs, closeTo(day.expectedMaxSpeedMs, day.expectedMaxSpeedMs * 0.15));
      expect(r.stats.signalLossMs, 0); // the gondola GPS dropout is a lift (barometer keeps rising), not signal loss
      expect(r.stats.skiDistanceM, greaterThan(0));
      expect(r.stats.liftDistanceM, greaterThan(0));
    });

    test('live == offline', () {
      final e = TrackingEngine(dayId: 'd1');
      final live = runLive(day, e);
      final offline = TrackingEngine.computeDay('d1', live.points);
      expect(offline.segments.length, live.segments.length);
      for (var i = 0; i < live.segments.length; i++) {
        expect(offline.segments[i].kind, live.segments[i].kind);
        expect(offline.segments[i].startTs, live.segments[i].startTs);
        expect(offline.segments[i].endTs, live.segments[i].endTs);
        expect(offline.segments[i].dropM, closeTo(live.segments[i].dropM, 0.01));
      }
      expect(offline.stats.runCount, live.stats.runCount);
      expect(offline.stats.dropM, closeTo(live.stats.dropM, 0.01));
      expect(offline.stats.maxSpeedMs, closeTo(live.stats.maxSpeedMs, 0.01));
    });

    test('no run overlaps a lift and runs are numbered', () {
      final r = runLive(day, TrackingEngine(dayId: 'd1'));
      for (var i = 1; i < r.segments.length; i++) {
        expect(r.segments[i].startTs, greaterThanOrEqualTo(r.segments[i - 1].endTs));
      }
      final nums = r.segments.where((s) => s.kind == SegmentKind.run).map((s) => s.runNumber).toList();
      expect(nums, [1, 2, 3]);
    });
  });

  test('a long GPS dropout while stopped is signal loss, not pause', () {
    const phases = [
      Phase.stop(60),
      Phase.lift(900, 500),
      Phase.lift(0, 300, avgSpeedMs: 0, dropoutFrom: 0, dropoutTo: 300), // parked in a hut without GPS
      Phase.run(900, 400),
      Phase.stop(30),
    ];
    final day = SyntheticDayGenerator(seed: 11).generate(phases);
    final r = runLive(day, TrackingEngine(dayId: 'd3'));
    expect(r.stats.signalLossMs, greaterThan(200000));
    expect(r.stats.runCount, 1);
    expect(r.stats.liftCount, 1);
  });

  test('GPS-only day (no barometer) still finds the runs', () {
    final day = SyntheticDayGenerator(seed: 3, withBarometer: false).generate();
    final r = runLive(day, TrackingEngine(dayId: 'd2'));
    expect(r.stats.hasBarometer, isFalse);
    expect(r.stats.runCount, day.expectedRuns);
    expect(r.stats.dropM, closeTo(day.expectedDropM, day.expectedDropM * 0.08));
  });

  test('gate rejects bad fixes', () {
    final g = FixGate();
    final ok = g.evaluate(const RawFix(ts: 1000, lat: 47, lon: 12, hAccM: 5, speedMs: 3, speedAccMs: 0.5, gpsAltM: 1000, vAccM: 8), 1000);
    expect(ok.accepted, isTrue);
    expect(ok.speedTrusted, isTrue);
    expect(ok.maxCandidate, isTrue);
    expect(ok.altAnchor, isTrue);
    expect(g.evaluate(const RawFix(ts: 2000, lat: 47, lon: 12, hAccM: 40), 2000).reason, RejectReason.hAcc);
    expect(g.evaluate(const RawFix(ts: 500, lat: 47, lon: 12, hAccM: 5), 2000).reason, RejectReason.nonMonotonic);
    expect(g.evaluate(const RawFix(ts: 2000, lat: 47.01, lon: 12, hAccM: 5), 2000).reason, RejectReason.impliedSpeed);
    expect(g.evaluate(const RawFix(ts: 2000, lat: 47, lon: 12, hAccM: 5, isMocked: true), 2000).reason, RejectReason.mocked);
    expect(g.evaluate(const RawFix(ts: 2000, lat: 47, lon: 12, hAccM: 5), 9000).reason, RejectReason.stale);
  });

  test('max speed needs 2 of 3 agreeing candidates', () {
    final m = MaxSpeedTracker();
    expect(m.offer(10, 1), isFalse); // single candidate
    expect(m.offer(10.5, 2), isTrue); // two agree
    expect(m.offer(30, 3), isFalse); // spike alone
    expect(m.offer(11, 4), isTrue); // 11 > 10.5 and agrees with 10.5
  });

  test('altitude fuser corrects barometric scale after a lift', () {
    final f = AltitudeFuser();
    var ts = 0;
    // anchor at 800 m with baro reading scaled 0.97
    double baro(double hTrue) => hypsometricInverse((hTrue - 800) * 0.97 + 800);
    for (var i = 0; i < 12; i++) {
      ts += 1000;
      f.addPressure(PressureSample(ts: ts, hPa: baro(800)));
      f.addFix(RawFix(ts: ts, lat: 47, lon: 12, hAccM: 5, gpsAltM: 800, vAccM: 8), altAnchor: true, nowMs: ts);
    }
    expect(f.isAnchored, isTrue);
    expect(f.value!, closeTo(800, 3));
    for (var h = 800.0; h <= 1900; h += 2) {
      ts += 1000;
      f.addPressure(PressureSample(ts: ts, hPa: baro(h)));
      f.addFix(RawFix(ts: ts, lat: 47, lon: 12, hAccM: 5, gpsAltM: h, vAccM: 8), altAnchor: true, nowMs: ts);
    }
    expect(f.scaleFactor, greaterThan(1.0));
    expect(f.value!, closeTo(1900, 15));
  });
}

/// Pressure for a barometric altitude (inverse hypsometric).
double hypsometricInverse(double hBaro) =>
    TrackingConfig.seaLevelHpa * math.pow(1 - hBaro / TrackingConfig.hypsometricScaleM, 1 / TrackingConfig.hypsometricExponent);
