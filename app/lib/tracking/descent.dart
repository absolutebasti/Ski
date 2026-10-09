import 'dart:math' as math;

import '../core/core.dart';
import 'rigidity.dart';

export 'rigidity.dart' show RigidLine, measureRigidity, standstills;

/// Is this descent a cable riding DOWN into the valley, or is it skiing?
///
/// **Switched off in the shipped build** — see [TrackingConfig.descentRidesEnabled].
/// Measured over 4.320 synthetic ski-road days, 427 of them lost a real run to
/// this rule, and nothing measurable separates the two populations. The code and
/// its tests stay, so the decision can be revisited with better evidence; what
/// does *not* stay is a rule that silently deletes runs.
///
/// **The rule is deliberately asymmetric** (docs/TRACKING.md). Nobody gains
/// altitude at a constant speed along a straight line without a machine, so the
/// rolling-window signature in `cable.dart` is evidence enough for a ride *up*.
/// Losing altitude at a constant speed along a straight line is exactly what a
/// schuss looks like, so a ride *down* has to clear every hurdle below before it
/// may be taken away from the skier. Missing a gondola valley ride costs a few
/// lift kilometres; eating a real run costs the top speed.
///
/// All of these must hold, and they are measured at **full resolution** — never
/// over averaged slices, which is what made the first version of this rule read
/// a straight steady descent as a gondola:
///
/// * **station to station** — a standstill within [TrackingConfig.descentStationLookbackS]
///   before the ride starts *and* another one after it ends. A cabin is boarded
///   and left at a station; this is the single strongest discriminator and it
///   cannot be averaged away.
/// * **length** — at least [TrackingConfig.descentMinDurationS] and
///   [TrackingConfig.descentMinDropM]. A two-minute schuss cannot qualify.
/// * **speed** — inside the cable band and above
///   [TrackingConfig.descentMinSpeedMs], and constant against a bound derived
///   from the *reported* `speedAccMs`, not a hard-coded number.
/// * **geometric rigidity** — every accepted fix within a few `hAcc` of the
///   start-end chord.
/// * **gradient rigidity** — altitude linear in cumulative distance, because a
///   cable is a straight line in 3D while a piste rolls.
class DescentEvidence {
  const DescentEvidence({
    required this.startTs,
    required this.endTs,
    required this.samples,
    required this.meanVMs,
    required this.speedSdMs,
    required this.speedSdBoundMs,
    required this.chordOffsetM,
    required this.chordOffsetBoundM,
    required this.altResidualM,
    required this.dropM,
    required this.gradientPct,
    required this.stationBefore,
    required this.stationAfter,
    this.samplesFloor = TrackingConfig.descentMinSamples,
  });

  /// No evidence at all (too few fixes, no station, inverted interval).
  const DescentEvidence.none()
      : startTs = 0,
        endTs = 0,
        samples = 0,
        meanVMs = 0,
        speedSdMs = 0,
        speedSdBoundMs = 0,
        chordOffsetM = 0,
        chordOffsetBoundM = 0,
        altResidualM = 0,
        dropM = 0,
        gradientPct = 0,
        stationBefore = false,
        stationAfter = false,
        samplesFloor = TrackingConfig.descentMinSamples;

  /// The ride as the evidence reads it: from the standstill it left to the
  /// standstill it reached (so the seconds before the ride was recognisable
  /// belong to the ride, not to the run in front of it).
  final int startTs, endTs;

  /// Accepted fixes in the cruise portion the speed spread was measured on.
  final int samples;
  /// How many of them the verdict needs. Smaller on the live path, where the
  /// verdict only holds a number back for another second.
  final int samplesFloor;
  final double meanVMs, speedSdMs, speedSdBoundMs;
  final double chordOffsetM, chordOffsetBoundM;
  final double altResidualM, dropM, gradientPct;
  final bool stationBefore, stationAfter;

  int get durationS => (endTs - startTs) ~/ 1000;

