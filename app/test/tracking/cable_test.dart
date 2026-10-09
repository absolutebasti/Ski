import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/tracking/cable.dart';

/// CableDetector: which 45 s windows hold, which ride, and which do neither.
void main() {
  const lat0 = 47.4491, lon0 = 12.3913;
  const mPerDegLat = 111320.0;
  final mPerDegLon = 111320.0 * math.cos(lat0 * math.pi / 180);

  /// Feeds [n] seconds of motion into [d]: speed `vMs` (± [noise], seeded),
  /// vertical speed `vzMs`, heading turning by [turnDegPerS] each second.
  /// Returns the timestamp of the last fix.
  int feed(
    CableDetector d, {
    int n = 50,
    double vMs = 6,
    double vzMs = 1.5,
    double noise = 0,
    double turnDegPerS = 0,
    double posNoiseM = 0,
    int startTs = 1000,
    double startAltM = 1000,
    int seed = 4,
  }) {
    final rnd = math.Random(seed);
    var x = 0.0, y = 0.0, alt = startAltM, heading = 0.0, ts = startTs;
    for (var i = 0; i < n; i++) {
      final v = vMs + (noise == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * noise);
      heading += turnDegPerS * math.pi / 180;
      x += v * math.cos(heading);
      y += v * math.sin(heading);
      alt += vzMs;
      final nx = x + (posNoiseM == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * posNoiseM);
      final ny = y + (posNoiseM == 0 ? 0 : (rnd.nextDouble() * 2 - 1) * posNoiseM);
      d.add(ts: ts, lat: lat0 + ny / mPerDegLat, lon: lon0 + nx / mPerDegLon, altM: alt, speedMs: v, speedAccMs: 0.5);
      ts += 1000;
    }
    return ts - 1000;
  }

  group('a window that RIDES (strict signature)', () {
    test('6 m/s, straight, +1.5 m/s → holds and rides', () {
      final d = CableDetector();
      final ts = feed(d);
      expect(d.holds, isTrue, reason: 'cv ${d.speedCv}, straightness ${d.straightness}, mono ${d.monotonicity}');
      expect(d.rides, isTrue);
      expect(d.holdsAt(ts), isTrue);
      expect(d.ridesAt(ts), isTrue);
      expect(d.meanVMs, closeTo(6, 0.01));
      expect(d.altChangeM, greaterThan(TrackingConfig.cableMinAltChangeM));
      expect(d.gradientPct, closeTo(25, 1));
    });

    test('a gondola riding DOWN holds but never RIDES — the window cannot tell', () {
      // The asymmetry. Over 45 s a cabin into the valley and a steady schuss are
      // the same picture, so the window may only hold a running lift together;
      // rewriting a descent needs the interval-level evidence in descent.dart.
      final d = CableDetector();
      feed(d, vMs: 7, vzMs: -1.7);
      expect(d.holds, isTrue, reason: 'it still holds a running lift together');
      expect(d.descending, isTrue);
      expect(d.vetoesRun, isFalse, reason: 'and it must never stop a run from starting');
      expect(d.rides, isFalse, reason: 'going down is not decided from 45 s of window');
      expect(d.altChangeM, lessThan(-TrackingConfig.cableMinAltChangeM));
      expect(d.gradientPct, greaterThan(TrackingConfig.cableMinGradientPct));
    });

    test('an ascending window vetoes a RUN entry', () {
      final d = CableDetector();
      feed(d, vMs: 6, vzMs: 1.5);
      expect(d.vetoesRun, isTrue);
      expect(d.descending, isFalse);
    });

    test('a 2.5 m/s chair survives ±0.7 m/s Doppler noise (absolute noise floor)', () {
      final d = CableDetector();
      feed(d, vMs: 2.5, vzMs: 0.9, noise: 0.7, posNoiseM: 2);
      expect(d.speedCv, greaterThan(TrackingConfig.cableMaxSpeedCv), reason: 'the relative test alone would reject it');
      expect(d.rides, isTrue, reason: 'cv ${d.speedCv}, straightness ${d.straightness}');
    });

    test('… but not ±1.5 m/s of it (that is a person, not a rope)', () {
      final d = CableDetector();
      feed(d, vMs: 2.5, vzMs: 0.9, noise: 1.5);
      expect(d.holds, isFalse);
      expect(d.rides, isFalse);
    });
  });

  group('a window that HOLDS but does not RIDE', () {
    test('a cable car\'s flat mid-span: constant, straight, no altitude change', () {
      final d = CableDetector();
      feed(d, vzMs: 0);
      expect(d.holds, isTrue);
      expect(d.rides, isFalse, reason: 'a flat span opens no lift');
    });

    test('a straight constant glide on a gradient below cableMinGradientPct', () {
      final d = CableDetector();
      feed(d, vMs: 8, vzMs: -0.4); // 5 % — a cat track, not a cable
      expect(d.gradientPct, lessThan(TrackingConfig.cableMinGradientPct));
      expect(d.holds, isTrue);
      expect(d.rides, isFalse);
    });

    test('monotone but less than cableMinAltChangeM over the window', () {
      final d = CableDetector();
      feed(d, vMs: 3, vzMs: 0.1);
      expect(d.altChangeM, lessThan(TrackingConfig.cableMinAltChangeM));
      expect(d.holds, isTrue);
      expect(d.rides, isFalse);
    });
  });

  group('a window that does NEITHER', () {
    test('a skier: speed swinging by ± 4 m/s', () {
      final d = CableDetector();
      feed(d, vMs: 11, vzMs: -1.6, noise: 4);
      expect(d.holds, isFalse, reason: 'cv ${d.speedCv}');
    });

    test('a skier: turning 6° per second', () {
      final d = CableDetector();
      feed(d, vMs: 10, vzMs: -1.5, turnDegPerS: 6);
      expect(d.straightness, lessThan(TrackingConfig.cableMinStraightness));
      expect(d.holds, isFalse);
    });

    test('a lift queue below cableMinSpeedMs', () {
      final d = CableDetector();
      feed(d, vMs: 1.0, vzMs: 0.2);
      expect(d.holds, isFalse);
    });

    test('faster than any cable (cableMaxSpeedMs)', () {
      final d = CableDetector();
      feed(d, vMs: 14, vzMs: -2);
      expect(d.holds, isFalse);
    });

    test('a window shorter than cableMinSpanS proves nothing', () {
      final d = CableDetector();
      feed(d, n: TrackingConfig.cableMinSpanS - 1);
      expect(d.windowSamples, TrackingConfig.cableMinSpanS - 1);
      expect(d.holds, isFalse);
      expect(d.rides, isFalse);
    });

    test('one second more and the same motion rides', () {
      final d = CableDetector();
      feed(d, n: TrackingConfig.cableMinSpanS + 1);
      expect(d.rides, isTrue);
    });

    test('an altitude that goes up and back down again is not one way', () {
      final d = CableDetector();
      var ts = feed(d, n: 25, vzMs: 2.0);
      ts = feed(d, n: 25, vzMs: -2.0, startTs: ts + 1000, startAltM: 1000 + 25 * 2.0);
      expect(d.monotonicity, lessThan(TrackingConfig.cableMinAltMonotonicity));
      expect(d.rides, isFalse);
    });
  });

  group('freshness and window hygiene', () {
    test('the verdict goes stale cableStaleS after the last fix', () {
      final d = CableDetector();
      final ts = feed(d);
      expect(d.holdsAt(ts + TrackingConfig.cableStaleS * 1000), isTrue);
      expect(d.holdsAt(ts + TrackingConfig.cableStaleS * 1000 + 1), isFalse);
      expect(d.ridesAt(ts + TrackingConfig.cableStaleS * 1000 + 1), isFalse);
      expect(d.rides, isTrue, reason: 'the window itself still rides, only the clock is stale');
    });

    test('a gap longer than windowResetGapS starts a new window', () {
      final d = CableDetector();
      final ts = feed(d);
      expect(d.rides, isTrue);
      feed(d, n: 3, startTs: ts + (TrackingConfig.windowResetGapS.toInt() + 2) * 1000);
      expect(d.windowSamples, 3);
      expect(d.rides, isFalse);
    });

    test('reset() empties the window and clears the metrics', () {
      final d = CableDetector();
      feed(d);
      d.reset();
      expect(d.windowSamples, 0);
      expect(d.holds, isFalse);
      expect(d.rides, isFalse);
      expect(d.meanVMs, 0);
      expect(d.windowStartTs, isNull);
    });

    test('non-monotonic input never enters the window', () {
      final d = CableDetector();
      final ts = feed(d);
      final n = d.windowSamples;
      d.add(ts: ts - 5000, lat: lat0, lon: lon0, altM: 1000, speedMs: 6, speedAccMs: 0.5);
      expect(d.windowSamples, n);
    });

    test('rejected points and points without a fused altitude are ignored', () {
      final d = CableDetector();
      d.addPoint(const TrackPoint(ts: 1000, lat: lat0, lon: lon0, fusedAltM: 1000, accepted: false));
      d.addPoint(const TrackPoint(ts: 2000, lat: lat0, lon: lon0, accepted: true));
      d.addPoint(const TrackPoint(ts: 3000, accepted: true, fusedAltM: 1000));
      expect(d.windowSamples, 0);
    });
  });

  group('cableCoverage', () {
    /// Points along a cable ride from [fromS] to [toS] (seconds), then a skier.
    List<TrackPoint> ride({required int n, required double vMs, required double vzMs, double turnDegPerS = 0, int startTs = 1000, double startAltM = 1000}) {
      final out = <TrackPoint>[];
      var x = 0.0, y = 0.0, alt = startAltM, heading = 0.0, ts = startTs;
      for (var i = 0; i < n; i++) {
        heading += turnDegPerS * math.pi / 180;
        x += vMs * math.cos(heading);
        y += vMs * math.sin(heading);
        alt += vzMs;
        out.add(TrackPoint(
          ts: ts, lat: lat0 + y / mPerDegLat, lon: lon0 + x / mPerDegLon,
          hAccM: 5, speedMs: vMs, speedAccMs: 0.5, fusedAltM: alt, accepted: true,
        ));
        ts += 1000;
      }
      return out;
    }

    test('a whole interval of cable scores ~1, a skier scores 0', () {
      // Ascending: the strict signature is an ascending-only verdict now.
      final cable = ride(n: 200, vMs: 7, vzMs: 1.7);
      final cov = cableCoverage(cable, cable.first.ts, cable.last.ts);
      expect(cov, greaterThan(0.95));
      expect(cov, lessThanOrEqualTo(1.0));
      final skier = ride(n: 200, vMs: 12, vzMs: -1.7, turnDegPerS: 6);
      expect(cableCoverage(skier, skier.first.ts, skier.last.ts), 0);
      final descending = ride(n: 200, vMs: 7, vzMs: -1.7);
      expect(cableCoverage(descending, descending.first.ts, descending.last.ts), 0,
          reason: 'a descent never scores coverage — descent.dart decides that');
    });

    test('half cable, half skiing lands between the two and below the veto', () {
      final pts = ride(n: 120, vMs: 12, vzMs: 1.7, turnDegPerS: 6);
      pts.addAll(ride(n: 120, vMs: 7, vzMs: 1.7, startTs: pts.last.ts + 1000, startAltM: pts.last.fusedAltM!));
      final cov = cableCoverage(pts, pts.first.ts, pts.last.ts);
      expect(cov, greaterThan(0.3));
      expect(cov, lessThan(TrackingConfig.cableRunVetoCoverage));
    });

    test('the `from` index only skips work: same answer as scanning from 0', () {
      final pts = ride(n: 60, vMs: 12, vzMs: 1.7, turnDegPerS: 6);
      pts.addAll(ride(n: 200, vMs: 7, vzMs: 1.7, startTs: pts.last.ts + 1000, startAltM: pts.last.fusedAltM!));
      final start = pts[60].ts, end = pts.last.ts;
      expect(cableCoverage(pts, start, end, from: 60), cableCoverage(pts, start, end));
    });

    test('an empty or inverted interval scores 0', () {
      final pts = ride(n: 60, vMs: 7, vzMs: 1.7);
      expect(cableCoverage(pts, pts.last.ts, pts.first.ts), 0);
      expect(cableCoverage(const [], 0, 1000), 0);
    });

    test('cableRideStart finds the station the ride left from', () {
      // 30 s standing in the station, a 6 s acceleration, then 200 s of cable.
      final pts = <TrackPoint>[];
      var ts = 1000;
      for (var i = 0; i < 30; i++) {
        pts.add(TrackPoint(ts: ts, lat: lat0, lon: lon0, hAccM: 5, speedMs: 0, speedAccMs: 0.5, fusedAltM: 1000, accepted: true));
        ts += 1000;
      }
      var x = 0.0, alt = 1000.0;
      for (var i = 0; i < 206; i++) {
        final v = 7.0 * math.min(1.0, (i + 1) / 6.0);
        x += v;
        alt += v * 1.7 / 7;
        pts.add(TrackPoint(
          ts: ts, lat: lat0, lon: lon0 + x / mPerDegLon, hAccM: 5, speedMs: v, speedAccMs: 0.5, fusedAltM: alt, accepted: true,
        ));
        ts += 1000;
      }
      final stationTs = pts[29].ts; // the last fix that was still standing
      final rideTs = pts[30].ts;
      // The segmenter only opens the lift ~1 min in; the snap has to find the station.
      final detectedAt = rideTs + (TrackingConfig.cableWindowS + TrackingConfig.cableEnterS) * 1000;
      expect(cableRideStart(pts, detectedAt, notBefore: pts.first.ts, until: pts.last.ts), stationTs);
    });

    test('cableRideStart returns atTs when there is no ride to find', () {
      final skier = ride(n: 200, vMs: 12, vzMs: -1.7, turnDegPerS: 6);
      final at = skier[150].ts;
      expect(cableRideStart(skier, at, notBefore: skier.first.ts, until: skier.last.ts), at);
    });

    test('cableRideStart never reaches before notBefore', () {
      final pts = ride(n: 200, vMs: 7, vzMs: 1.7);
      final at = pts[120].ts;
      expect(cableRideStart(pts, at, notBefore: pts[110].ts, until: pts.last.ts), pts[110].ts);
    });
  });
}
