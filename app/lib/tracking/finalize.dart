import 'dart:math' as math;

import '../core/core.dart';
import 'cable.dart';
import 'descent.dart';
import 'segmenter.dart';
import 'speed.dart';

/// Applies validity + merge rules to raw intervals and computes per-segment stats
/// from the accepted points. Deterministic: same inputs → same segments.
///
/// [firstIdx] / [firstRunNumber] let the engine finalize only the tail of a
/// day (provisional live view) and splice it behind already finalized
/// segments. Every scan over [points] starts at a binary-searched index, so
/// one call costs O(n + S·log n) instead of O(S·n).
List<Segment> finalizeSegments(List<RawInterval> raw, List<TrackPoint> points, {required String dayId, int firstIdx = 0, int firstRunNumber = 1}) {
  if (raw.isEmpty) return const [];
  // 1. copy + sort + merge adjacent same kind
  final iv = raw.map((r) => RawInterval(kind: r.kind, startTs: r.startTs, endTs: r.endTs, vehicle: r.vehicle, cable: r.cable)).toList()
    ..sort((a, b) => a.startTs.compareTo(b.startTs));
  for (var i = 1; i < iv.length; i++) {
    if (iv[i].startTs < iv[i - 1].endTs) iv[i].startTs = iv[i - 1].endTs;
  }
  final accepted = points.where((p) => p.accepted && p.fusedAltM != null).toList();
  _mergeAdjacent(iv, accepted);

  // 1b. cable post-pass. A gondola, cable car, T-bar or funicular carries a
  // signature the segmenter only recognises after ~1 min (the window has to
  // fill), and a ride *down* into the valley looks like a run to the state
  // machine. So re-read every run and lift against the signature: a run that is
  // mostly cable becomes a lift ride, and a lift that is mostly cable is
  // "cable-confirmed" and may lose altitude (see the validity rule below).
  // `from` is a binary search per interval, so the whole pass stays O(n).
  for (final r in iv) {
    if (r.kind != SegmentKind.run && r.kind != SegmentKind.lift) continue;
    final cov = cableCoverage(accepted, r.startTs, r.endTs, from: lowerBoundTs(accepted, r.startTs));
    if (cov < TrackingConfig.cableRunVetoCoverage) continue;
    r.cable = true;
    if (r.kind == SegmentKind.run) r.kind = SegmentKind.lift;
  }
  // A run rewritten as a lift joins the ride it belongs to *before* the
  // duration rule looks at it (a 40 s sliver alone would be thrown away).
  _mergeAdjacent(iv, accepted);

  // 1b-down. …and the other direction, which is **switched off**
  // ([TrackingConfig.descentRidesEnabled]). A gondola riding down into the
  // valley cannot be recognised from a 45 s window, and — measured over 4.320
  // synthetic ski-road days — it cannot be recognised from the interval either:
  // a straight ski road and a valley cabin have the same speed spread, the same
  // chord offset and the same altitude linearity. The rule below is complete and
  // tested; leaving it on deleted 427 real runs. So a gondola riding down counts
  // as a run (docs/TRACKING.md → Grenzen).
  if (TrackingConfig.descentRidesEnabled) {
    _descendingCablePass(iv, accepted);
    _mergeAdjacent(iv, accepted);
  }

  // 1c. …and pull each cable ride's start back to where the ride really began.
  // The window needs ~1 min to fill, so without this the last minute before the
  // cabin was recognised stays on the neighbour's account — as skied kilometres
  // if the neighbour was a run. Reaches back at most
  // TrackingConfig.cableStartSnapReachS (= cableWindowS + cableEnterS + cableStationS).
  for (var i = 0; i < iv.length; i++) {
    final r = iv[i];
    if (r.kind != SegmentKind.lift) continue;
    final prev = i > 0 ? iv[i - 1] : null;
    // A ride cannot begin inside another ride, so a lift in front of this one is
    // a hard floor (riding up and straight back down shares a station).
    // …and never behind the first interval handed in. On the live path that is the
    // splice point of the frozen prefix, and `accepted` deliberately reaches
    // finalizeLookbackS further back so the signature can be replayed — without
    // this floor the ride's start walks into the prefix and the two overlap by up
    // to 90 s. On a full pass the day's first interval starts at or before the
    // first fix, so the floor changes nothing.
    final notBefore = prev == null
        ? (accepted.isEmpty ? r.startTs : math.max(accepted.first.ts, iv.first.startTs))
        : (prev.kind == SegmentKind.lift ? prev.endTs : prev.startTs);
    final at = cableRideStart(accepted, r.startTs,
        notBefore: notBefore,
        until: r.endTs,
        from: lowerBoundTs(accepted, r.startTs - TrackingConfig.cableStartSnapReachS * 1000));
    if (at >= r.startTs) continue;
    r.startTs = at;
    if (prev != null) prev.endTs = at;
  }
  iv.removeWhere((r) => r.durationMs <= 0);
  // A neighbour that was consumed whole would leave a hole in the timeline; the
  // interval in front of it takes the hole over so the day stays contiguous.
  for (var i = 1; i < iv.length; i++) {
    if (iv[i].startTs > iv[i - 1].endTs) iv[i - 1].endTs = iv[i].startTs;
  }
  _mergeAdjacent(iv, accepted);
  // Now that every ride reaches back to its station, a sliver left between two
  // rides in the same direction is one tick of lost grip, not a second ride.
  _absorbLiftSlivers(iv, accepted);

  // 1d. …and the ascending side gets the same full-resolution treatment the
  // descending side gets. The 45 s window measures straightness over slice
  // centroids, and averaging hides a wander: a skater poling up a rising
  // connector at T-bar speed scores 0.99 there and was booked as a cable LIFT
  // with phantom lift kilometres. Every ascent the barometer cannot prove on its
  // own (`evaluateAscent`) must show a station in front of it, a straight line at
  // full resolution and a machine-constant speed — else it is not a ride but a
  // person, and the interval becomes OTHER.
  _ascendingCableGate(iv, accepted);
  _mergeAdjacent(iv, accepted);

  // 2. validity: short/shallow runs and lifts become OTHER (vehicle intervals never RUN)
  for (final r in iv) {
    if (r.vehicle && r.kind == SegmentKind.run) r.kind = SegmentKind.other;
    // The ski bus: skier speed on a graded road with hairpins. Neither the run
    // rules nor the cable rules separate it, so it gets its own answer.
    if (r.kind == SegmentKind.run && _isRoadDescent(accepted, r)) {
      r.kind = SegmentKind.other;
      r.vehicle = true;
    }
    if (r.kind == SegmentKind.run || r.kind == SegmentKind.lift) {
      final (sAlt, eAlt) = _endAlts(accepted, r.startTs, r.endTs);
      // A cable-confirmed ride only has to *change* altitude by liftMinGainM:
      // a gondola into the valley loses height instead of gaining it, and
      // without this it would fall into the OTHER bucket and take its
      // kilometres with it. Its `dropM` stays 0, so ascentM stays honest.
      final gain = eAlt == null || sAlt == null ? null : (r.cable ? (eAlt - sAlt).abs() : eAlt - sAlt);
      final ok = r.kind == SegmentKind.run
          ? r.durationMs >= TrackingConfig.runMinDurationS * 1000 && sAlt != null && eAlt != null && sAlt - eAlt >= TrackingConfig.runMinDropM
          : r.durationMs >= TrackingConfig.liftMinDurationS * 1000 && gain != null && gain >= TrackingConfig.liftMinGainM;
      if (!ok) r.kind = SegmentKind.other;
    }
  }
  _mergeAdjacent(iv, accepted);

  // 3. runs separated by a short stop/other (< 45 s) merge into one run
  var merged = true;
  while (merged) {
    merged = false;
    for (var i = 1; i + 1 < iv.length; i++) {
      final a = iv[i - 1], m = iv[i], b = iv[i + 1];
      if (a.kind == SegmentKind.run && b.kind == SegmentKind.run &&
          (m.kind == SegmentKind.stop || m.kind == SegmentKind.other) && m.durationMs < TrackingConfig.runStopAbsorbS * 1000) {
        a.endTs = b.endTs;
        iv.removeRange(i, i + 2);
        merged = true;
        break;
      }
    }
  }

  // 3b. snap run/lift starts to the altitude turning point: a run that follows a
  // lift is detected ~10 s after the descent began; move the boundary to the
  // highest point within the 60 s before it (lowest point for lifts).
  for (var i = 1; i < iv.length; i++) {
    final cur = iv[i], prev = iv[i - 1];
    final direct = (cur.kind == SegmentKind.run && prev.kind == SegmentKind.lift) ||
        (cur.kind == SegmentKind.lift && prev.kind == SegmentKind.run);
    if (!direct) continue;
    // A cable ride that goes *down* has no turning point at its start (the
    // skier was already descending), so there is nothing to snap to — and none
    // at its *end* either, which is the mirror case: snapping the boundary
    // behind a descending ride to the highest point of the previous 60 s moves a
    // minute of the carved ride back into the run and hands the run the cabin's
    // speed. Both sides need the guard.
    if (cur.kind == SegmentKind.lift && cur.cable && _descends(accepted, cur)) continue;
    if (prev.kind == SegmentKind.lift && prev.cable && _descends(accepted, prev)) continue;
    final wantMax = cur.kind == SegmentKind.run;
    int? bestTs;
    double? best;
    for (var k = lowerBoundTs(accepted, cur.startTs - 60000); k < accepted.length; k++) {
      final p = accepted[k];
      if (p.ts > cur.startTs + 10000) break;
      if (p.ts <= prev.startTs) continue;
      final a = p.fusedAltM!;
      if (best == null || (wantMax ? a > best : a < best)) {
        best = a;
        bestTs = p.ts;
      }
    }
    if (bestTs != null && bestTs != cur.startTs) {
      cur.startTs = bestTs;
      prev.endTs = bestTs;
    }
  }
  iv.removeWhere((r) => r.durationMs <= 0);

  // 4. stats
  final out = <Segment>[];
  var run = firstRunNumber - 1;
  for (var i = 0; i < iv.length; i++) {
    final r = iv[i];
    final seg = _stats(r, accepted, dayId: dayId, idx: firstIdx + i, runNumber: r.kind == SegmentKind.run ? ++run : null);
    out.add(seg);
  }
  return out;
}

