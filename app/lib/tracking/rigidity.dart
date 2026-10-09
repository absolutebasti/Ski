import 'dart:math' as math;

import '../core/core.dart';

/// Full-resolution geometry of a candidate cable ride: how straight the line
/// really is, and how linear the altitude is along it.
///
/// Measured **per accepted fix**, never over averaged slices. Averaging is what
/// makes a slow ride measurable at all in the 45 s rolling window of
/// `cable.dart`, and it is also what hides a wander: a skater poling up a
/// connector scores a slice-centroid straightness of 0.99 over 45 s. Over the
/// whole interval, at full resolution, a rope and a person are different shapes.
///
/// Two offsets, because they answer different questions:
///
/// * [maxOffsetM] — the largest perpendicular distance of any fix from the
///   start-end chord. Dominated by per-fix GPS noise (≈ 3 × the position sigma),
///   so it catches only a gross bend.
/// * [bowM] — the largest *mean* perpendicular offset over a fixed window of
///   [TrackingConfig.cableAscentBowWindowS] seconds, measured against the
///   least-squares line through the ride (not the endpoint chord, whose own two
///   fixes would tilt it). Averaging removes the GPS noise, so what is left is
///   the bend itself. This is the discriminator.
class RigidLine {
  const RigidLine({
    required this.samples,
    required this.chordM,
    required this.maxOffsetM,
    required this.bowM,
    required this.altResidualM,
    required this.medianHAccM,
  });

  const RigidLine.none()
      : samples = 0,
        chordM = 0,
        maxOffsetM = double.infinity,
        bowM = double.infinity,
        altResidualM = double.infinity,
        medianHAccM = 99;

  final int samples;
  final double chordM;
  final double maxOffsetM;
  final double bowM;

  /// RMS residual of altitude fitted against distance *along the chord*. A cable
  /// is a straight line in 3D; a piste rolls. Distance along the chord, not the
  /// walked path: per-fix noise inflates a walked path by a few per cent per
  /// step and cannot inflate the single long step across a GPS dropout, which
  /// would bend the fit and make every gondola with a dropout look like a piste.
  final double altResidualM;

  /// Median reported horizontal accuracy over the ride — every bound is derived
  /// from it, so a quiet phone is held to a tighter line than a noisy one.
  final double medianHAccM;

  /// Largest bow a rope may show: the GPS noise floor of the measurement,
  /// scaled by what the device claims, and capped so a noisy device cannot
  /// switch the test off.
  double get bowBoundM => medianHAccM > TrackingConfig.maxHorizontalAccuracyM
      ? 0
      : math.min(
          TrackingConfig.cableAscentMaxBowCapM,
          math.max(TrackingConfig.cableAscentMaxBowFactor * medianHAccM, TrackingConfig.cableAscentMaxBowFloorM),
        );

  /// Largest per-fix offset from the chord a rope may show. Scales with the
  /// reported accuracy, with a floor *and* an absolute cap: the offset of a real
  /// curving path does not grow with the reported accuracy, so without the cap a
  /// noisy phone silently disabled the test (2,5 × 30 m = 75 m).
  double get maxOffsetBoundM => medianHAccM > TrackingConfig.maxHorizontalAccuracyM
      ? 0
      : math.min(
          TrackingConfig.descentMaxChordOffsetCapM,
          math.max(TrackingConfig.descentMaxChordOffsetFactor * medianHAccM, TrackingConfig.descentMaxChordOffsetFloorM),
        );

  bool get straight => chordM > 1 && maxOffsetBoundM > 0 && maxOffsetM <= maxOffsetBoundM;
  bool get unbowed => chordM > 1 && bowBoundM > 0 && bowM <= bowBoundM;
  bool get linearAltitude => altResidualM <= TrackingConfig.descentMaxAltResidualM;

  String get why => 'n=$samples chord=${chordM.round()}m '
      'off=${maxOffsetM.toStringAsFixed(1)}/${maxOffsetBoundM.toStringAsFixed(1)}m '
      'bow=${bowM.toStringAsFixed(2)}/${bowBoundM.toStringAsFixed(2)}m '
      'alt=${altResidualM.toStringAsFixed(2)}m hAcc=${medianHAccM.toStringAsFixed(1)} '
      '[${straight ? 'straight' : 'STRAIGHT'} ${unbowed ? 'unbowed' : 'BOWED'} '
      '${linearAltitude ? 'linear' : 'ROLLS'}]';
}

double medianOf(List<double> xs) {
  if (xs.isEmpty) return double.infinity;
  final s = [...xs]..sort();
  return s[s.length ~/ 2];
}

