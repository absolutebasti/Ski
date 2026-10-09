import 'dart:math' as math;

import '../core/core.dart';
import 'altitude.dart';

/// One phase of a synthetic ski day.
class Phase {
  const Phase.stop(this.durationS)
      : kind = SegmentKind.stop, altDeltaM = 0, avgSpeedMs = 0, dropoutFrom = null, dropoutTo = null, jitter = 0.15, ramp = true,
        speedWaveAmp = 0, speedWaveS = 30, turnRateDeg = 0, cable = false, hairpinEveryS = 0, hairpinTurnS = 12;
  const Phase.lift(this.altDeltaM, this.durationS, {this.avgSpeedMs = 5, this.dropoutFrom, this.dropoutTo, this.jitter = 0.15, this.ramp = true})
      : kind = SegmentKind.lift, speedWaveAmp = 0, speedWaveS = 30, turnRateDeg = 0, cable = false, hairpinEveryS = 0, hairpinTurnS = 12;
  const Phase.run(double dropM, this.durationS,
      {this.avgSpeedMs = 14, this.jitter = 0.15, this.ramp = true, this.speedWaveAmp = 0, this.speedWaveS = 30, this.turnRateDeg = 0})
      : kind = SegmentKind.run, altDeltaM = -dropM, dropoutFrom = null, dropoutTo = null, cable = false, hairpinEveryS = 0, hairpinTurnS = 12;
  const Phase.walk(this.durationS, {this.avgSpeedMs = 1.2, this.jitter = 0.15})
      : kind = SegmentKind.other, altDeltaM = 0, dropoutFrom = null, dropoutTo = null, ramp = true, speedWaveAmp = 0, speedWaveS = 30, turnRateDeg = 0, cable = false, hairpinEveryS = 0, hairpinTurnS = 12;
  /// Anything that is neither a lift nor a run: skating on a rising traverse,
  /// a cat track too flat to count as a run, a magic carpet below the lift floors.
  ///
  /// [turnRateDeg] is what separates a person from a rope on the way *up*: a
  /// skater poling up a connector wanders, a T-bar is a straight line. The
  /// uphill sweep in `lift_uphill_sweep_test.dart` drives it.
  const Phase.other(this.altDeltaM, this.durationS,
      {this.avgSpeedMs = 2, this.jitter = 0.15, this.ramp = true, this.turnRateDeg = 0})
      : kind = SegmentKind.other, dropoutFrom = null, dropoutTo = null, speedWaveAmp = 0, speedWaveS = 30, cable = false, hairpinEveryS = 0, hairpinTurnS = 12;

  /// A cable ride: constant speed, straight line, altitude one way only.
  /// [altDeltaM] may be negative — a gondola riding down into the valley.
  /// Consecutive cable phases are ONE physical cable: the generator keeps the
  /// heading and skips the speed ramp at the joint, so a cable car's flat
  /// mid-span is a mid-span and not two rides with a stop between them.
  const Phase.cable(this.altDeltaM, this.durationS, {this.avgSpeedMs = 6, this.jitter = 0.03, this.dropoutFrom, this.dropoutTo})
      : kind = SegmentKind.lift, ramp = true, speedWaveAmp = 0, speedWaveS = 30, turnRateDeg = 0, cable = true, hairpinEveryS = 0, hairpinTurnS = 12;

  /// A vehicle on a mountain road: cruising speed on a graded descent with
  /// switchbacks — a hairpin every [hairpinEveryS] seconds, each taken over
  /// [hairpinTurnS] seconds and reversing the direction. Neither a run nor a
  /// lift; the ski bus of the reviewer case list.
  const Phase.road(this.altDeltaM, this.durationS,
      {this.avgSpeedMs = 10, this.jitter = 0.08, this.hairpinEveryS = 90, this.hairpinTurnS = 12})
      : kind = SegmentKind.other, dropoutFrom = null, dropoutTo = null, ramp = true,
        speedWaveAmp = 0, speedWaveS = 30, turnRateDeg = 0, cable = false;