/// One tick of OTHER between two rides in the same direction is not a second
/// ride — it is the moment a chairlift dipped and the rolling window lost its
/// grip. Swallows slivers up to [TrackingConfig.liftSliverMergeS].
void _absorbLiftSlivers(List<RawInterval> iv, List<TrackPoint> accepted) {
  var again = true;
  while (again) {
    again = false;
    for (var i = 1; i + 1 < iv.length; i++) {
      final a = iv[i - 1], m = iv[i], b = iv[i + 1];
      if (a.kind != SegmentKind.lift || b.kind != SegmentKind.lift) continue;
      if (m.kind != SegmentKind.other && m.kind != SegmentKind.stop) continue;
      if (m.durationMs > TrackingConfig.liftSliverMergeS * 1000) continue;
      if (_oppositeRides(accepted, a, b)) continue;
      a.endTs = b.endTs;
      a.cable = a.cable || b.cable;
      iv.removeRange(i, i + 2);
      again = true;
      break;
    }
  }
}

/// Demotes every ascending LIFT that rests on the 45 s cable signature alone and
/// cannot back it up at full resolution (see [evaluateAscent]).
///
/// Only ever demotes, and only ever a LIFT that
///
/// * is **ascending** by at least [TrackingConfig.liftMinGainM] — a ride down is
///   not decided here (and not at all, see [TrackingConfig.descentRidesEnabled]);
/// * and that **neither barometric rule proves** ([AscentEvidence.baroProven]):
///   a chairlift, gondola or funicular climbing at
///   [TrackingConfig.liftEnterVz30Ms] over half a minute, or
///   [TrackingConfig.liftEnterGained60M] over a minute, is untouched — the
///   segmenter would have opened it with no cable signature at all, so there is
///   nothing here to second-guess.
///
/// What is left is the slow rope — and the skater who looks like one.
void _ascendingCableGate(List<RawInterval> iv, List<TrackPoint> accepted) {
  if (accepted.isEmpty) return;
  for (final r in iv) {
    if (r.kind != SegmentKind.lift) continue;
    final (sAlt, eAlt) = _endAlts(accepted, r.startTs, r.endTs);
    if (sAlt == null || eAlt == null || eAlt - sAlt < TrackingConfig.liftMinGainM) continue;
    final ev = evaluateAscent(accepted, r.startTs, r.endTs,
        from: lowerBoundTs(accepted, r.startTs - TrackingConfig.cableAscentStationLookbackS * 1000));
    if (ev.confirmed) continue;
    r.kind = SegmentKind.other;
    r.cable = false;
  }
}