  bool get longEnough => durationS >= TrackingConfig.descentMinDurationS && durationS <= TrackingConfig.descentMaxRideS;
  bool get deepEnough =>
      dropM >= TrackingConfig.descentMinDropM &&
      gradientPct >= TrackingConfig.descentMinGradientPct &&
      durationS > 0 &&
      dropM / durationS >= TrackingConfig.descentMinVerticalMs;
  bool get fastEnough => meanVMs >= TrackingConfig.descentMinSpeedMs && meanVMs <= TrackingConfig.cableMaxSpeedMs;
  bool get steadySpeed => samples >= samplesFloor && speedSdBoundMs > 0 && speedSdMs <= speedSdBoundMs;
  /// The cruise is still too short to say anything at all — not a failure.
  bool get tooShortToJudge => samples < samplesFloor;
  bool get straightChord => chordOffsetBoundM > 0 && chordOffsetM <= chordOffsetBoundM;
  bool get rigidGradient => altResidualM <= TrackingConfig.descentMaxAltResidualM;

  /// Every hurdle cleared: this interval is a cable ride down, not a run.
  bool get ride =>
      stationBefore && stationAfter && longEnough && deepEnough && fastEnough && steadySpeed && straightChord && rigidGradient;

  /// Everything that can already be known while the cabin is still moving —
  /// the live top speed uses this to hold a provisional peak back instead of
  /// showing a number the day's end would throw away.
  bool get possible => stationBefore && fastEnough && steadySpeed && straightChord && rigidGradient && dropM > 0;

  /// Why it did (not) qualify — the reason string for test failures.
  String get why => 'dur=${durationS}s drop=${dropM.round()}m grad=${gradientPct.toStringAsFixed(1)}% '
      'vz=${(durationS > 0 ? dropM / durationS : 0).toStringAsFixed(2)} '
      'v=${meanVMs.toStringAsFixed(2)} sd=${speedSdMs.toStringAsFixed(3)}/${speedSdBoundMs.toStringAsFixed(3)} '
      'off=${chordOffsetM.toStringAsFixed(1)}/${chordOffsetBoundM.toStringAsFixed(1)}m '
      'alt=${altResidualM.toStringAsFixed(2)}m n=$samples '
      'station=${stationBefore ? 'A' : '-'}${stationAfter ? 'B' : '-'} '
      '[${longEnough ? 'len' : 'LEN'} ${deepEnough ? 'deep' : 'DEEP'} ${fastEnough ? 'fast' : 'FAST'} '
      '${steadySpeed ? 'steady' : 'STEADY'} ${straightChord ? 'straight' : 'STRAIGHT'} ${rigidGradient ? 'rigid' : 'RIGID'}]';
}