  /// A run the way people really ski: speed swinging between roughly 8 and
  /// 19 m/s and a heading that keeps changing.
  static Phase realRun(double dropM, int durationS, {double avgSpeedMs = 13.5}) =>
      Phase.run(dropM, durationS, avgSpeedMs: avgSpeedMs, jitter: 0.06, speedWaveAmp: 0.35, speedWaveS: 40, turnRateDeg: 6);

  final SegmentKind kind;
  final double altDeltaM;
  final int durationS;
  final double avgSpeedMs;
  /// Seconds into the phase without GPS (gondola).
  final int? dropoutFrom;
  final int? dropoutTo;
  /// Per-second speed spread: v = avg · (1 ± jitter), uniform. 0.15 is a skier
  /// (and the historic default); a cable runs at 0.02–0.05.
  final double jitter;
  /// Ramp speed in/out over 6 s at the phase edges.
  final bool ramp;
  /// Amplitude of a smooth speed wave as a fraction of [avgSpeedMs] — a skier
  /// speeding up and braking through the turns.
  final double speedWaveAmp;
  /// Period of that wave in seconds.
  final double speedWaveS;
  /// Standard deviation of the per-second heading change in degrees (turns).
  final double turnRateDeg;
  /// True for [Phase.cable]: a rope, not a person. Consecutive cable phases are
  /// joined into one continuous ride.
  final bool cable;
  /// Seconds between hairpin bends (0 = none), and how long one bend takes.
  final int hairpinEveryS;
  final int hairpinTurnS;
}

class SyntheticDay {
  const SyntheticDay({
    required this.fixes, required this.pressures, required this.expectedRuns, required this.expectedLifts, required this.expectedDropM, required this.expectedMaxSpeedMs,
    this.expectedSkiDistanceM = 0, this.expectedRunS = 0, this.expectedLiftDistanceM = 0, this.expectedLiftMaxSpeedMs = 0,
  });
  final List<RawFix> fixes;
  final List<PressureSample> pressures;
  final int expectedRuns;
  final int expectedLifts;
  final double expectedDropM;
  /// Highest true (noise-free) speed inside a run phase.
  final double expectedMaxSpeedMs;
  /// True horizontal path length of the run phases.
  final double expectedSkiDistanceM;
  /// Seconds spent in run phases.
  final int expectedRunS;
  /// True horizontal path length of the lift phases.
  final double expectedLiftDistanceM;
  /// Highest true speed inside a lift phase.
  final double expectedLiftMaxSpeedMs;

