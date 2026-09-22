import 'dart:math' as math;

import '../core/core.dart';
import 'segmenter.dart';
import 'speed.dart';

/// Applies validity + merge rules to raw intervals and computes per-segment stats
/// from the accepted points. Deterministic: same inputs → same segments.
List<Segment> finalizeSegments(List<RawInterval> raw, List<TrackPoint> points, {required String dayId}) {
  if (raw.isEmpty) return const [];
  // 1. copy + sort + merge adjacent same kind
  final iv = raw.map((r) => RawInterval(kind: r.kind, startTs: r.startTs, endTs: r.endTs, vehicle: r.vehicle)).toList()
    ..sort((a, b) => a.startTs.compareTo(b.startTs));
  for (var i = 1; i < iv.length; i++) {
    if (iv[i].startTs < iv[i - 1].endTs) iv[i].startTs = iv[i - 1].endTs;
  }
  _mergeAdjacent(iv);

  // 2. validity: short/shallow runs and lifts become OTHER (vehicle intervals never RUN)
  final accepted = points.where((p) => p.accepted && p.fusedAltM != null).toList();
  for (final r in iv) {
    if (r.vehicle && r.kind == SegmentKind.run) r.kind = SegmentKind.other;
    if (r.kind == SegmentKind.run || r.kind == SegmentKind.lift) {
      final (sAlt, eAlt) = _endAlts(accepted, r.startTs, r.endTs);
      final ok = r.kind == SegmentKind.run
          ? r.durationMs >= TrackingConfig.runMinDurationS * 1000 && sAlt != null && eAlt != null && sAlt - eAlt >= TrackingConfig.runMinDropM
          : r.durationMs >= TrackingConfig.liftMinDurationS * 1000 && sAlt != null && eAlt != null && eAlt - sAlt >= TrackingConfig.liftMinGainM;
      if (!ok) r.kind = SegmentKind.other;
    }
  }
  _mergeAdjacent(iv);

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
    final wantMax = cur.kind == SegmentKind.run;
    int? bestTs;
    double? best;
    for (final p in accepted) {
      if (p.ts < cur.startTs - 60000) continue;
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
  var run = 0;
  for (var i = 0; i < iv.length; i++) {
    final r = iv[i];
    final seg = _stats(r, accepted, dayId: dayId, idx: i, runNumber: r.kind == SegmentKind.run ? ++run : null);
    out.add(seg);
  }
  return out;
}

void _mergeAdjacent(List<RawInterval> iv) {
  for (var i = iv.length - 1; i >= 1; i--) {
    if (iv[i].kind == iv[i - 1].kind && iv[i].vehicle == iv[i - 1].vehicle) {
      iv[i - 1].endTs = iv[i].endTs;
      iv.removeAt(i);
    }
  }
}

(double?, double?) _endAlts(List<TrackPoint> accepted, int startTs, int endTs) {
  double? s, e;
  for (final p in accepted) {
    if (p.ts < startTs) continue;
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
  for (final p in accepted) {
    if (p.ts < r.startTs) continue;
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
      // slide window
      var j = cumD.length - 1;
      while (j > 0 && horiz - cumD[j - 1] < 100) {
        j--;
      }
      if (j < cumD.length - 1 && horiz - cumD[j] >= 100) {
        final g = (alts[j] - alts.last) / (horiz - cumD[j]) * 100;
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

/// Day aggregates from finalized segments and all points.
DayStats computeDayStats(List<Segment> segments, List<TrackPoint> points, {required bool hasBarometer}) {
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
  double? maxAlt, minAlt;
  int acc = 0, rej = 0;
  int hrSum = 0, hrN = 0, hrMax = 0;
  for (final p in points) {
    if (p.hasPosition) {
      if (p.accepted) {
        acc++;
      } else {
        rej++;
      }
    }
    final a = p.fusedAltM;
    if (a != null && p.accepted) {
      maxAlt = maxAlt == null ? a : math.max(maxAlt, a);
      minAlt = minAlt == null ? a : math.min(minAlt, a);
    }
    final hr = p.heartRateBpm;
    if (hr != null && hr > 0) {
      hrSum += hr;
      hrN++;
      if (hr > hrMax) hrMax = hr;
    }
  }
  final elapsed = points.isEmpty ? 0 : points.last.ts - points.first.ts;
  return DayStats(
    elapsedMs: elapsed, skiMs: ski, liftMs: lift, pauseMs: pause, signalLossMs: loss, otherMs: other,
    runCount: runs, liftCount: lifts, dropM: drop, ascentM: ascent, skiDistanceM: skiD, liftDistanceM: liftD,
    totalDistanceM: totalD, maxSpeedMs: maxV, avgSkiSpeedMs: runMoving > 0 ? skiD / (runMoving / 1000) : 0,
    maxAltM: maxAlt, minAltM: minAlt, maxSpeedSegmentId: maxId, longestRunSegmentId: longestId,
    acceptedFixes: acc, rejectedFixes: rej, hasBarometer: hasBarometer, vehicleFlag: vehicle,
    avgHeartRateBpm: hrN > 0 ? (hrSum / hrN).round() : null, maxHeartRateBpm: hrN > 0 ? hrMax : null,
  );
}