/// Weighs the descent that the interval `[fromTs, toTs]` covers.
///
/// [accepted] must be the accepted fixes with a fused altitude, sorted by ts.
/// [from] is a starting index (a binary search by the caller) — it may only skip
/// work, never change the answer, so it must point at or before the first fix
/// that can carry a standstill for this interval.
///
/// With [requireStationAfter] false the ride is judged as far as it has come
/// (the live path, where the cabin has not arrived yet).
DescentEvidence evaluateDescent(
  List<TrackPoint> accepted,
  int fromTs,
  int toTs, {
  int from = 0,
  bool requireStationAfter = true,
  int minSamples = TrackingConfig.descentMinSamples,
  double boundSlack = 1.0,
}) {
  if (toTs <= fromTs || accepted.isEmpty) return const DescentEvidence.none();
  const look = TrackingConfig.descentStationLookbackS * 1000;
  const ramp = TrackingConfig.descentRampS * 1000;
  // Fixes that can carry a station verdict for either end.
  final scan = <TrackPoint>[];
  for (var k = math.max(0, from); k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts < fromTs - look) continue;
    if (p.ts > toTs + look) break;
    scan.add(p);
  }
  if (scan.length < minSamples) return const DescentEvidence.none();

  final board = standstillEndIn(scan, fromTs - look, fromTs + ramp);
  if (board == null) return const DescentEvidence.none();
  final alight = requireStationAfter ? standstillStartIn(scan, toTs - ramp, toTs + look) : toTs;
  final endTs = alight ?? toTs;
  if (endTs <= board) return const DescentEvidence.none();

  final ride = [
    for (final p in scan)
      if (p.ts >= board && p.ts <= endTs) p,
  ];
  if (ride.length < minSamples) return const DescentEvidence.none();

  // --- speed constancy over the cruise portion, bound from the device ---
  // Both station ramps are dropped, on the live path too: the last seconds of a
  // ride are the cabin braking into the station, and counting them would break
  // the live verdict exactly when the ride is nearly over — which is when the
  // gondola's speed would land on the screen.
  final cruiseA = board + ramp, cruiseB = endTs - ramp;
  final vs = <double>[];
  final speedAcc = <double>[];
  TrackPoint? prev;
  for (final p in ride) {
    final v = speedOfFix(p, prev);
    prev = p;
    if (p.ts < cruiseA || p.ts > cruiseB || v == null) continue;
    vs.add(v);
    speedAcc.add(p.speedAccMs ?? 99);
  }
  var mean = 0.0, sd = 0.0, bound = 0.0;
  if (vs.length >= minSamples) {
    // Doppler noise is white and averages out; a skier's speed changes are
    // correlated over several seconds and survive the smoothing. Measuring the
    // spread of the *smoothed* series is what separates the two.
    const w = TrackingConfig.descentSpeedSmoothS;
    final sm = <double>[];
    for (var i = 0; i + w <= vs.length; i++) {
      var s = 0.0;
      for (var k = 0; k < w; k++) {
        s += vs[i + k];
      }
      sm.add(s / w);
    }
    mean = vs.reduce((a, b) => a + b) / vs.length;
    final smMean = sm.reduce((a, b) => a + b) / sm.length;
    var sq = 0.0;
    for (final x in sm) {
      sq += (x - smMean) * (x - smMean);
    }
    sd = math.sqrt(sq / sm.length);
    final medAcc = medianOf(speedAcc);
    // A device that does not report a trustworthy speed accuracy carries no
    // evidence: no bound, no ride.
    bound = medAcc <= TrackingConfig.speedTrustedMaxAccMs
        ? math.max(TrackingConfig.descentSpeedSdFactor * medAcc, TrackingConfig.descentSpeedSdFloorMs) * boundSlack
        : 0.0;
  }

  // --- geometric rigidity: perpendicular offset from the chord, per fix ---
  final p0 = ride.first, p1 = ride.last;
  final mLat = 111320.0, mLon = 111320.0 * math.cos(p0.lat! * math.pi / 180);
  final cx = (p1.lon! - p0.lon!) * mLon, cy = (p1.lat! - p0.lat!) * mLat;
  final chord = math.sqrt(cx * cx + cy * cy);
  var offset = double.infinity;
  var residual = double.infinity;
  final medHAcc = medianOf([for (final p in ride) p.hAccM ?? 99]);
  // Factor · hAcc, with a floor *and* an absolute cap: the offset a real curving
  // path shows does not grow with the reported accuracy, so without the cap a
  // noisy phone (2,5 × 30 m = 75 m) silently switched the test off.
  final offsetBound = medHAcc <= TrackingConfig.maxHorizontalAccuracyM
      ? math.min(TrackingConfig.descentMaxChordOffsetCapM,
              math.max(TrackingConfig.descentMaxChordOffsetFactor * medHAcc, TrackingConfig.descentMaxChordOffsetFloorM)) *
          boundSlack
      : 0.0;
  if (chord > 1) {
    offset = 0;
    // --- gradient rigidity: altitude linear in distance along the ride ---
    // Distance is measured *along the chord*, not as the walked path: per-fix
    // GPS noise inflates a walked path by a few per cent per step, and it cannot
    // inflate the one long step across a GPS dropout — which would bend the fit
    // and make every gondola with a dropout look like a piste that rolls. The
    // projection onto the chord has no such bias.
    var n = 0;
    double sx = 0, sy = 0, sxx = 0, sxy = 0;
    final xs = <double>[], ys = <double>[];
    for (final p in ride) {
      final px = (p.lon! - p0.lon!) * mLon, py = (p.lat! - p0.lat!) * mLat;
      final d = ((px * cy - py * cx) / chord).abs();
      if (d > offset) offset = d;
      final x = (px * cx + py * cy) / chord;
      final a = p.fusedAltM!;
      xs.add(x);
      ys.add(a);
      sx += x;
      sy += a;
      sxx += x * x;
      sxy += x * a;
      n++;
    }
    final den = n * sxx - sx * sx;
    if (den.abs() > 1e-9) {
      final slope = (n * sxy - sx * sy) / den;
      final icpt = (sy - slope * sx) / n;
      var rss = 0.0;
      for (var i = 0; i < n; i++) {
        final r = ys[i] - (icpt + slope * xs[i]);
        rss += r * r;
      }
      residual = math.sqrt(rss / n);
    }
  }

  final drop = ride.first.fusedAltM! - ride.last.fusedAltM!;
  return DescentEvidence(
    startTs: board,
    endTs: endTs,
    samples: vs.length,
    meanVMs: mean,
    speedSdMs: sd,
    speedSdBoundMs: bound,
    chordOffsetM: offset,
    chordOffsetBoundM: offsetBound,
    altResidualM: residual,
    dropM: drop,
    gradientPct: chord > 1 ? drop.abs() / chord * 100 : 0,
    stationBefore: true,
    stationAfter: alight != null,
    samplesFloor: minSamples,
  );
}