/// Rewrites descents that carry the full descending-cable evidence as one cable
/// LIFT, pulling the start back to the station the cabin left.
///
/// Candidates are **station pairs**, not segmenter intervals: a 30 s stop at the
/// top station is shorter than [TrackingConfig.runStopAbsorbS], so the segmenter
/// keeps the valley ride inside the RUN in front of it and there is no interval
/// to test. A pair may span a mid-station stop and a five-minute GPS dropout —
/// the rigidity tests run over the whole span, so a real run inside it breaks
/// them.
void _descendingCablePass(List<RawInterval> iv, List<TrackPoint> accepted) {
  const look = TrackingConfig.descentStationLookbackS * 1000;
  if (iv.isEmpty || accepted.isEmpty) return;
  final st = standstills(accepted);
  final rides = <DescentEvidence>[];
  var i = 0;
  while (i + 1 < st.length) {
    DescentEvidence? best;
    var bestJ = -1;
    // At most three stations ahead: one ride may contain a mid-station, not a day.
    for (var j = i + 1; j < st.length && j <= i + 3; j++) {
      final a = st[i].$2, b = st[j].$1;
      final dur = b - a;
      if (dur > TrackingConfig.descentMaxRideS * 1000) break;
      if (dur < TrackingConfig.descentMinDurationS * 1000) continue;
      final (sAlt, eAlt) = _endAlts(accepted, a, b);
      if (sAlt == null || eAlt == null || sAlt - eAlt < TrackingConfig.descentMinDropM) continue;
      final ev = evaluateDescent(accepted, a, b, from: lowerBoundTs(accepted, a - look));
      if (ev.ride) {
        best = ev;
        bestJ = j;
      }
    }
    if (best == null) {
      i++;
      continue;
    }
    rides.add(best);
    i = bestJ;
  }
  // A mid-station is part of one ride, not two: two rides that both go down and
  // are separated only by a station dwell are joined. Judging them as one window
  // instead would mean letting the dwell's standstill into the speed spread,
  // which is exactly the evidence that keeps a braking skier out.
  final spans = <(int, int)>[];
  for (final ev in rides) {
    if (spans.isNotEmpty && ev.startTs - spans.last.$2 <= TrackingConfig.descentMidStationS * 1000) {
      spans[spans.length - 1] = (spans.last.$1, ev.endTs);
    } else {
      spans.add((ev.startTs, ev.endTs));
    }
  }
  for (final sp in spans) {
    _carveRide(iv, sp.$1, sp.$2, stationAfter: true);
  }
}

