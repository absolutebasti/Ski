import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/descent.dart';

/// `evaluateDescent` gate by gate: each constant gets a case that shows what it
/// separates, and one that shows the ride still passes without it.
void main() {
  const lat0 = 47.4491, lon0 = 12.3913;
  const mPerDegLat = 111320.0;
  final mPerDegLon = 111320.0 * math.cos(lat0 * math.pi / 180);

  /// A cable ride down: [stationS] s standing, [cruiseS] s at [speed] losing
  /// [drop] m, [stationS] s standing. [turnDegPerS] bends the line,
  /// [speedNoise] wobbles the speed (seeded), [roll] adds a sine to the altitude.
  List<TrackPoint> ride({
    int cruiseS = 400,
    double drop = 500,
    double speed = 7,
    int stationS = 20,
    double turnDegPerS = 0,
    double speedNoise = 0,
    double roll = 0,
    double speedAccMs = 0.5,
    double hAccM = 8,
    int seed = 4,
    int gapFrom = -1,
    int gapTo = -1,
  }) {
    final rnd = math.Random(seed);
    final out = <TrackPoint>[];
    var x = 0.0, y = 0.0, heading = 0.0, sec = 0;
    final alt0 = 1500.0;
    void add(double v, double alt, {bool drop = false}) {
      if (!drop) {
        out.add(TrackPoint(
          ts: sec * 1000, lat: lat0 + y / mPerDegLat, lon: lon0 + x / mPerDegLon,
          hAccM: hAccM, speedMs: v, speedAccMs: speedAccMs, fusedAltM: alt, accepted: true,
        ));
      }
      sec++;
    }

    for (var i = 0; i < stationS; i++) {
      add(0, alt0);
    }
    for (var i = 0; i < cruiseS; i++) {
      final v = speed + (speedNoise == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * speedNoise);
      heading += turnDegPerS * math.pi / 180;
      x += v * math.cos(heading);
      y += v * math.sin(heading);
      final base = alt0 - drop * (i + 1) / cruiseS;
      final alt = roll == 0 ? base : base + roll * math.sin(2 * math.pi * i / 90);
      add(v, alt, drop: i >= gapFrom && i < gapTo);
    }
    for (var i = 0; i < stationS; i++) {
      add(0, alt0 - drop);
    }
    return out;
  }

  DescentEvidence ev(List<TrackPoint> pts) => evaluateDescent(pts, pts.first.ts, pts.last.ts);

  test('the textbook valley ride clears every hurdle', () {
    final e = ev(ride());
    expect(e.ride, isTrue, reason: e.why);
    expect(e.stationBefore && e.stationAfter, isTrue);
    expect(e.startTs, 19000, reason: 'the ride starts at the last second of standing in the station');
    expect(e.endTs, 420000, reason: 'and ends at the first second of standing in the next one');
  });

  group('station to station — the strongest gate, and it cannot be averaged away', () {
    test('no standstill before it: no evidence at all', () {
      final pts = ride(stationS: 20).where((p) => p.speedMs! > 0).toList();
      final e = evaluateDescent(pts, pts.first.ts, pts.last.ts);
      expect(e.stationBefore, isFalse, reason: e.why);
      expect(e.ride, isFalse);
    });

    test('a standstill before but none after: not a ride yet', () {
      final all = ride();
      final pts = [for (final p in all) if (p.ts <= 420000 - 1000 || p.speedMs! > 0) p];
      final e = evaluateDescent(pts, pts.first.ts, pts.last.ts);
      expect(e.stationAfter, isFalse, reason: e.why);
      expect(e.ride, isFalse);
      // …but it is still *possible*, which is what the live top speed uses.
      expect(evaluateDescent(pts, pts.first.ts, pts.last.ts, requireStationAfter: false).possible, isTrue);
    });

    test('a single slow fix is not a station (descentStationHoldS)', () {
      final pts = ride(stationS: 2);
      expect(ev(pts).stationBefore, isFalse, reason: ev(pts).why);
    });
  });

  group('length and depth', () {
    test('one second under descentMinDurationS is not a ride', () {
      // The evidence interval runs station to station, so the cruise plus one
      // second of each ramp has to clear the floor.
      final short = ride(cruiseS: TrackingConfig.descentMinDurationS - 5, drop: 500);
      expect(ev(short).longEnough, isFalse, reason: ev(short).why);
      expect(ev(short).ride, isFalse);
      final long = ride(cruiseS: TrackingConfig.descentMinDurationS + 5, drop: 500);
      expect(ev(long).ride, isTrue, reason: ev(long).why);
    });

    test('too little drop is not a ride (descentMinDropM)', () {
      final e = ev(ride(drop: TrackingConfig.descentMinDropM - 20, cruiseS: 400));
      expect(e.deepEnough, isFalse, reason: e.why);
    });

    test('a shallow gradient is a ski road, not a cable (descentMinGradientPct)', () {
      // 400 s at 7 m/s is 2.8 km; 200 m over that is 7 %.
      final e = ev(ride(drop: 200, cruiseS: 400));
      expect(e.gradientPct, lessThan(TrackingConfig.descentMinGradientPct), reason: e.why);
      expect(e.deepEnough, isFalse);
    });

    test('a slow sink is a ski road too (descentMinVerticalMs)', () {
      // 0.5 m/s of vertical speed on a 14 % gradient: a long traverse.
      final e = ev(ride(drop: 250, cruiseS: 500, speed: 5));
      expect(e.gradientPct, greaterThan(TrackingConfig.descentMinGradientPct), reason: e.why);
      expect(e.dropM / e.durationS, lessThan(TrackingConfig.descentMinVerticalMs));
      expect(e.deepEnough, isFalse);
    });
  });

  group('speed', () {
    test('below descentMinSpeedMs the run always wins', () {
      final e = ev(ride(speed: 3, cruiseS: 400, drop: 500));
      expect(e.fastEnough, isFalse, reason: e.why);
    });

    test('above cableMaxSpeedMs it is a skier, not a cabin', () {
      final e = ev(ride(speed: 13, cruiseS: 400, drop: 900));
      expect(e.fastEnough, isFalse, reason: e.why);
    });

    test('the spread bound comes from the reported speedAccMs, not a constant', () {
      // Same motion, two devices. The bound scales with what the device claims.
      final quiet = ev(ride(speedNoise: 0.9, speedAccMs: 0.4));
      final noisy = ev(ride(speedNoise: 0.9, speedAccMs: 1.4));
      expect(quiet.speedSdBoundMs, lessThan(noisy.speedSdBoundMs));
      expect(quiet.speedSdBoundMs, closeTo(TrackingConfig.descentSpeedSdFactor * 0.4, 1e-9));
      expect(noisy.speedSdBoundMs, closeTo(TrackingConfig.descentSpeedSdFactor * 1.4, 1e-9));
    });

    test('a device that does not report a trustworthy speed accuracy carries no evidence', () {
      final e = ev(ride(speedAccMs: TrackingConfig.speedTrustedMaxAccMs + 0.5));
      expect(e.speedSdBoundMs, 0, reason: e.why);
      expect(e.steadySpeed, isFalse);
      expect(e.ride, isFalse);
    });

    test('a bound floor keeps an implausibly optimistic speedAccMs honest', () {
      final e = ev(ride(speedAccMs: 0.01));
      expect(e.speedSdBoundMs, TrackingConfig.descentSpeedSdFloorMs);
    });

    test('a skier\'s speed swinging through the turns breaks the bound', () {
      final e = ev(ride(speedNoise: 2.5));
      expect(e.steadySpeed, isFalse, reason: e.why);
      expect(e.ride, isFalse);
    });
  });

  group('rigidity at full resolution', () {
    test('a bent line is not a chord (descentMaxChordOffsetFactor)', () {
      final e = ev(ride(turnDegPerS: 0.5));
      expect(e.chordOffsetM, greaterThan(e.chordOffsetBoundM), reason: e.why);
      expect(e.straightChord, isFalse);
      expect(e.ride, isFalse);
    });

    test('the offset bound scales with the reported hAcc, with a floor AND a cap', () {
      expect(ev(ride(hAccM: 12)).chordOffsetBoundM, closeTo(TrackingConfig.descentMaxChordOffsetFactor * 12, 1e-9));
      expect(ev(ride(hAccM: 2)).chordOffsetBoundM, TrackingConfig.descentMaxChordOffsetFloorM);
      // The cap is the point: the offset a real curving path shows does not grow
      // with the *reported* accuracy, so scaling all the way to 2,5 × 30 m = 75 m
      // only ever switched the test off on a noisy phone.
      expect(ev(ride(hAccM: 28)).chordOffsetBoundM, TrackingConfig.descentMaxChordOffsetCapM);
      expect(TrackingConfig.descentMaxChordOffsetCapM,
          lessThan(TrackingConfig.descentMaxChordOffsetFactor * TrackingConfig.maxHorizontalAccuracyM));
    });

    test('a piste that rolls is not a straight line in 3D (descentMaxAltResidualM)', () {
      final e = ev(ride(roll: 12));
      expect(e.altResidualM, greaterThan(TrackingConfig.descentMaxAltResidualM), reason: e.why);
      expect(e.rigidGradient, isFalse);
      expect(e.ride, isFalse);
    });

    test('… and the barometric noise level itself does not (a 3 m ripple passes)', () {
      final e = ev(ride(roll: 3));
      expect(e.ride, isTrue, reason: e.why);
    });

    test('a five-minute GPS dropout inside a steel cabin does not bend the fit', () {
      // The fit runs against the distance *along the chord*, not the walked path:
      // per-fix noise inflates a walked path by a few per cent per step and cannot
      // inflate the one long step across a dropout, which would otherwise make
      // every gondola with a dropout look like a piste that rolls.
      final e = ev(ride(cruiseS: 700, drop: 700, gapFrom: 150, gapTo: 450));
      expect(e.ride, isTrue, reason: e.why);
      expect(e.altResidualM, lessThan(TrackingConfig.descentMaxAltResidualM), reason: e.why);
    });
  });

  group('standstills()', () {
    test('finds every sustained standstill and nothing shorter', () {
      final pts = ride(stationS: 20, cruiseS: 400);
      final st = standstills(pts);
      expect(st.length, 2);
      expect(st.first.$1, 0);
      expect(st.first.$2, 19000);
      expect(st.last.$1, 420000);
      expect(standstills(ride(stationS: 3)), isEmpty);
    });
  });

  test('an inverted or empty interval yields no evidence', () {
    final pts = ride();
    expect(evaluateDescent(pts, pts.last.ts, pts.first.ts).ride, isFalse);
    expect(evaluateDescent(const [], 0, 1000).ride, isFalse);
  });
}
