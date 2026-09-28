import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/segmenter.dart';

/// Drives the 1 Hz state machine with synthetic ticks (speed, altitude, fix/no fix).
class Sim {
  Sim({this.h = 1000});
  final seg = Segmenter();
  double h;
  int ts = 0;
  int? lastFixTs;

  /// [n] ticks at horizontal speed [vH], altitude changing by [dh] per tick.
  Sim run(int n, {required double vH, double dh = 0, bool fix = true}) {
    for (var i = 0; i < n; i++) {
      ts += 1000;
      h += dh;
      if (fix) lastFixTs = ts;
      seg.tick(SegTick(ts: ts, vH: vH, h: h, hasFix: fix, gapMs: fix ? 0 : ts - (lastFixTs ?? ts)));
    }
    return this;
  }

  SegmentKind get state => seg.state;
}

void main() {
  group('STOP enter/exit (stopEnterS = ${TrackingConfig.stopEnterS}, stopExitS = ${TrackingConfig.stopExitS})', () {
    for (final (ticks, expected) in [(9, SegmentKind.other), (10, SegmentKind.stop), (30, SegmentKind.stop)]) {
      test('$ticks slow ticks → $expected', () => expect(Sim().run(ticks, vH: 0.5).state, expected));
    }
    for (final (ticks, expected) in [(2, SegmentKind.stop), (3, SegmentKind.other)]) {
      test('stop, then $ticks ticks ≥ stopExitSpeedMs → $expected', () => expect(Sim().run(10, vH: 0.5).run(ticks, vH: 1.5).state, expected));
    }
    test('creeping below stopExitSpeedMs never leaves STOP', () => expect(Sim().run(10, vH: 0.5).run(30, vH: 1.4).state, SegmentKind.stop));
    test('the stop interval is back-dated by stopEnterS', () {
      final s = Sim().run(20, vH: 3).run(10, vH: 0.5);
      expect(s.seg.open!.kind, SegmentKind.stop);
      expect(s.seg.open!.startTs, s.ts - TrackingConfig.stopEnterS * 1000);
      expect(s.seg.intervals.single.kind, SegmentKind.other);
    });
  });

  group('RUN enter (runEnterVz10Ms = ${TrackingConfig.runEnterVz10Ms}, runEnterSpeedMs = ${TrackingConfig.runEnterSpeedMs})', () {
    for (final (vH, dh, expected) in [(5.0, -1.0, SegmentKind.run), (1.9, -1.0, SegmentKind.other), (5.0, -0.6, SegmentKind.other), (2.0, -0.7, SegmentKind.run)]) {
      test('vH $vH, $dh m/s vertical → $expected', () => expect(Sim().run(20, vH: vH, dh: dh).state, expected));
    }
    test('from STOP a descent starts a run', () => expect(Sim().run(10, vH: 0.5).run(20, vH: 6, dh: -1.2).state, SegmentKind.run));
  });

  group('RUN exit', () {
    test('runStopAbsorbS: ${TrackingConfig.runStopAbsorbS - 1} slow ticks stay in the run, one more → STOP', () {
      final s = Sim().run(20, vH: 5, dh: -1).run(TrackingConfig.runStopAbsorbS - 1, vH: 0);
      expect(s.state, SegmentKind.run);
      s.run(1, vH: 0);
      expect(s.state, SegmentKind.stop);
    });
    test('flat and slow for runFlatS ends the run as OTHER, not STOP', () {
      expect(Sim().run(20, vH: 5, dh: -1).run(100, vH: 1.5).state, SegmentKind.other);
    });
    test('a run is not interrupted by a short slow patch', () {
      expect(Sim().run(20, vH: 5, dh: -1).run(30, vH: 0.5).run(20, vH: 5, dh: -1).state, SegmentKind.run);
    });
  });

  group('LIFT enter/exit', () {
    for (final (vH, expected) in [(4.0, SegmentKind.lift), (8.0, SegmentKind.lift), (9.0, SegmentKind.other)]) {
      test('rising 1 m/s at $vH m/s horizontal → $expected (liftMaxHorizontalSpeedMs = ${TrackingConfig.liftMaxHorizontalSpeedMs})', () {
        expect(Sim().run(40, vH: vH, dh: 1).state, expected);
      });
    }
    test('parked cabin: flat for liftExitS after the climb ends the lift, then STOP', () {
      final s = Sim().run(40, vH: 4, dh: 1).run(70, vH: 0.5);
      expect(s.state, SegmentKind.stop);
      expect(s.seg.intervals.map((i) => i.kind), contains(SegmentKind.lift));
    });
    test('walking off the lift and skiing down leaves LIFT', () {
      final s = Sim().run(40, vH: 4, dh: 1).run(20, vH: 1).run(15, vH: 5, dh: -1.5);
      expect(s.state, isNot(SegmentKind.lift));
    });
  });

  group('vehicle guard (vehicleSpeedMs = ${TrackingConfig.vehicleSpeedMs}, vehicleSustainS = ${TrackingConfig.vehicleSustainS})', () {
    test('needs the full sustain window', () {
      final s = Sim().run(TrackingConfig.vehicleSustainS - 1, vH: 35);
      expect(s.seg.vehicle, isFalse);
      s.run(1, vH: 35);
      expect(s.seg.vehicle, isTrue);
      expect(s.state, SegmentKind.other);
      expect(s.seg.open!.vehicle, isTrue);
    });
    test('30 slow ticks end the vehicle phase and the ride itself carries the flag', () {
      final s = Sim().run(20, vH: 1).run(60, vH: 35).run(29, vH: 5);
      expect(s.seg.vehicle, isTrue);
      s.run(1, vH: 5);
      expect(s.seg.vehicle, isFalse);
      final flagged = s.seg.intervals.where((i) => i.vehicle).toList();
      expect(flagged.length, 1);
      expect(flagged.single.durationMs, greaterThanOrEqualTo(60000));
      expect(s.seg.intervals.first.vehicle, isFalse, reason: 'the walk before the ride is not a vehicle');
      expect(s.seg.open!.vehicle, isFalse);
    });
    test('34 m/s in a run does not count while under the sustain window', () {
      expect(Sim().run(20, vH: 5, dh: -1).run(30, vH: 34, dh: -2).seg.vehicle, isFalse);
    });
  });

  group('no fix (signalLossGapS = ${TrackingConfig.signalLossGapS}, liftGapEnterS = ${TrackingConfig.liftGapEnterS})', () {
    test('a gap of exactly the threshold is not yet signal loss, one second more is', () {
      final s = Sim().run(5, vH: 1).run(TrackingConfig.signalLossGapS, vH: 0, fix: false);
      expect(s.state, SegmentKind.other);
      s.run(1, vH: 0, fix: false);
      expect(s.state, SegmentKind.signalLoss);
      expect(s.seg.motionState, MotionState.unknown);
      s.run(1, vH: 1);
      expect(s.state, SegmentKind.other, reason: 'first fix ends the loss');
    });
    test('barometer climbing during a gap is a gondola: LIFT from the gap start', () {
      final s = Sim().run(5, vH: 1).run(31, vH: 0, dh: 1, fix: false);
      expect(s.state, SegmentKind.lift);
      expect(s.seg.open!.startTs, 5000, reason: 'lift starts where the fixes stopped');
      s.run(100, vH: 0, dh: 1, fix: false);
      expect(s.state, SegmentKind.lift, reason: 'keeps rising, keeps the lift');
    });
    test('a lift whose barometer goes flat for a minute during a long gap becomes signal loss', () {
      final s = Sim().run(5, vH: 1).run(31, vH: 0, dh: 1, fix: false).run(100, vH: 0, dh: 1, fix: false).run(61, vH: 0, fix: false);
      expect(s.state, SegmentKind.signalLoss);
    });
    test('a small climb (< liftGapGainM) during a gap is not a lift', () {
      expect(Sim().run(5, vH: 1).run(40, vH: 0, dh: 0.5, fix: false).state, SegmentKind.other);
    });
  });

  test('open interval, allIntervals and motion-state mapping', () {
    final s = Sim();
    expect(s.seg.open, isNull);
    s.run(10, vH: 0.5);
    expect(s.seg.allIntervals.length, s.seg.intervals.length + 1);
    expect(s.seg.open!.kind, SegmentKind.stop);
    expect(s.seg.motionState, MotionState.stop);
    s.run(20, vH: 6, dh: -1.2);
    expect(s.seg.motionState, MotionState.run);
    s.run(60, vH: 4, dh: 1).run(0, vH: 0);
    expect(s.seg.motionState, MotionState.lift);
    // stop exit (3 s of movement) precedes run detection; finalize merges that sliver away
    expect(s.seg.intervals.map((i) => i.kind).toList(), [SegmentKind.stop, SegmentKind.other, SegmentKind.run]);
    for (var i = 1; i < s.seg.intervals.length; i++) {
      expect(s.seg.intervals[i].startTs, s.seg.intervals[i - 1].endTs, reason: 'intervals are contiguous');
    }
  });
}