/// Cuts `[ev.startTs, ev.endTs]` out of the interval list and puts one cable
/// LIFT there; whatever the ride overlapped keeps its kind on either side.
void _carveRide(List<RawInterval> iv, int a, int b, {required bool stationAfter}) {
  var firstIdx = -1, lastIdx = -1;
  for (var k = 0; k < iv.length; k++) {
    if (iv[k].endTs <= a || iv[k].startTs >= b) continue;
    if (firstIdx < 0) firstIdx = k;
    lastIdx = k;
  }
  if (firstIdx < 0) return;
  final first = iv[firstIdx], last = iv[lastIdx];
  final head = first.startTs < a
      ? RawInterval(kind: first.kind, startTs: first.startTs, endTs: a, vehicle: first.vehicle, cable: first.cable)
      : null;
  // The ride ends at the standstill it reached, so a short remainder *is* that
  // standstill — calling it OTHER would leave a spurious sliver in the day.
  final tailShort = last.endTs - b <= TrackingConfig.runStopAbsorbS * 1000;
  final tail = last.endTs > b
      ? RawInterval(
          kind: stationAfter && tailShort ? SegmentKind.stop : last.kind,
          startTs: b,
          endTs: last.endTs,
          vehicle: last.vehicle,
          cable: stationAfter && tailShort ? false : last.cable)
      : null;
  iv.replaceRange(firstIdx, lastIdx + 1, [
    ?head,
    RawInterval(kind: SegmentKind.lift, startTs: a, endTs: b, cable: true),
    ?tail,
  ]);
}

