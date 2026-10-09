import 'dart:collection';
import 'dart:math' as math;

import '../core/core.dart';
import 'rigidity.dart';

/// One accepted fix as the cable detector sees it.
class CableSample {
  const CableSample({required this.ts, required this.lat, required this.lon, required this.altM, required this.vMs});
  final int ts;
  final double lat, lon, altM, vMs;
}

/// Rolling-window test for "this is a cable, not a skier" (docs/TRACKING.md).
///
/// A gondola, chairlift, T-bar, cable car or funicular moves at a **constant
/// speed** along a **straight line** and changes altitude **one way only**.
/// Skiers vary their speed, turn, and lose altitude irregularly. Two levels are
/// exposed, both judged over the same window:
///
/// * [holds] — loose: constant speed, straight, altitude monotone *or* flat.
///   Holds a running LIFT together over a flat cable span and over the stretch
///   where a chairlift dips before it climbs again.
/// * [vetoesRun] — [holds] restricted to a clear *climb*. Only a window that is
///   gaining height may stop a RUN from starting: you are on a lift, not
///   skiing. Anything losing height or flat looks exactly like a straight
///   schuss over 45 s — including the gentle 6–11 % ski road, which is too
///   shallow to count as [descending] and was blocked from becoming a RUN at
///   all while the veto was defined as "not descending".
/// * [rides] — strict, and **ascending only**: the loose test plus a clear
///   altitude *gain* on a real gradient. Opens a LIFT and rewrites an
///   ascending RUN as a lift ride in finalize.
///
/// A ride *down* is not decided here at all. It cannot be: over 45 s a gondola
/// into the valley and a steady schuss are the same picture. The interval-level
/// rule in `descent.dart` cannot decide it either — see
/// [TrackingConfig.descentRidesEnabled], where the measurement and the decision
/// to switch it off are written down.
///
/// Going *up*, this window is necessary but not sufficient either. Its
/// straightness is measured over slice centroids, and averaging hides a wander:
/// a skater poling up a connector at T-bar speed scores 0.99 here. So an ascent
/// that the barometer cannot prove on its own has to clear [evaluateAscent] over
/// the whole interval, at full resolution, before it may keep its LIFT.
///
/// Deterministic and look-ahead free: the verdict depends only on the fixes fed
/// so far, so the live engine and the offline replay see the same thing.
class CableDetector {
  final Queue<CableSample> _w = Queue();
  CableSample? _last;
  bool _holds = false, _rides = false, _descending = false, _ascending = false;
  double _meanVMs = 0, _speedCv = 1, _straightness = 0, _monotonicity = 0, _altChangeM = 0, _gradientPct = 0;

  /// Loose signature: cable-like motion, flat spans allowed.
  bool get holds => _holds;

  /// Strict signature, ascending only: cable-like motion with a clear altitude
  /// *gain* on a real gradient. A descent is never judged here (see the class
  /// comment and `descent.dart`).
  bool get rides => _rides;

  /// [holds] restricted to a clear *climb* — the only verdict a RUN entry is
  /// vetoed on. Everything else must let a run start: a descent on any
  /// gradient, a flat span, and above all the gentle 6–11 % ski road, which
  /// holds the loose signature, is not steep enough to count as [descending]
  /// and would otherwise be blocked from ever becoming a RUN.
  bool get vetoesRun => _holds && _ascending;

  /// True when the window is clearly losing height on a real gradient.
  bool get descending => _descending;

  /// True when the window is clearly gaining height on a real gradient.
  bool get ascending => _ascending;

  /// Mean speed over the window (m/s); 0 while the window is too short.
  double get meanVMs => _meanVMs;

  /// Speed spread / mean speed over the window.
  double get speedCv => _speedCv;

  /// Chord / path length over the slice centroids (1.0 = straight).
  double get straightness => _straightness;

  /// |Σ Δh| / Σ|Δh| over the slices (1.0 = strictly one way).
  double get monotonicity => _monotonicity;

