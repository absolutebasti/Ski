import 'dart:math' as math;

import '../core/core.dart';
import 'altitude.dart';

/// One phase of a synthetic ski day.
class Phase {
  const Phase.stop(this.durationS) : kind = SegmentKind.stop, altDeltaM = 0, avgSpeedMs = 0, dropoutFrom = null, dropoutTo = null;
  const Phase.lift(this.altDeltaM, this.durationS, {this.avgSpeedMs = 5, this.dropoutFrom, this.dropoutTo}) : kind = SegmentKind.lift;
  const Phase.run(double dropM, this.durationS, {this.avgSpeedMs = 14})
      : kind = SegmentKind.run, altDeltaM = -dropM, dropoutFrom = null, dropoutTo = null;
  const Phase.walk(this.durationS, {this.avgSpeedMs = 1.2}) : kind = SegmentKind.other, altDeltaM = 0, dropoutFrom = null, dropoutTo = null;

  final SegmentKind kind;
  final double altDeltaM;
  final int durationS;
  final double avgSpeedMs;
  /// Seconds into the phase without GPS (gondola).
  final int? dropoutFrom;
  final int? dropoutTo;
}

class SyntheticDay {
  const SyntheticDay({required this.fixes, required this.pressures, required this.expectedRuns, required this.expectedLifts, required this.expectedDropM, required this.expectedMaxSpeedMs});
  final List<RawFix> fixes;
  final List<PressureSample> pressures;
  final int expectedRuns;
  final int expectedLifts;
  final double expectedDropM;
  final double expectedMaxSpeedMs;
}

/// Deterministic generator (seeded) for engine property tests.
class SyntheticDayGenerator {
  SyntheticDayGenerator({
    this.seed = 1,
    this.startTs = 1735288800000, // 2024-12-27 09:00 local-ish
    this.baseAltM = 800,
    this.lat0 = 47.4491,
    this.lon0 = 12.3913,
    this.gpsNoiseM = 4,
    this.altNoiseM = 8,
    this.hAccM = 8,
    this.vAccM = 10,
    this.speedAccMs = 0.5,
    this.baroScaleTrue = 0.97,
    this.baroDriftHpaPerH = 0.4,
    this.withBarometer = true,
  });

  final int seed, startTs;
  final double baseAltM, lat0, lon0, gpsNoiseM, altNoiseM, hAccM, vAccM, speedAccMs, baroScaleTrue, baroDriftHpaPerH;
  final bool withBarometer;

  static const List<Phase> defaultDay = [
    Phase.stop(60),
    Phase.lift(1100, 600, dropoutFrom: 150, dropoutTo: 450),
    Phase.stop(60),
    Phase.run(600, 300, avgSpeedMs: 15),
    Phase.stop(30), // short → merges with the next run
    Phase.run(200, 120, avgSpeedMs: 12),
    Phase.walk(40),
    Phase.lift(800, 480, avgSpeedMs: 4),
    Phase.run(600, 250, avgSpeedMs: 16),
    Phase.stop(120),
    Phase.run(500, 240, avgSpeedMs: 14),
    Phase.stop(30),
  ];

  SyntheticDay generate([List<Phase> phases = defaultDay]) {
    final rnd = math.Random(seed);
    final fixes = <RawFix>[];
    final pressures = <PressureSample>[];
    var ts = startTs;
    var alt = baseAltM;
    var x = 0.0, y = 0.0;
    var heading = 0.0;
    var runs = 0, lifts = 0;
    double drop = 0, maxV = 0;
    Phase? prevRun;
    var sinceRunS = 1 << 30;
    for (final ph in phases) {
      heading = rnd.nextDouble() * 2 * math.pi;
      if (ph.kind == SegmentKind.run) {
        // runs separated by < 45 s of stop/other count once
        if (prevRun == null || sinceRunS >= 45) runs++;
        drop += -ph.altDeltaM;
        prevRun = ph;
        sinceRunS = 0;
      } else if (ph.kind == SegmentKind.lift) {
        lifts++;
        sinceRunS += ph.durationS;
      } else {
        sinceRunS += ph.durationS;
      }
      final vAlt = ph.altDeltaM / ph.durationS;
      for (var i = 0; i < ph.durationS; i++) {
        // ramp in/out over 6 s (nobody goes 0 → 60 km/h in one second)
        final ramp = math.min(1.0, math.min(i + 1, ph.durationS - i) / 6.0);
        final v = ph.avgSpeedMs <= 0 ? 0.0 : (ph.avgSpeedMs * (0.85 + 0.3 * rnd.nextDouble()) * ramp);
        x += v * math.cos(heading);
        y += v * math.sin(heading);
        alt += vAlt;
        if (ph.kind == SegmentKind.run && v > maxV) maxV = v;
        ts += 1000;
        final dropout = ph.dropoutFrom != null && i >= ph.dropoutFrom! && i < ph.dropoutTo!;
        if (!dropout) {
          final nx = x + _gauss(rnd) * gpsNoiseM, ny = y + _gauss(rnd) * gpsNoiseM;
          fixes.add(RawFix(
            ts: ts,
            lat: lat0 + ny / 111320,
            lon: lon0 + nx / (111320 * math.cos(lat0 * math.pi / 180)),
            hAccM: hAccM + rnd.nextDouble() * 4,
            gpsAltM: alt + _gauss(rnd) * altNoiseM,
            vAccM: vAccM,
            speedMs: (v + _gauss(rnd) * 0.3).clamp(0, 60),
            speedAccMs: speedAccMs,
            courseDeg: heading * 180 / math.pi,
          ));
        }
        if (withBarometer) {
          final hBaro = (alt - baseAltM) * baroScaleTrue + baseAltM;
          final drift = baroDriftHpaPerH * (ts - startTs) / 3600000;
          final p = TrackingConfig.seaLevelHpa * math.pow(1 - hBaro / TrackingConfig.hypsometricScaleM, 1 / TrackingConfig.hypsometricExponent) + drift + _gauss(rnd) * 0.02;
          pressures.add(PressureSample(ts: ts, hPa: p.toDouble()));
        }
      }
    }
    return SyntheticDay(fixes: fixes, pressures: pressures, expectedRuns: runs, expectedLifts: lifts, expectedDropM: drop, expectedMaxSpeedMs: maxV);
  }

  static double _gauss(math.Random r) {
    final u1 = 1 - r.nextDouble(), u2 = r.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

/// Convenience for tests: altitude back from pressure (no anchor).
double baroAltitude(double hPa) => hypsometricAltitude(hPa);