/// The ski bus: a descent at cruising speed on a graded road with hairpins.
///
/// [minDurationS] and [minHairpins] are only ever *loosened*, and only by the
/// engine's live top-speed hold ([TrackingConfig.roadLiveMinDurationS],
/// [TrackingConfig.roadLiveMinHairpins]): a bus that is already fast, already
/// shallow, already driving twice its straight line and has already reversed
/// once holds its peaks back. Nothing is reclassified early — only the live
/// number waits, and a wait costs nothing while a wrong number costs trust.
///
/// All five conditions together — a fast, long, shallow descent whose driven
/// line is at least twice its straight line and that reverses direction twice
/// over hundreds of metres. A piste has none of the last three: skiers traverse,
/// but a traverse reverses over 20–60 m, not over 400.
bool isRoadDescent(List<TrackPoint> accepted, int startTs, int endTs,
        {int minDurationS = TrackingConfig.roadMinDurationS, int minHairpins = TrackingConfig.roadMinHairpins}) =>
    _isRoadDescent(accepted, RawInterval(kind: SegmentKind.run, startTs: startTs, endTs: endTs),
        minDurationS: minDurationS, minHairpins: minHairpins);

bool _isRoadDescent(List<TrackPoint> accepted, RawInterval r,
    {int minDurationS = TrackingConfig.roadMinDurationS, int minHairpins = TrackingConfig.roadMinHairpins}) {
  if (r.durationMs < minDurationS * 1000) return false;
  final pts = <TrackPoint>[];
  for (var k = lowerBoundTs(accepted, r.startTs); k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts > r.endTs) break;
    if (p.hasPosition) pts.add(p);
  }
  if (pts.length < 60) return false;
  var path = 0.0, vSum = 0.0;
  var vN = 0;
  final cum = <double>[0];
  for (var k = 1; k < pts.length; k++) {
    path += haversineM(pts[k - 1].lat!, pts[k - 1].lon!, pts[k].lat!, pts[k].lon!);
    cum.add(path);
  }
  for (final p in pts) {
    final v = p.speedMs;
    if (v != null && v >= 0 && (p.speedAccMs ?? 99) <= TrackingConfig.speedTrustedMaxAccMs) {
      vSum += v;
      vN++;
    }
  }
  if (vN < 30 || path <= 0) return false;
  if (vSum / vN < TrackingConfig.roadMinSpeedMs) return false;
  final drop = (pts.first.fusedAltM ?? 0) - (pts.last.fusedAltM ?? 0);
  if (drop <= 0) return false;
  if (drop / path * 100 > TrackingConfig.roadMaxGradientPct) return false;
  final chord = haversineM(pts.first.lat!, pts.first.lon!, pts.last.lat!, pts.last.lon!);
  if (chord / path > TrackingConfig.roadMaxChordOverPath) return false;
  // Bearings averaged over 15 s: a skier's turns average out to the fall line,
  // a road's hairpins do not.
  const step = 15;
  final bear = <(double, double)>[];
  for (var k = 0; k + step < pts.length; k += step) {
    final a = pts[k], b = pts[k + step];
    final dx = (b.lon! - a.lon!) * math.cos(a.lat! * math.pi / 180), dy = b.lat! - a.lat!;
    if (dx == 0 && dy == 0) continue;
    bear.add((cum[k], math.atan2(dy, dx) * 180 / math.pi));
  }
  var hairpins = 0, ref = 0;
  for (var k = 1; k < bear.length; k++) {
    final dp = bear[k].$1 - bear[ref].$1;
    if (dp < TrackingConfig.roadHairpinMinPathM) continue;
    var db = (bear[k].$2 - bear[ref].$2).abs() % 360;
    if (db > 180) db = 360 - db;
    if (db >= TrackingConfig.roadHairpinMinTurnDeg) {
      hairpins++;
      ref = k;
    } else if (dp > TrackingConfig.roadHairpinMinPathM * 3) {
      ref = k;
    }
  }
  return hairpins >= minHairpins;
}

/// Index of the first point with `ts >= tsMs` in a list sorted by ts.
int lowerBoundTs(List<TrackPoint> sorted, int tsMs) {
  var lo = 0, hi = sorted.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].ts < tsMs) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

void _mergeAdjacent(List<RawInterval> iv, List<TrackPoint> accepted) {
  for (var i = iv.length - 1; i >= 1; i--) {
    if (iv[i].kind == iv[i - 1].kind && iv[i].vehicle == iv[i - 1].vehicle && !_oppositeRides(accepted, iv[i - 1], iv[i])) {
      iv[i - 1].endTs = iv[i].endTs;
      iv[i - 1].cable = iv[i - 1].cable || iv[i].cable;
      iv.removeAt(i);
    }
  }
}