  /// Signed altitude change over the window (m).
  double get altChangeM => _altChangeM;

  /// |altitude change| / horizontal chord in percent.
  double get gradientPct => _gradientPct;

  int get windowSamples => _w.length;

  /// Timestamp of the oldest fix in the window (null while it is empty).
  int? get windowStartTs => _w.isEmpty ? null : _w.first.ts;

  /// Speed the last fed fix was judged with (Doppler or distance/time).
  double? get lastSpeedMs => _last?.vMs;

  /// [holds] plus a fresh fix — a stale window never holds anything.
  bool holdsAt(int nowMs) => _holds && _fresh(nowMs);

  /// [rides] plus a fresh fix.
  bool ridesAt(int nowMs) => _rides && _fresh(nowMs);

  /// [vetoesRun] plus a fresh fix.
  bool vetoesRunAt(int nowMs) => vetoesRun && _fresh(nowMs);

  bool _fresh(int nowMs) {
    final l = _last;
    return l != null && nowMs - l.ts <= TrackingConfig.cableStaleS * 1000;
  }

  void reset() {
    _w.clear();
    _last = null;
    _clearMetrics();
  }

  /// Feeds a stored point; rejected points and points without a position or a
  /// fused altitude are ignored (they carry no evidence either way).
  void addPoint(TrackPoint p) {
    final alt = p.fusedAltM;
    if (!p.accepted || !p.hasPosition || alt == null) return;
    add(ts: p.ts, lat: p.lat!, lon: p.lon!, altM: alt, speedMs: p.speedMs, speedAccMs: p.speedAccMs);
  }

  /// Feeds one accepted fix. Speed is the trusted Doppler value, else distance
  /// over time — exactly what the segment stats use, so live == offline.
  void add({required int ts, required double lat, required double lon, required double altM, double? speedMs, double? speedAccMs}) {
    final prev = _last;
    double? v;
    if (speedMs != null && speedMs >= 0 && (speedAccMs ?? 99) <= TrackingConfig.speedTrustedMaxAccMs) {
      v = speedMs;
    } else if (prev != null) {
      final dt = (ts - prev.ts) / 1000;
      if (dt > 0 && dt <= TrackingConfig.distanceMaxDtS) v = haversineM(prev.lat, prev.lon, lat, lon) / dt;
    }
    if (prev != null && ts <= prev.ts) return; // non-monotonic input never enters the window
    _last = CableSample(ts: ts, lat: lat, lon: lon, altM: altM, vMs: v ?? 0);
    if (v == null) {
      // No usable speed: the window can no longer be judged as a whole.
      _w.clear();
      _clearMetrics();
      return;
    }
    if (_w.isNotEmpty && ts - _w.last.ts > TrackingConfig.windowResetGapS * 1000) _w.clear();
    _w.addLast(_last!);
    while (_w.isNotEmpty && ts - _w.first.ts > TrackingConfig.cableWindowS * 1000) {
      _w.removeFirst();
    }
    _evaluate();
  }

  void _clearMetrics() {
    _holds = false;
    _rides = false;
    _descending = false;
    _ascending = false;
    _meanVMs = 0;
    _speedCv = 1;
    _straightness = 0;
    _monotonicity = 0;
    _altChangeM = 0;
    _gradientPct = 0;
  }