  /// Truth for the Ø ski speed (skied distance / run time).
  double get expectedAvgSkiSpeedMs => expectedRunS > 0 ? expectedSkiDistanceM / expectedRunS : 0;
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
    double drop = 0, maxV = 0, skiD = 0, liftD = 0, liftMaxV = 0;
    var runS = 0;
    Phase? prevRun;
    var sinceRunS = 1 << 30;
    for (var pi = 0; pi < phases.length; pi++) {
      final ph = phases[pi];
      // One physical cable spanning several phases keeps its heading and does
      // not decelerate at the joint.
      final joinPrev = ph.cable && pi > 0 && phases[pi - 1].cable;
      final joinNext = ph.cable && pi + 1 < phases.length && phases[pi + 1].cable;
      if (!joinPrev) heading = rnd.nextDouble() * 2 * math.pi;
      if (ph.kind == SegmentKind.run) {
        // runs separated by < 45 s of stop/other count once
        if (prevRun == null || sinceRunS >= 45) runs++;
        drop += -ph.altDeltaM;
        prevRun = ph;
        sinceRunS = 0;
      } else if (ph.kind == SegmentKind.lift) {
        if (!joinPrev) lifts++;
        sinceRunS += ph.durationS;
      } else {
        sinceRunS += ph.durationS;
      }
      final vAlt = ph.altDeltaM / ph.durationS;
      for (var i = 0; i < ph.durationS; i++) {
        // ramp in/out over 6 s (nobody goes 0 → 60 km/h in one second)
        final rIn = joinPrev || !ph.ramp ? 1.0 : math.min(1.0, (i + 1) / 6.0);
        final rOut = joinNext || !ph.ramp ? 1.0 : math.min(1.0, (ph.durationS - i) / 6.0);
        final ramp = math.min(rIn, rOut);
        final wave = ph.speedWaveAmp == 0 ? 1.0 : 1 + ph.speedWaveAmp * math.sin(2 * math.pi * i / ph.speedWaveS);
        final v = ph.avgSpeedMs <= 0
            ? 0.0
            : (ph.avgSpeedMs * wave * (1 - ph.jitter + 2 * ph.jitter * rnd.nextDouble()) * ramp);
        if (ph.turnRateDeg > 0) heading += _gauss(rnd) * ph.turnRateDeg * math.pi / 180;
        if (ph.hairpinEveryS > 0 && i % ph.hairpinEveryS < ph.hairpinTurnS) {
          final dir = (i ~/ ph.hairpinEveryS).isEven ? 1 : -1;
          heading += dir * (170.0 / ph.hairpinTurnS) * math.pi / 180;
        }
        x += v * math.cos(heading);
        y += v * math.sin(heading);
        alt += vAlt;
        if (ph.kind == SegmentKind.run) {
          if (v > maxV) maxV = v;
          skiD += v;
          runS++;
        } else if (ph.kind == SegmentKind.lift) {
          if (v > liftMaxV) liftMaxV = v;
          liftD += v;
        }
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
    return SyntheticDay(
      fixes: fixes, pressures: pressures, expectedRuns: runs, expectedLifts: lifts, expectedDropM: drop, expectedMaxSpeedMs: maxV,
      expectedSkiDistanceM: skiD, expectedRunS: runS, expectedLiftDistanceM: liftD, expectedLiftMaxSpeedMs: liftMaxV,
    );
  }

  static double _gauss(math.Random r) {
    final u1 = 1 - r.nextDouble(), u2 = r.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

/// Ready-made phase lists for the lift cases from docs/TRACKING.md. Every one of
/// them is a realistic ride or descent; the engine tests assert what the day
/// stats must look like afterwards.
class SkiProfiles {
  /// Chairlift: 2.5 m/s, +400 m in 5 min.
  static const chairlift = [Phase.stop(60), Phase.cable(400, 300, avgSpeedMs: 2.5), Phase.stop(30)];

  /// Gondola with a flat mid-span: 6 m/s, +250 m, 40 s flat, +250 m.
  static const gondolaFlatSpan = [
    Phase.stop(60),
    Phase.cable(250, 120, avgSpeedMs: 6),
    Phase.cable(0, 40, avgSpeedMs: 6),
    Phase.cable(250, 120, avgSpeedMs: 6),
    Phase.stop(30),
  ];

  /// T-bar: 3 m/s, +250 m.
  static const tbar = [Phase.stop(60), Phase.cable(250, 400, avgSpeedMs: 3), Phase.stop(30)];

  /// Funicular: 10 m/s, +900 m — faster than [TrackingConfig.liftMaxHorizontalSpeedMs].
  static const funicular = [Phase.stop(60), Phase.cable(900, 300, avgSpeedMs: 10), Phase.stop(30)];

  /// Up by gondola, one real descent, then down into the valley by gondola
  /// (7 m/s, −600 m in 6 min) — the founder's case.
  static final gondolaDownAfterRun = [
    const Phase.stop(60),
    const Phase.cable(600, 300, avgSpeedMs: 5),
    Phase.realRun(600, 300, avgSpeedMs: 15),
    const Phase.stop(30),
    const Phase.cable(-600, 360, avgSpeedMs: 7),
    const Phase.stop(30),
  ];

  /// The same day without the valley ride — the baseline for "ski numbers unchanged".
  static final runOnly = [
    const Phase.stop(60),
    const Phase.cable(600, 300, avgSpeedMs: 5),
    Phase.realRun(600, 300, avgSpeedMs: 15),
    const Phase.stop(30),
  ];

  /// A real descent: irregular 8–19 m/s with turns. Must stay a run.
  static final realDescent = [
    const Phase.stop(60),
    const Phase.cable(600, 300, avgSpeedMs: 5),
    Phase.realRun(650, 320),
    const Phase.stop(30),
  ];

  /// The founder's valley ride with a five-minute GPS dropout inside the steel
  /// cabin — the ride must still donate nothing to the ski numbers.
  static final gondolaDownDropout = [
    const Phase.stop(60),
    const Phase.cable(600, 300, avgSpeedMs: 5),
    Phase.realRun(600, 300, avgSpeedMs: 15),
    const Phase.stop(30),
    const Phase.cable(-600, 700, avgSpeedMs: 7, dropoutFrom: 150, dropoutTo: 450),
    const Phase.stop(30),
  ];

  /// A descending gondola with a mid-station stop: two standstills inside ONE
  /// ride. Two sections of 5½ min, which is what a real two-section gondola is.
  static const gondolaDownMidStation = [
    Phase.stop(60),
    Phase.cable(-300, 330, avgSpeedMs: 7),
    Phase.stop(40),
    Phase.cable(-300, 330, avgSpeedMs: 7),
    Phase.stop(60),
  ];

  /// A funicular descending inside a tunnel: GPS gone over most of the ride.
  static const funicularTunnel = [
    Phase.stop(60),
    Phase.cable(-500, 300, avgSpeedMs: 8, dropoutFrom: 30, dropoutTo: 270),
    Phase.stop(60),
  ];

  /// The beginner whose gondola home (9 m/s) is faster than anything they ski.
  static final beginnerGondolaHome = [
    const Phase.stop(60),
    const Phase.cable(450, 250, avgSpeedMs: 6),
    Phase.realRun(150, 200, avgSpeedMs: 5),
    const Phase.stop(30),
    const Phase.cable(-450, 330, avgSpeedMs: 9),
    const Phase.stop(60),
  ];

  /// The same beginner day without the ride home — the baseline.
  static final beginnerRunOnly = [
    const Phase.stop(60),
    const Phase.cable(450, 250, avgSpeedMs: 6),
    Phase.realRun(150, 200, avgSpeedMs: 5),
    const Phase.stop(30),
  ];

  /// A straight schuss at terminal velocity, 60–80 km/h. The most expensive case
  /// to get wrong: it must feed the top speed.
  static const schuss = [Phase.stop(60), Phase.run(420, 150, avgSpeedMs: 19, jitter: 0.05), Phase.stop(60)];

  /// Cat track / ski road: 5 m/s over 1.5 km at 16 %, with gentle curves —
  /// steep enough for the engine's RUN entry, so it must count as ski
  /// kilometres and must never become a lift.
  static const catTrack = [
    Phase.stop(60),
    Phase.run(240, 300, avgSpeedMs: 5, jitter: 0.08, turnRateDeg: 1.5),
    Phase.stop(60),
  ];

  /// … and the shallow variant (8 %): too flat for a run *and* for a ride.
  static const catTrackShallow = [
    Phase.stop(60),
    Phase.run(120, 300, avgSpeedMs: 5, jitter: 0.08, turnRateDeg: 1.5),
    Phase.stop(60),
  ];

  /// The ski bus down a mountain road: 10 m/s, 9.5 %, hairpins every 90 s.
  /// Steep and fast enough that the RUN rules would take it. Must be OTHER.
  static const skiBus = [Phase.stop(60), Phase.road(-400, 420, avgSpeedMs: 10), Phase.stop(60)];

  /// A magic carpet: 0.7 m/s, +15 m. Below every lift floor, by design a pause.
  static final magicCarpet = [
    const Phase.stop(30),
    const Phase.lift(15, 150, avgSpeedMs: 0.7, jitter: 0.05),
    const Phase.stop(20),
    Phase.realRun(60, 60, avgSpeedMs: 6),
    const Phase.stop(30),
  ];

  /// Two runs with 4 min of lift-queue shuffling (0.3–1.5 m/s) in between.
  static final liftQueue = [
    const Phase.stop(30),
    Phase.realRun(400, 200),
    const Phase.walk(240, avgSpeedMs: 0.9, jitter: 0.65),
    Phase.realRun(400, 200),
    const Phase.stop(30),
  ];
}

/// Convenience for tests: altitude back from pressure (no anchor).
double baroAltitude(double hPa) => hypsometricAltitude(hPa);