/// Two rides in opposite directions are two rides. Riding up and straight back
/// down (a gondola that is also the way home) would otherwise merge into one
/// interval whose net altitude change is zero — and the validity rule below
/// would throw that interval, and its kilometres, away.
bool _oppositeRides(List<TrackPoint> accepted, RawInterval a, RawInterval b) {
  if (a.kind != SegmentKind.lift) return false;
  final (sa, ea) = _endAlts(accepted, a.startTs, a.endTs);
  final (sb, eb) = _endAlts(accepted, b.startTs, b.endTs);
  if (sa == null || ea == null || sb == null || eb == null) return false;
  final da = ea - sa, db = eb - sb;
  return da * db < 0 && da.abs() >= TrackingConfig.liftMinGainM && db.abs() >= TrackingConfig.liftMinGainM;
}

/// True when the interval ends lower than it started (a ride into the valley).
bool _descends(List<TrackPoint> accepted, RawInterval r) {
  final (sAlt, eAlt) = _endAlts(accepted, r.startTs, r.endTs);
  return sAlt != null && eAlt != null && eAlt < sAlt;
}

(double?, double?) _endAlts(List<TrackPoint> accepted, int startTs, int endTs) {
  double? s, e;
  for (var k = lowerBoundTs(accepted, startTs); k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts > endTs) break;
    s ??= p.fusedAltM;
    e = p.fusedAltM;
  }
  return (s, e);
}

Segment _stats(RawInterval r, List<TrackPoint> accepted, {required String dayId, required int idx, int? runNumber}) {
  TrackPoint? prev;
  double dist = 0, horiz = 0;
  int moving = 0;
  double? sAlt, eAlt;
  int? sTs, eTs;
  final maxT = MaxSpeedTracker();
  // steepest 100 m window
  final cumD = <double>[];
  final alts = <double>[];
  double? steepest;
  for (var k = lowerBoundTs(accepted, r.startTs); k < accepted.length; k++) {
    final p = accepted[k];
    if (p.ts > r.endTs) break;
    sAlt ??= p.fusedAltM;
    sTs ??= p.ts;
    eAlt = p.fusedAltM;
    eTs = p.ts;
    final trusted = p.speedMs != null && p.speedMs! >= 0 && (p.speedAccMs ?? 99) <= TrackingConfig.speedTrustedMaxAccMs;
    var v = trusted ? p.speedMs! : 0.0;
    if (prev != null && prev.hasPosition && p.hasPosition) {
      final dt = (p.ts - prev.ts) / 1000;
      final d = haversineM(prev.lat!, prev.lon!, p.lat!, p.lon!);
      if (!trusted && dt > 0) v = d / dt;
      if (v >= TrackingConfig.distanceMinSpeedMs && dt <= TrackingConfig.distanceMaxDtS) {
        dist += d;
        moving += (dt * 1000).round();
      }
      horiz += d;
      cumD.add(horiz);
      alts.add(p.fusedAltM ?? alts.lastOrNull ?? 0);
      // shortest trailing window of ≥ 100 m: walk back while the window is short
      var j = cumD.length - 1;
      while (j > 0 && horiz - cumD[j - 1] < 100) {
        j--;
      }
      if (j > 0 && horiz - cumD[j - 1] >= 100) {
        final i0 = j - 1;
        final g = (alts[i0] - alts.last) / (horiz - cumD[i0]) * 100;
        if (steepest == null || g > steepest) steepest = g;
      }
    }
    if (r.kind == SegmentKind.run && p.speedMs != null && p.speedMs! >= 0 &&
        (p.speedAccMs ?? 99) <= TrackingConfig.maxCandidateSpeedAccMs && (p.hAccM ?? 99) <= TrackingConfig.maxCandidateHAccM) {
      maxT.offer(p.speedMs!, p.ts);
    }
    prev = p;
  }
  final drop = switch (r.kind) {
    SegmentKind.run => ((sAlt ?? 0) - (eAlt ?? 0)).clamp(0, double.infinity).toDouble(),
    SegmentKind.lift => ((eAlt ?? 0) - (sAlt ?? 0)).clamp(0, double.infinity).toDouble(),
    _ => 0.0,
  };
  return Segment(
    id: '$dayId-$idx',
    dayId: dayId,
    kind: r.kind,
    idx: idx,
    runNumber: runNumber,
    startTs: r.startTs,
    endTs: r.endTs,
    startAltM: sAlt ?? 0,
    endAltM: eAlt ?? 0,
    dropM: drop,
    distanceM: dist,
    movingMs: moving,
    maxSpeedMs: maxT.max,
    maxSpeedAtTs: maxT.maxTs,
    avgSpeedMs: moving > 0 ? dist / (moving / 1000) : 0,
    avgGradientPct: horiz > 0 ? drop / horiz * 100 : 0,
    steepest100mPct: r.kind == SegmentKind.run ? steepest : null,
    startPointTs: sTs,
    endPointTs: eTs,
    flags: r.vehicle ? 1 : 0,
  );
}