  void _evaluate() {
    _clearMetrics();
    final n = _w.length;
    if (n < TrackingConfig.cableMinSamples) return;
    if (_w.last.ts - _w.first.ts < TrackingConfig.cableMinSpanS * 1000) return;

    // 1. constant speed around a clearly non-zero mean
    var sum = 0.0;
    for (final s in _w) {
      sum += s.vMs;
    }
    final mean = sum / n;
    _meanVMs = mean;
    if (mean < TrackingConfig.cableMinSpeedMs || mean > TrackingConfig.cableMaxSpeedMs) return;
    var sq = 0.0;
    for (final s in _w) {
      final d = s.vMs - mean;
      sq += d * d;
    }
    final sd = math.sqrt(sq / n);
    _speedCv = sd / mean;
    // Relative *or* absolute: the Doppler noise floor is the same 0.3–0.5 m/s
    // at 2.5 m/s as at 10 m/s, so a slow chair can never meet a pure 10 % test.
    if (sd > math.max(TrackingConfig.cableMaxSpeedCv * mean, TrackingConfig.cableMaxSpeedSdMs)) return;

    // 2. near-straight path. Measured over slice centroids: averaging kills the
    // per-fix GPS noise, which otherwise inflates the path length of every slow
    // ride far beyond the chord.
    final k = TrackingConfig.cableSlices;
    final lat = List<double>.filled(k, 0), lon = List<double>.filled(k, 0), alt = List<double>.filled(k, 0);
    final cnt = List<int>.filled(k, 0);
    var i = 0;
    for (final s in _w) {
      final b = (i * k) ~/ n;
      lat[b] += s.lat;
      lon[b] += s.lon;
      alt[b] += s.altM;
      cnt[b]++;
      i++;
    }
    for (var b = 0; b < k; b++) {
      if (cnt[b] == 0) return;
      lat[b] /= cnt[b];
      lon[b] /= cnt[b];
      alt[b] /= cnt[b];
    }
    var path = 0.0;
    for (var b = 1; b < k; b++) {
      path += haversineM(lat[b - 1], lon[b - 1], lat[b], lon[b]);
    }
    if (path <= 0) return;
    final chord = haversineM(lat.first, lon.first, lat.last, lon.last);
    _straightness = chord / path;
    if (_straightness < TrackingConfig.cableMinStraightness) return;

    // 3. altitude: monotone (up or down), or flat throughout
    var up = 0.0, down = 0.0, maxStep = 0.0;
    for (var b = 1; b < k; b++) {
      final d = alt[b] - alt[b - 1];
      if (d >= 0) {
        up += d;
      } else {
        down -= d;
      }
      if (d.abs() > maxStep) maxStep = d.abs();
    }
    final total = up + down;
    _monotonicity = total <= 0 ? 1 : (up - down).abs() / total;
    _altChangeM = alt.last - alt.first;
    _gradientPct = chord > 0 ? _altChangeM.abs() / chord * 100 : 0;
    final monotone = _monotonicity >= TrackingConfig.cableMinAltMonotonicity;
    final flat = maxStep <= TrackingConfig.cableFlatSliceM;
    _holds = monotone || flat;
    _descending = _altChangeM <= -TrackingConfig.cableMinAltChangeM && _gradientPct >= TrackingConfig.cableMinGradientPct;
    _ascending = _altChangeM >= TrackingConfig.cableMinAltChangeM && _gradientPct >= TrackingConfig.cableMinGradientPct;
    // A ride goes somewhere — and only *upwards* is decided from a 45 s window.
    // Nobody climbs at a constant speed on a straight line without a machine, so
    // the evidence is sufficient; going down it is not (see the class comment).
    // The gradient keeps a straight cat track or a flat traverse out.
    _rides = monotone &&
        _altChangeM >= TrackingConfig.cableMinAltChangeM &&
        _gradientPct >= TrackingConfig.cableMinGradientPct;
  }
}

