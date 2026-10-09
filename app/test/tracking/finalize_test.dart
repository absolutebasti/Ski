import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/finalize.dart';
import 'package:slopetrack/tracking/segmenter.dart';

import 'cable_support.dart';

/// finalizeSegments validity/merge/snap rules and the day-stats aggregate.
String describeSegs(List<Segment> segs) =>
    segs.map((s) => '${s.kind.name}:${s.startTs ~/ 1000}-${s.endTs ~/ 1000}s/${(s.endAltM - s.startAltM).round()}m').join(', ');

void main() {
  const dayId = 'd';
  TrackPoint p(int s, double alt, {double speed = 10, bool accepted = true, int? hr}) => TrackPoint(
        ts: s * 1000, lat: 47 + s * speed / 111320, lon: 12, hAccM: 5, speedMs: speed, speedAccMs: 0.5, fusedAltM: alt, accepted: accepted, heartRateBpm: hr,
      );
  /// Points for seconds [from, to] with a piecewise altitude function.
  List<TrackPoint> track(int from, int to, double Function(int s) alt) => [for (var s = from; s <= to; s++) p(s, alt(s))];
  /// Like [track] but with a skier's swinging speed — an *additional* fixture,
  /// never a replacement: a dead-straight, dead-constant 25 % descent has to
  /// stay a RUN on [track] input alone, and that is what the groups below assert.
  List<TrackPoint> skierTrack(int from, int to, double Function(int s) alt) =>
      [for (var s = from; s <= to; s++) p(s, alt(s), speed: 10 + 4 * math.sin(s / 7))];
  /// A cable ride *down*: [stationS] s standing in the upper station, [cruiseS] s
  /// at [speed] on a dead-straight line losing [drop] m, then [stationS] s
  /// standing in the lower station. This — station to station, long enough, deep
  /// enough, rigid at full resolution — is what it takes to rewrite a descent.
  List<TrackPoint> rideDown(int cruiseS, double drop, {double speed = 7, int stationS = 20}) {
    final out = <TrackPoint>[];
    var x = 0.0, alt = 1000.0, sec = 0;
    void add(double v) {
      out.add(TrackPoint(
        ts: sec * 1000, lat: 47, lon: 12 + x / (111320 * 0.681998), hAccM: 5,
        speedMs: v, speedAccMs: 0.5, fusedAltM: alt, accepted: true,
      ));
      sec++;
    }
    for (var i = 0; i < stationS; i++) {
      add(0);
    }
    for (var i = 0; i < cruiseS; i++) {
      x += speed;
      alt -= drop / cruiseS;
      add(speed);
    }
    for (var i = 0; i < stationS; i++) {
      add(0);
    }
    return out;
  }
  double lin(int s, int s0, int s1, double a0, double a1) => a0 + (a1 - a0) * (s - s0) / (s1 - s0);
  RawInterval iv(SegmentKind k, int fromS, int toS, {bool vehicle = false, bool cable = false}) =>
      RawInterval(kind: k, startTs: fromS * 1000, endTs: toS * 1000, vehicle: vehicle, cable: cable);

  group('run validity (runMinDurationS = ${TrackingConfig.runMinDurationS}, runMinDropM = ${TrackingConfig.runMinDropM})', () {
    for (final (dur, drop, expected) in [(60, 40.0, SegmentKind.run), (59, 100.0, SegmentKind.other), (60, 39.9, SegmentKind.other), (120, 300.0, SegmentKind.run)]) {
      test('$dur s, $drop m → $expected', () {
        final out = finalizeSegments([iv(SegmentKind.run, 0, dur)], track(0, dur, (s) => lin(s, 0, dur, 1000, 1000 - drop)), dayId: dayId);
        expect(out.single.kind, expected, reason: 'plain track(): dead straight at a dead-constant speed');
        // …and the same thing skied the way people ski.
        final skied = finalizeSegments([iv(SegmentKind.run, 0, dur)], skierTrack(0, dur, (s) => lin(s, 0, dur, 1000, 1000 - drop)), dayId: dayId);
        expect(skied.single.kind, expected);
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

  group('descending rides: what it takes to take a descent away from the skier', () {
    test('a dead-straight, dead-constant 25 % descent over 120 s stays a RUN', () {
      // Acceptance: plain track() input, the cable signature in its purest form.
      // 120 s is under descentMinDurationS, and there is no station at either
      // end — either one alone keeps it a run.
      final out = finalizeSegments([iv(SegmentKind.run, 0, 120)], track(0, 120, (s) => lin(s, 0, 120, 1000, 700)), dayId: dayId);
      expect(out.single.kind, SegmentKind.run);
      expect(out.single.maxSpeedMs, 10);
    });

    test('… and over 400 s too, as long as it is not station to station', () {
      final out = finalizeSegments([iv(SegmentKind.run, 0, 400)], track(0, 400, (s) => lin(s, 0, 400, 1600, 1000)), dayId: dayId);
      expect(out.single.kind, SegmentKind.run, reason: 'no standstill at either end: nobody boarded anything');
      expect(out.single.maxSpeedMs, 10);
    });

    test('… and station to station stays a RUN below descentMinDurationS', () {
      final pts = rideDown(TrackingConfig.descentMinDurationS - 40, 300);
      final out = finalizeSegments([iv(SegmentKind.run, 0, pts.last.ts ~/ 1000)], pts, dayId: dayId);
      expect(out.where((x) => x.kind == SegmentKind.lift), isEmpty, reason: describeSegs(out));
      expect(out.where((x) => x.kind == SegmentKind.run).length, 1, reason: describeSegs(out));
    });

    test('a cable-confirmed ride down is a LIFT, adds no ascent, and keeps its kilometres', () {
      // `cable: true` is what the descending pass sets when it carves a ride, so
      // this exercises the validity rule's absolute-gain branch and the stats
      // directly — independent of whether the pass itself runs
      // ([TrackingConfig.descentRidesEnabled]).
      final pts = rideDown(330, 420);
      final out = finalizeSegments([iv(SegmentKind.lift, 0, pts.last.ts ~/ 1000, cable: true)], pts, dayId: dayId);
      final lift = out.singleWhere((x) => x.kind == SegmentKind.lift);
      expect(lift.endAltM - lift.startAltM, closeTo(-420, 3), reason: 'liftMinGainM counts an absolute change for a cable ride');
      expect(lift.dropM, 0, reason: 'a ride down is not ascent');
      expect(lift.distanceM, greaterThan(1000), reason: 'but its kilometres are lift kilometres');
      expect(lift.maxSpeedMs, 0);
      expect(out.where((x) => x.kind == SegmentKind.run), isEmpty);
    });

    test('a RUN that is a full ride down: rewritten, or not, per the switch', () {
      final pts = rideDown(330, 420);
      final out = finalizeSegments([iv(SegmentKind.run, 0, pts.last.ts ~/ 1000)], pts, dayId: dayId);
      final st = dayStatsFrom(out, PointAggregate(), hasBarometer: true);
      if (!descentRides) {
        // SHIPPED: nothing is taken away from the skier. This is the *textbook*
        // ride — station to station, 330 s, 420 m, dead straight, dead constant —
        // and it still stays a run, because a ski road is the same picture and
        // 427 of them were being deleted (ski_road_sweep_test.dart).
        expect(out.where((x) => x.kind == SegmentKind.run).length, 1, reason: describeSegs(out));
        expect(st.skiDistanceM, greaterThan(2000), reason: describeSegs(out));
        return;
      }
      expect(out.where((x) => x.kind == SegmentKind.run), isEmpty, reason: describeSegs(out));
      expect(st.skiDistanceM, 0);
      expect(st.maxSpeedMs, 0);
    });

    test('the ride start is pulled back to the station the cabin left', () {
      final pts = rideDown(330, 420);
      final total = pts.last.ts ~/ 1000;
      final out = finalizeSegments(
          [iv(SegmentKind.other, 0, 60), iv(SegmentKind.lift, 60, total, cable: true)], pts, dayId: dayId);
      final lift = out.singleWhere((x) => x.kind == SegmentKind.lift);
      if (!descentRides) {
        // The start snap of rule 1c replays the *ascending* signature, which a
        // ride down never carries; what pulled a valley ride back to its station
        // was the descending pass itself, and that is off. So the interval keeps
        // the boundary it was handed.
        expect(lift.startTs, 60000, reason: describeSegs(out));
        return;
      }
      expect(lift.startTs, 19000, reason: 'the last second of standing in the station: ${describeSegs(out)}');
      expect(out.first.endTs, 19000, reason: 'and the neighbour in front gives those seconds up');
    });

    group('rule 3b, the 60 s turning-point snap, leaves a descending ride alone', () {
      // A descending cable ride has no turning point at *either* end: the skier
      // was already going down when they boarded and is going down when they get
      // out. Snapping the boundary to the highest fix of the previous 60 s moves a
      // minute of the carved ride back into the neighbouring RUN — and hands that
      // run the cabin's speed. Measured on SkiProfiles.gondolaDownMidStation
      // before the mirror guard: 60 s moved back, live top speed 28,8 km/h for
      // five minutes against a finished day of 0 runs and 0,0 km/h.
      test('…when the ride comes AFTER the run (cur is the ride)', () {
        // Run down, then board the cabin: [run 0-120] [cable lift 120-460].
        final pts = <TrackPoint>[
          for (var t = 0; t <= 120; t++) p(t, lin(t, 0, 120, 2000, 1800)),
          for (final q in rideDown(330, 420)) TrackPoint(
            ts: q.ts + 121000, lat: q.lat, lon: q.lon, hAccM: q.hAccM, speedMs: q.speedMs,
            speedAccMs: q.speedAccMs, fusedAltM: q.fusedAltM! - 200, accepted: true,
          ),
        ];
        final total = pts.last.ts ~/ 1000;
        final out = finalizeSegments(
            [iv(SegmentKind.run, 0, 120), iv(SegmentKind.lift, 121, total, cable: true)], pts, dayId: dayId);
        final lift = out.firstWhere((x) => x.kind == SegmentKind.lift);
        expect(lift.startTs, 121000, reason: 'the boundary was not snapped: ${describeSegs(out)}');
        final run = out.firstWhere((x) => x.kind == SegmentKind.run);
        expect(run.endTs, 121000, reason: 'and the run keeps exactly its own 120 s: ${describeSegs(out)}');
      });

      test('…and when the ride comes BEFORE the run (prev is the ride) — the mirror', () {
        // The cabin arrives in the valley, the skier pushes off and skis on:
        // [cable lift 0-420] [run 420-560]. Rule 3b must not pull the run's start
        // back into the ride.
        final ride = rideDown(330, 420);
        final rideEndS = ride.last.ts ~/ 1000;
        final pts = <TrackPoint>[
          ...ride,
          for (var t = 1; t <= 140; t++) p(rideEndS + t, lin(t, 0, 140, 580, 480)),
        ];
        final out = finalizeSegments(
            [iv(SegmentKind.lift, 0, rideEndS, cable: true), iv(SegmentKind.run, rideEndS, rideEndS + 140)],
            pts,
            dayId: dayId);
        final run = out.firstWhere((x) => x.kind == SegmentKind.run);
        expect(run.startTs, rideEndS * 1000,
            reason: 'the run may not start inside the ride: ${describeSegs(out)}');
        final lift = out.firstWhere((x) => x.kind == SegmentKind.lift);
        expect(lift.endTs, rideEndS * 1000, reason: describeSegs(out));
        expect(run.maxSpeedMs, closeTo(10, 1e-9), reason: 'and it carries only its own speed');
      });
    });

    test('a descending LIFT that is not a confirmed ride still needs a real GAIN', () {
      for (final pts in [track(0, 200, (s) => lin(s, 0, 200, 1500, 1000)), skierTrack(0, 200, (s) => lin(s, 0, 200, 1500, 1000))]) {
        final out = finalizeSegments([iv(SegmentKind.lift, 0, 200)], pts, dayId: dayId);
        expect(out.single.kind, SegmentKind.other, reason: 'losing 500 m is no lift unless the ride is confirmed');
      }
    });
  });
}