/// Day aggregates from finalized segments and all points (offline path).
DayStats computeDayStats(List<Segment> segments, List<TrackPoint> points, {required bool hasBarometer}) =>
    dayStatsFrom(segments, PointAggregate.of(points), hasBarometer: hasBarometer);

/// The point-derived part of [DayStats], maintained incrementally by the live
/// engine so a recompute never walks the whole day again.
class PointAggregate {
  PointAggregate();

  factory PointAggregate.of(Iterable<TrackPoint> points) {
    final a = PointAggregate();
    for (final p in points) {
      a.add(p);
    }
    return a;
  }

  int accepted = 0, rejected = 0;
  double? maxAltM, minAltM;
  int hrSum = 0, hrN = 0, hrMax = 0;
  int? firstTs, lastTs;

  int get elapsedMs => firstTs == null ? 0 : lastTs! - firstTs!;

  void add(TrackPoint p) {
    firstTs ??= p.ts;
    lastTs = p.ts;
    if (p.hasPosition) {
      if (p.accepted) {
        accepted++;
      } else {
        rejected++;
      }
    }
    final a = p.fusedAltM;
    if (a != null && p.accepted) {
      maxAltM = maxAltM == null ? a : math.max(maxAltM!, a);
      minAltM = minAltM == null ? a : math.min(minAltM!, a);
    }
    final hr = p.heartRateBpm;
    if (hr != null && hr > 0) {
      hrSum += hr;
      hrN++;
      if (hr > hrMax) hrMax = hr;
    }
  }
}

/// Segment totals + the point aggregate → [DayStats]. O(segments).
DayStats dayStatsFrom(List<Segment> segments, PointAggregate agg, {required bool hasBarometer}) {
  int ski = 0, lift = 0, pause = 0, loss = 0, other = 0, runs = 0, lifts = 0;
  double drop = 0, ascent = 0, skiD = 0, liftD = 0, totalD = 0, maxV = 0, runMoving = 0;
  String? maxId, longestId;
  double longest = -1;
  bool vehicle = false;
  for (final s in segments) {
    totalD += s.distanceM;
    switch (s.kind) {
      case SegmentKind.run:
        ski += s.durationMs;
        runs++;
        drop += s.dropM;
        skiD += s.distanceM;
        runMoving += s.movingMs;
        if (s.maxSpeedMs > maxV) {
          maxV = s.maxSpeedMs;
          maxId = s.id;
        }
        if (s.dropM > longest) {
          longest = s.dropM;
          longestId = s.id;
        }
      case SegmentKind.lift:
        lift += s.durationMs;
        lifts++;
        ascent += s.dropM;
        liftD += s.distanceM;
      case SegmentKind.stop:
        pause += s.durationMs;
      case SegmentKind.other:
        other += s.durationMs;
        if (s.isVehicle) vehicle = true;
      case SegmentKind.signalLoss:
        loss += s.durationMs;
    }
  }
  return DayStats(
    elapsedMs: agg.elapsedMs, skiMs: ski, liftMs: lift, pauseMs: pause, signalLossMs: loss, otherMs: other,
    runCount: runs, liftCount: lifts, dropM: drop, ascentM: ascent, skiDistanceM: skiD, liftDistanceM: liftD,
    totalDistanceM: totalD, maxSpeedMs: maxV, avgSkiSpeedMs: runMoving > 0 ? skiD / (runMoving / 1000) : 0,
    maxAltM: agg.maxAltM, minAltM: agg.minAltM, maxSpeedSegmentId: maxId, longestRunSegmentId: longestId,
    acceptedFixes: agg.accepted, rejectedFixes: agg.rejected, hasBarometer: hasBarometer, vehicleFlag: vehicle,
    avgHeartRateBpm: agg.hrN > 0 ? (agg.hrSum / agg.hrN).round() : null, maxHeartRateBpm: agg.hrN > 0 ? agg.hrMax : null,
  );
}