/// Share of `[startTs, endTs]` that carries the strict cable signature.
///
/// Each fix whose window rides marks the window it was judged on as covered;
/// the marked spans are merged and clipped to the interval, so an interval that
/// is cable-like from its first second reaches 1.0 even though the first
/// [TrackingConfig.cableWindowS] seconds can never hold a verdict of their own.
/// Starts from a cold detector at [startTs], so an interval always scores the
/// same no matter how much of the day is handed in.
double cableCoverage(List<TrackPoint> accepted, int startTs, int endTs, {int from = 0}) {
  final duration = endTs - startTs;
  if (duration <= 0) return 0;
  final d = CableDetector();
  var covered = 0;
  int? spanStart, spanEnd;
  for (var k = from; k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts < startTs) continue;
    if (p.ts > endTs) break;
    d.addPoint(p);
    if (!d.ridesAt(p.ts)) continue;
    var a = p.ts - TrackingConfig.cableWindowS * 1000;
    if (a < startTs) a = startTs;
    if (spanStart == null) {
      spanStart = a;
      spanEnd = p.ts;
    } else if (a <= spanEnd!) {
      if (p.ts > spanEnd) spanEnd = p.ts;
    } else {
      covered += spanEnd - spanStart;
      spanStart = a;
      spanEnd = p.ts;
    }
  }
  if (spanStart != null) covered += spanEnd! - spanStart;
  return covered / duration;
}

/// Where the cable ride that is running at [atTs] began.
///
/// The signature can only be read once the rolling window has filled, so a ride
/// is recognised up to `cableWindowS + cableEnterS` seconds after it started —
/// long enough for a gondola riding into the valley to donate half a kilometre
/// of "skied" distance to the run in front of it.
///
/// Replays the detector from [TrackingConfig.cableStartSnapReachS] before [atTs] up
/// to [until] (the first verdict about a window that started before [atTs] can
/// only arrive `cableWindowS` later, so the scan has to look a little past
/// [atTs]) and takes the first window that carries the strict signature. From
/// there it walks back over the station acceleration — a cabin leaves the
/// station from a standstill — for at most [TrackingConfig.cableStationS]
/// seconds, and only while the speed keeps falling, so it can never eat into a
/// run that was already going faster.
///
/// Never returns anything before [notBefore]; returns [atTs] when no ride is
/// found. [from] is the index to start scanning at.
int cableRideStart(List<TrackPoint> accepted, int atTs, {required int notBefore, required int until, int from = 0}) {
  var searchFrom = atTs - TrackingConfig.cableStartSnapReachS * 1000;
  if (searchFrom < notBefore) searchFrom = notBefore;
  var searchTo = atTs + TrackingConfig.cableWindowS * 1000;
  if (searchTo > until) searchTo = until;
  final d = CableDetector();
  final ts = <int>[];
  final vs = <double>[];
  int? windowStart;
  for (var k = from; k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts < searchFrom) continue;
    if (p.ts > searchTo) break;
    d.addPoint(p);
    if (p.ts <= atTs) {
      ts.add(p.ts);
      vs.add(d.lastSpeedMs ?? 0);
    }
    if (windowStart == null && d.ridesAt(p.ts)) windowStart = d.windowStartTs;
  }
  final w = windowStart;
  if (w == null || w >= atTs || ts.isEmpty) return atTs;
  var i = 0;
  while (i < ts.length && ts[i] < w) {
    i++;
  }
  if (i >= ts.length) i = ts.length - 1;
  var out = ts[i];
  for (var back = 0; i > 0 && back < TrackingConfig.cableStationS; back++) {
    final vPrev = vs[i - 1];
    if (vPrev < TrackingConfig.distanceMinSpeedMs) {
      out = ts[i - 1]; // standing still: the station, and the ride starts here
      break;
    }
    if (vPrev > vs[i] * 1.15) break; // no longer decelerating backwards: this is not the station
    i--;
    out = ts[i];
  }
  return out < notBefore ? notBefore : out;
}