/// Live companion to [evaluateDescent]: tracks the descent the skier *might*
/// currently be on, from the last standstill onwards.
///
/// Used by the engine to hold a provisional top speed back. A candidate dies the
/// moment its evidence breaks and is only reborn at the next standstill, so a
/// skiing day costs one evaluation per standstill, not one per tick.
class DescentCandidate {
  int? _startTs;
  int? _graceFrom;
  int _graceUntil = 0;
  int _nowTs = 0;
  int _lastJudgeTs = 0;
  bool _alive = false;
  bool _dead = false;
  int _breakTicks = 0;
  DescentEvidence _ev = const DescentEvidence.none();

  /// Peaks stamped at or after this timestamp are provisional and must be held
  /// back; null when nothing is being held.
  int? get holdFrom {
    final a = _alive ? _startTs : null;
    final b = _graceUntil > _nowTs ? _graceFrom : null;
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  DescentEvidence get evidence => _ev;

  void reset() {
    _startTs = null;
    _graceFrom = null;
    _graceUntil = 0;
    _alive = false;
    _dead = false;
    _breakTicks = 0;
    _lastJudgeTs = 0;
    _ev = const DescentEvidence.none();
  }

  /// Feeds the tick. [descending] is the segmenter's "this is going down" state,
  /// [points] the accepted points with a fused altitude so far.
  void update({required int ts, required bool descending, required double? speedMs, required List<TrackPoint> points}) {
    _nowTs = ts;
    if (speedMs != null && speedMs < TrackingConfig.descentStationSpeedMs) {
      // A standstill ends the candidate and opens the next one — a cabin starts
      // at a station. If the one that just ended was never disproved, its peaks
      // stay held for a grace period: the ride can only be rewritten once this
      // standstill itself has registered, a handful of seconds from now.
      if (_alive && _startTs != null) {
        _graceFrom = _startTs;
        _graceUntil = ts + TrackingConfig.descentHoldGraceS * 1000;
      }
      _startTs = ts;
      _alive = false;
      _dead = false;
      _breakTicks = 0;
      _ev = const DescentEvidence.none();
      return;
    }
    final s = _startTs;
    if (s == null || _dead || !descending) {
      if (!descending) _alive = false;
      return;
    }
    if (ts - s > TrackingConfig.descentMaxRideS * 1000) {
      _dead = true;
      _alive = false;
      return;
    }
    // Too young to say anything: hold back, it may still be a cabin.
    if (ts - s < (TrackingConfig.descentRampS + 5) * 1000) {
      _alive = true;
      return;
    }
    if (ts - _lastJudgeTs < 1000) return;
    _lastJudgeTs = ts;
    _ev = evaluateDescent(points, s, ts,
        requireStationAfter: false,
        minSamples: TrackingConfig.descentLiveMinSamples,
        boundSlack: TrackingConfig.descentLiveBoundSlack);
    // "Not enough cruise yet" is not a verdict — it must not kill the candidate,
    // or the hold is released while the cabin is still accelerating out of the
    // station and the gondola's speed lands on the screen.
    if (_ev.tooShortToJudge) {
      _alive = true;
      _breakTicks = 0;
      return;
    }
    if (_ev.possible) {
      _alive = true;
      _breakTicks = 0;
      return;
    }
    // One noisy second is not a verdict either; the evidence has to stay broken.
    _breakTicks++;
    if (_breakTicks >= TrackingConfig.descentLiveBreakS) {
      _alive = false;
      _dead = true; // not a ride from this station
    }
  }
}