/// Measures [RigidLine] over the fixes of `[fromTs, toTs]`.
///
/// [pts] must be accepted fixes with a position and a fused altitude, sorted by
/// ts. [from] is a starting index; it may only skip work, never change the
/// answer.
RigidLine measureRigidity(List<TrackPoint> pts, int fromTs, int toTs, {int from = 0, int minSamples = 20}) {
  final ride = <TrackPoint>[];
  for (var k = math.max(0, from); k < pts.length; k++) {
    final p = pts[k];
    if (p.ts < fromTs) continue;
    if (p.ts > toTs) break;
    if (p.hasPosition && p.fusedAltM != null) ride.add(p);
  }
  if (ride.length < minSamples) return const RigidLine.none();
  final p0 = ride.first, p1 = ride.last;
  const mLat = 111320.0;
  final mLon = 111320.0 * math.cos(p0.lat! * math.pi / 180);
  final cx = (p1.lon! - p0.lon!) * mLon, cy = (p1.lat! - p0.lat!) * mLat;
  final chord = math.sqrt(cx * cx + cy * cy);
  final medHAcc = medianOf([for (final p in ride) p.hAccM ?? 99]);
  if (chord <= 1) {
    return RigidLine(
      samples: ride.length, chordM: chord, maxOffsetM: double.infinity, bowM: double.infinity,
      altResidualM: double.infinity, medianHAccM: medHAcc,
    );
  }

  // Along-chord distance and cross-track offset per fix.
  final along = <double>[], cross = <double>[], alt = <double>[];
  final ts = <int>[];
  var maxOffset = 0.0;
  for (final p in ride) {
    final px = (p.lon! - p0.lon!) * mLon, py = (p.lat! - p0.lat!) * mLat;
    final d = (px * cy - py * cx) / chord;
    if (d.abs() > maxOffset) maxOffset = d.abs();
    along.add((px * cx + py * cy) / chord);
    cross.add(d);
    alt.add(p.fusedAltM!);
    ts.add(p.ts);
  }

  final n = along.length;
  final altResidual = _rmsResidual(along, alt);
  // The bow: the endpoint chord is tilted by the noise of its own two fixes, so
  // the residuals are taken against the least-squares line instead.
  final tilt = _fit(along, cross);
  final resid = [for (var i = 0; i < n; i++) cross[i] - (tilt.$2 + tilt.$1 * along[i])];
  var bow = 0.0;
  var lo = 0;
  var sum = 0.0;
  const windowMs = TrackingConfig.cableAscentBowWindowS * 1000;
  for (var i = 0; i < n; i++) {
    sum += resid[i];
    while (ts[i] - ts[lo] > windowMs) {
      sum -= resid[lo];
      lo++;
    }
    final len = i - lo + 1;
    // A window the fixes do not really cover (a GPS dropout) proves nothing.
    if (ts[i] - ts[lo] < windowMs ~/ 2 || len < 5) continue;
    final m = (sum / len).abs();
    if (m > bow) bow = m;
  }
  return RigidLine(
    samples: n, chordM: chord, maxOffsetM: maxOffset, bowM: bow,
    altResidualM: altResidual, medianHAccM: medHAcc,
  );
}

/// (slope, intercept) of a least-squares fit of [ys] on [xs].
(double, double) _fit(List<double> xs, List<double> ys) {
  final n = xs.length;
  double sx = 0, sy = 0, sxx = 0, sxy = 0;
  for (var i = 0; i < n; i++) {
    sx += xs[i];
    sy += ys[i];
    sxx += xs[i] * xs[i];
    sxy += xs[i] * ys[i];
  }
  final den = n * sxx - sx * sx;
  if (den.abs() < 1e-9) return (0, n == 0 ? 0 : sy / n);
  final slope = (n * sxy - sx * sy) / den;
  return (slope, (sy - slope * sx) / n);
}

double _rmsResidual(List<double> xs, List<double> ys) {
  if (xs.length < 3) return double.infinity;
  final (slope, icpt) = _fit(xs, ys);
  var rss = 0.0;
  for (var i = 0; i < xs.length; i++) {
    final r = ys[i] - (icpt + slope * xs[i]);
    rss += r * r;
  }
  return math.sqrt(rss / xs.length);
}