/// Does this ascending interval hold up as a **rope**, at full resolution?
///
/// The 45 s window in [CableDetector] is enough for a ride whose *barometer*
/// already proves a machine: nobody climbs at [TrackingConfig.liftEnterVz30Ms]
/// for [TrackingConfig.cableAscentBaroWindowS] without one. It is not enough for
/// a slow rope — a T-bar or a platter climbs too gently for that rule, and there
/// the window's slice-centroid straightness is blind: a skater skating or poling
/// up a rising connector at 2–3 m/s scores a straightness of 0.99 over 45 s and
/// was booked as a cable LIFT with phantom lift kilometres, splitting the run
/// around it in two.
///
/// So a slow ascent has to prove three things a rope has and a person does not:
///
/// * **a station.** A T-bar is boarded from a standstill. A skier who comes off
///   a run at 12 m/s, pushes up the counter-slope and skis on never stood still.
///   This is the gate that closes the false positive completely.
/// * **a straight line at full resolution.** Not the slice centroids: the *bow*,
///   the mean cross-track offset over half a minute, which averages the GPS
///   noise away and leaves the bend. Measured: every rope 0,9–2,1 m; the same
///   motion with 1 °/s of wander 2,1–52 m, with 3 °/s 4,7–145 m.
/// * **a machine-constant speed over the whole ride**, smoothed, against the
///   bound the device's own reported accuracy allows.
class AscentEvidence {
  const AscentEvidence({
    required this.startTs,
    required this.endTs,
    required this.gainM,
    required this.bestVzMs,
    required this.bestGain60M,
    required this.stationBefore,
    required this.line,
    required this.speedSdMs,
    required this.speedSdBoundMs,
    required this.speedSamples,
  });

  const AscentEvidence.none()
      : startTs = 0,
        endTs = 0,
        gainM = 0,
        bestVzMs = 0,
        bestGain60M = 0,
        stationBefore = false,
        line = const RigidLine.none(),
        speedSdMs = double.infinity,
        speedSdBoundMs = 0,
        speedSamples = 0;

  final int startTs, endTs;
  final double gainM;

  /// Steepest climb over any [TrackingConfig.cableAscentBaroWindowS] of the ride.
  final double bestVzMs;

  /// Largest altitude gain over any 60 s of the ride — the segmenter's second
  /// barometric rule ([TrackingConfig.liftEnterGained60M]), re-read.
  final double bestGain60M;
  final bool stationBefore;
  final RigidLine line;
  final double speedSdMs, speedSdBoundMs;
  final int speedSamples;

  /// The barometer alone proves the machine: one of the segmenter's own two
  /// barometric rules would have opened this lift with no cable signature at all,
  /// so there is nothing here to second-guess. Both are re-read, not just the
  /// steeper one — rule 2 opens a lift at 30 m per minute (0,5 m/s), and a climb
  /// of 1.800 m/h sustained for a minute is a machine whatever its shape.
  bool get baroProven =>
      bestVzMs >= TrackingConfig.liftEnterVz30Ms || bestGain60M >= TrackingConfig.liftEnterGained60M;

  bool get steadySpeed =>
      speedSamples >= TrackingConfig.cableAscentMinSamples && speedSdBoundMs > 0 && speedSdMs <= speedSdBoundMs;

  /// Too little to judge: keep the lift. An ascent this short cannot cost more
  /// than [TrackingConfig.liftMinGainM] of phantom ascent, and throwing away
  /// every short T-bar would be the worse trade.
  bool get tooShortToJudge => line.samples < TrackingConfig.cableAscentMinSamples;

  bool get confirmed =>
      baroProven ||
      tooShortToJudge ||
      (stationBefore && line.straight && line.unbowed && line.linearAltitude && steadySpeed);

  String get why => 'gain=${gainM.round()}m vz30=${bestVzMs.toStringAsFixed(2)} g60=${bestGain60M.round()}m '
      'sd=${speedSdMs.toStringAsFixed(3)}/${speedSdBoundMs.toStringAsFixed(3)} n=$speedSamples '
      'station=${stationBefore ? 'A' : '-'} ${line.why} '
      '[${baroProven ? 'baro' : 'BARO'} ${steadySpeed ? 'steady' : 'STEADY'} '
      '${confirmed ? 'CONFIRMED' : 'rejected'}]';
}

