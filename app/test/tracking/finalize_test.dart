import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/finalize.dart';
import 'package:slopetrack/tracking/segmenter.dart';

/// finalizeSegments validity/merge/snap rules and the day-stats aggregate.
void main() {
  const dayId = 'd';
  TrackPoint p(int s, double alt, {double speed = 10, bool accepted = true, int? hr}) => TrackPoint(
        ts: s * 1000, lat: 47 + s * speed / 111320, lon: 12, hAccM: 5, speedMs: speed, speedAccMs: 0.5, fusedAltM: alt, accepted: accepted, heartRateBpm: hr,
      );
  /// Points for seconds [from, to] with a piecewise altitude function.
  List<TrackPoint> track(int from, int to, double Function(int s) alt) => [for (var s = from; s <= to; s++) p(s, alt(s))];
  double lin(int s, int s0, int s1, double a0, double a1) => a0 + (a1 - a0) * (s - s0) / (s1 - s0);
  RawInterval iv(SegmentKind k, int fromS, int toS, {bool vehicle = false}) => RawInterval(kind: k, startTs: fromS * 1000, endTs: toS * 1000, vehicle: vehicle);

  group('run validity (runMinDurationS = ${TrackingConfig.runMinDurationS}, runMinDropM = ${TrackingConfig.runMinDropM})', () {
    for (final (dur, drop, expected) in [(60, 40.0, SegmentKind.run), (59, 100.0, SegmentKind.other), (60, 39.9, SegmentKind.other), (120, 300.0, SegmentKind.run)]) {
      test('$dur s, $drop m → $expected', () {
        final out = finalizeSegments([iv(SegmentKind.run, 0, dur)], track(0, dur, (s) => lin(s, 0, dur, 1000, 1000 - drop)), dayId: dayId);
        expect(out.single.kind, expected);
      });
    }
  });

  group('lift validity (liftMinDurationS = ${TrackingConfig.liftMinDurationS}, liftMinGainM = ${TrackingConfig.liftMinGainM})', () {
    for (final (dur, gain, expected) in [(60, 30.0, SegmentKind.lift), (59, 100.0, SegmentKind.other), (60, 29.9, SegmentKind.other)]) {
      test('$dur s, $gain m → $expected', () {
        final out = finalizeSegments([iv(SegmentKind.lift, 0, dur)], track(0, dur, (s) => lin(s, 0, dur, 1000, 1000 + gain)), dayId: dayId);
        expect(out.single.kind, expected);
        if (expected == SegmentKind.lift) expect(out.single.dropM, closeTo(gain, 1e-6));
      });
    }
  });

  test('adjacent intervals of the same kind merge', () {
    final out = finalizeSegments([iv(SegmentKind.other, 0, 30), iv(SegmentKind.other, 30, 60), iv(SegmentKind.stop, 60, 90)], track(0, 90, (_) => 1000), dayId: dayId);
    expect(out.map((s) => s.kind).toList(), [SegmentKind.other, SegmentKind.stop]);
    expect(out.first.startTs, 0);
    expect(out.first.endTs, 60000);
  });

  group('runs separated by a short stop merge (runStopAbsorbS = ${TrackingConfig.runStopAbsorbS})', () {
    List<Segment> build(int gap, {int firstIdx = 0, int firstRunNumber = 1}) {
      final raw = [iv(SegmentKind.run, 0, 120), iv(SegmentKind.stop, 120, 120 + gap), iv(SegmentKind.run, 120 + gap, 240 + gap)];
      final pts = track(0, 240 + gap, (s) => s <= 120 ? lin(s, 0, 120, 1000, 900) : (s <= 120 + gap ? 900 : lin(s, 120 + gap, 240 + gap, 900, 800)));
      return finalizeSegments(raw, pts, dayId: dayId, firstIdx: firstIdx, firstRunNumber: firstRunNumber);
    }

    test('44 s stop → one run with the combined drop', () {
      final out = build(44);
      expect(out.single.kind, SegmentKind.run);
      expect(out.single.dropM, closeTo(200, 1e-6));
      expect(out.single.runNumber, 1);
      expect(out.single.endTs, 284000);
    });
    test('45 s stop → two runs and a pause', () {
      final out = build(45);
      expect(out.map((s) => s.kind).toList(), [SegmentKind.run, SegmentKind.stop, SegmentKind.run]);
      expect(out.map((s) => s.runNumber).toList(), [1, null, 2]);
      expect(out.map((s) => s.idx).toList(), [0, 1, 2]);
    });
    test('firstIdx / firstRunNumber offset ids and numbering for a spliced tail', () {
      final out = build(45, firstIdx: 3, firstRunNumber: 2);
      expect(out.map((s) => s.idx).toList(), [3, 4, 5]);
      expect(out.map((s) => s.id).toList(), ['d-3', 'd-4', 'd-5']);
      expect(out.map((s) => s.runNumber).toList(), [2, null, 3]);
    });
  });

  test('a vehicle interval is never a run and is flagged', () {
    final out = finalizeSegments([iv(SegmentKind.run, 0, 120, vehicle: true)], track(0, 120, (s) => lin(s, 0, 120, 1000, 800)), dayId: dayId);
    expect(out.single.kind, SegmentKind.other);
    expect(out.single.isVehicle, isTrue);
    expect(dayStatsFrom(out, PointAggregate(), hasBarometer: true).vehicleFlag, isTrue);
  });

  test('a run after a lift snaps its start to the altitude peak', () {
    final pts = track(0, 400, (s) => s <= 300 ? lin(s, 0, 300, 1000, 1300) : (s <= 310 ? 1300 : lin(s, 310, 400, 1300, 1200)));
    final out = finalizeSegments([iv(SegmentKind.lift, 0, 305), iv(SegmentKind.run, 305, 400)], pts, dayId: dayId);
    expect(out.map((s) => s.kind).toList(), [SegmentKind.lift, SegmentKind.run]);
    expect(out[1].startTs, 300000);
    expect(out[0].endTs, 300000);
    expect(out[1].dropM, closeTo(100, 1e-6));
  });

  test('segment stats: distance, moving time, speeds, gradient', () {
    final out = finalizeSegments([iv(SegmentKind.run, 0, 120)], track(0, 120, (s) => lin(s, 0, 120, 1000, 900)), dayId: dayId);
    final r = out.single;
    expect(r.distanceM, closeTo(1199, 3));
    expect(r.movingMs, 120000);
    expect(r.avgSpeedMs, closeTo(10, 0.1));
    expect(r.maxSpeedMs, 10);
    expect(r.startAltM, 1000);
    expect(r.endAltM, 900);
    expect(r.avgGradientPct, closeTo(8.34, 0.2));
    expect(r.steepest100mPct, isNotNull);
    expect(r.steepest100mPct!, closeTo(8.34, 0.5));
    expect(r.startPointTs, 0);
    expect(r.endPointTs, 120000);
  });

  group('lowerBoundTs', () {
    final list = [for (final t in [0, 1000, 2000, 3000]) TrackPoint(ts: t)];
    for (final (ts, idx) in [(-1, 0), (0, 0), (500, 1), (1000, 1), (2999, 3), (3000, 3), (3001, 4)]) {
      test('ts $ts → index $idx', () => expect(lowerBoundTs(list, ts), idx));
    }
    test('empty list → 0', () => expect(lowerBoundTs(const [], 5), 0));
  });

  test('PointAggregate incremental == batch, and computeDayStats == dayStatsFrom', () {
    final pts = [
      p(0, 1000, hr: 120), p(1, 1010, hr: 140), p(2, 990, accepted: false), TrackPoint(ts: 3000, pressureHpa: 900), p(4, 1005, hr: 100), p(9, 995),
    ];
    final inc = PointAggregate();
    for (final x in pts) {
      inc.add(x);
    }
    final batch = PointAggregate.of(pts);
    expect(inc.accepted, 4);
    expect(inc.rejected, 1);
    expect(inc.maxAltM, 1010);
    expect(inc.minAltM, 995);
    expect(inc.elapsedMs, 9000);
    expect((inc.hrSum, inc.hrN, inc.hrMax), (batch.hrSum, batch.hrN, batch.hrMax));
    expect((inc.accepted, inc.rejected, inc.maxAltM, inc.minAltM, inc.elapsedMs), (batch.accepted, batch.rejected, batch.maxAltM, batch.minAltM, batch.elapsedMs));

    final segs = finalizeSegments([iv(SegmentKind.other, 0, 9)], pts, dayId: dayId);
    final a = computeDayStats(segs, pts, hasBarometer: true);
    final b = dayStatsFrom(segs, inc, hasBarometer: true);
    expect(a.avgHeartRateBpm, 120);
    expect(a.maxHeartRateBpm, 140);
    expect((a.acceptedFixes, a.rejectedFixes, a.maxAltM, a.minAltM, a.elapsedMs, a.otherMs, a.avgHeartRateBpm), (b.acceptedFixes, b.rejectedFixes, b.maxAltM, b.minAltM, b.elapsedMs, b.otherMs, b.avgHeartRateBpm));
  });

  test('empty input → no segments', () {
    expect(finalizeSegments(const [], const [], dayId: dayId), isEmpty);
  });
}