/// Spread of the speed series of `[fromTs, toTs]`, smoothed over
/// [TrackingConfig.descentSpeedSmoothS] seconds, and the bound it is judged
/// against (from the *reported* `speedAccMs`, never a constant).
///
/// Doppler noise is white and averages out; a person's speed changes are
/// correlated over seconds and survive the smoothing. `(sd, bound, samples)`;
/// bound 0 means the device reported no trustworthy accuracy, which is no
/// evidence either way.
(double, double, int) smoothedSpeedSpread(
  List<TrackPoint> pts,
  int fromTs,
  int toTs, {
  int from = 0,
  int minSamples = TrackingConfig.descentMinSamples,
  double boundSlack = 1.0,
}) {
  final vs = <double>[];
  final accs = <double>[];
  TrackPoint? prev;
  for (var k = math.max(0, from); k < pts.length; k++) {
    final p = pts[k];
    if (p.ts > toTs) break;
    final v = speedOfFix(p, prev);
    prev = p;
    if (p.ts < fromTs || v == null) continue;
    vs.add(v);
    accs.add(p.speedAccMs ?? 99);
  }
  if (vs.length < minSamples) return (double.infinity, 0, vs.length);
  const w = TrackingConfig.descentSpeedSmoothS;
  final sm = <double>[];
  for (var i = 0; i + w <= vs.length; i++) {
    var s = 0.0;
    for (var k = 0; k < w; k++) {
      s += vs[i + k];
    }
    sm.add(s / w);
  }
  if (sm.isEmpty) return (double.infinity, 0, vs.length);
  final mean = sm.reduce((a, b) => a + b) / sm.length;
  var sq = 0.0;
  for (final x in sm) {
    sq += (x - mean) * (x - mean);
  }
  final sd = math.sqrt(sq / sm.length);
  final medAcc = medianOf(accs);
  final bound = medAcc <= TrackingConfig.speedTrustedMaxAccMs
      ? math.max(TrackingConfig.descentSpeedSdFactor * medAcc, TrackingConfig.descentSpeedSdFloorMs) * boundSlack
      : 0.0;
  return (sd, bound, vs.length);
}

/// Speed of [p] the way every other part of the engine reads it: trusted
/// Doppler, else distance over time against [prev]. Null when neither is usable.
double? speedOfFix(TrackPoint p, TrackPoint? prev) {
  final v = p.speedMs;
  if (v != null && v >= 0 && (p.speedAccMs ?? 99) <= TrackingConfig.speedTrustedMaxAccMs) return v;
  if (prev == null || !prev.hasPosition || !p.hasPosition) return null;
  final dt = (p.ts - prev.ts) / 1000;
  if (dt <= 0 || dt > TrackingConfig.distanceMaxDtS) return null;
  return haversineM(prev.lat!, prev.lon!, p.lat!, p.lon!) / dt;
}

/// Every sustained standstill in [accepted] as `(firstTs, lastTs)`.
///
/// These are the candidate stations: a cabin is boarded at one and left at the
/// next, a T-bar is boarded at one. Searching station pairs — instead of only
/// whole segmenter intervals — is what finds a ride that the segmenter glued
/// onto the run in front of it, because a 30 s stop at the top station is
/// shorter than [TrackingConfig.runStopAbsorbS] and never ends the run.
List<(int, int)> standstills(List<TrackPoint> accepted) {
  final out = <(int, int)>[];
  int? start, last;
  TrackPoint? prev;
  for (final p in accepted) {
    final v = speedOfFix(p, prev);
    prev = p;
    if (v != null && v < TrackingConfig.descentStationSpeedMs) {
      start ??= p.ts;
      last = p.ts;
    } else {
      if (start != null && last! - start >= TrackingConfig.descentStationHoldS * 1000) out.add((start, last));
      start = null;
      last = null;
    }
  }
  if (start != null && last! - start >= TrackingConfig.descentStationHoldS * 1000) out.add((start, last));
  return out;
}

/// Last fix of the latest sustained standstill inside `[a, b]`, or null.
///
/// [holdS] is how long the standstill has to last. The default is the station
/// hold a cabin needs; the ascending gate asks for longer, because a skier
/// crawling through the bottom of a counter-slope does slow below
/// [TrackingConfig.descentStationSpeedMs] for a few seconds and that is not a
/// T-bar station.
int? standstillEndIn(List<TrackPoint> pts, int a, int b, {int holdS = TrackingConfig.descentStationHoldS}) {
  int? runStart, best;
  TrackPoint? prev;
  for (final p in pts) {
    final v = speedOfFix(p, prev);
    prev = p;
    if (p.ts < a || p.ts > b) continue;
    if (v != null && v < TrackingConfig.descentStationSpeedMs) {
      runStart ??= p.ts;
      if (p.ts - runStart >= holdS * 1000) best = p.ts;
    } else {
      runStart = null;
    }
  }
  return best;
}

/// First fix of the earliest sustained standstill inside `[a, b]`, or null.
int? standstillStartIn(List<TrackPoint> pts, int a, int b) {
  int? runStart;
  TrackPoint? prev;
  for (final p in pts) {
    final v = speedOfFix(p, prev);
    prev = p;
    if (p.ts < a || p.ts > b) continue;
    if (v != null && v < TrackingConfig.descentStationSpeedMs) {
      runStart ??= p.ts;
      if (p.ts - runStart >= TrackingConfig.descentStationHoldS * 1000) return runStart;
    } else {
      runStart = null;
    }
  }
  return null;
}