/// Weighs the ascending interval `[fromTs, toTs]` (see [AscentEvidence]).
///
/// [accepted] must be the accepted fixes with a fused altitude, sorted by ts;
/// [from] is a starting index that may only skip work, never change the answer.
AscentEvidence evaluateAscent(List<TrackPoint> accepted, int fromTs, int toTs, {int from = 0}) {
  if (toTs <= fromTs || accepted.isEmpty) return const AscentEvidence.none();
  const look = TrackingConfig.cableAscentStationLookbackS * 1000;
  final scan = <TrackPoint>[];
  for (var k = math.max(0, from); k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts < fromTs - look) continue;
    if (p.ts > toTs) break;
    scan.add(p);
  }
  if (scan.isEmpty) return const AscentEvidence.none();

  // Steepest climb over a baro window — the segmenter's own rule 1, re-read.
  const win = TrackingConfig.cableAscentBaroWindowS * 1000;
  final inside = [
    for (final p in scan)
      if (p.ts >= fromTs) p,
  ];
  var bestVz = 0.0, bestGain = 0.0;
  var lo = 0, lo60 = 0;
  for (var i = 0; i < inside.length; i++) {
    while (inside[i].ts - inside[lo].ts > win) {
      lo++;
    }
    final dt = (inside[i].ts - inside[lo].ts) / 1000;
    if (dt >= win / 2000) {
      final vz = (inside[i].fusedAltM! - inside[lo].fusedAltM!) / dt;
      if (vz > bestVz) bestVz = vz;
    }
    while (inside[i].ts - inside[lo60].ts > 60000) {
      lo60++;
    }
    final g = inside[i].fusedAltM! - inside[lo60].fusedAltM!;
    if (g > bestGain) bestGain = g;
  }
  final gain = inside.isEmpty ? 0.0 : inside.last.fusedAltM! - inside.first.fusedAltM!;

  // The station in front of the ride, and the cruise between the two ramps.
  // Rule 1c pulls a ride's start back to the station it left, and a LIFT only
  // ends once the signature has gone stale, so the interval begins *and* ends
  // inside a standstill; a boundary snap can also let a few seconds of the run
  // behind it in. None of that is the ride, and all of it wrecks the measurement:
  // 15 s of standing still inside the speed series turns a spread of 0,10 m/s
  // into 0,49 m/s, and five seconds of a skier heading off in a new direction
  // puts the chord offset at 64 m.
  const ramp = TrackingConfig.cableAscentRampS * 1000;
  final board = standstillEndIn(scan, fromTs - look, fromTs + ramp, holdS: TrackingConfig.cableAscentStationHoldS);
  final station = board != null;
  // …and the same at the far end: a lift only leaves LIFT once the signature has
  // gone stale, so the interval reaches seconds into the top station.
  final alight = standstillStartIn(scan, toTs - look, toTs);
  final cruiseA = math.max(fromTs, board ?? fromTs) + ramp;
  final cruiseB = math.min(toTs, alight ?? toTs) - ramp;
  if (cruiseB <= cruiseA) {
    return AscentEvidence(
      startTs: fromTs, endTs: toTs, gainM: gain, bestVzMs: bestVz, bestGain60M: bestGain, stationBefore: station,
      line: const RigidLine.none(), speedSdMs: double.infinity, speedSdBoundMs: 0, speedSamples: 0,
    );
  }
  final line = measureRigidity(accepted, cruiseA, cruiseB, from: from, minSamples: TrackingConfig.cableAscentMinSamples);
  final (sd, bound, n) = smoothedSpeedSpread(accepted, cruiseA, cruiseB,
      from: from, minSamples: TrackingConfig.cableAscentMinSamples);
  return AscentEvidence(
    startTs: fromTs,
    endTs: toTs,
    gainM: gain,
    bestVzMs: bestVz,
    bestGain60M: bestGain,
    stationBefore: station,
    line: line,
    speedSdMs: sd,
    speedSdBoundMs: bound,
    speedSamples: n,
  );
}
