import 'package:latlong2/latlong.dart';

import '../../core/core.dart';

/// Which line style a point contributes to. Stops and unknown are not drawn.
enum TrackLineKind { run, lift }

/// One continuous polyline of a single kind.
class TrackLine {
  const TrackLine(this.kind, this.points);
  final TrackLineKind kind;
  final List<LatLng> points;
}

/// Pure geometry helpers shared by the live map, the detail map and the thumbnail.
class TrackGeometry {
  const TrackGeometry._();

  /// Points with a position that a consumer may draw.
  static List<TrackPoint> drawable(List<TrackPoint> points) => points.where((p) => p.accepted && p.hasPosition).toList();

  /// Classifies a point: its own state wins; unknown/other falls back to the
  /// segment covering its timestamp (lets recomputed days render consistently).
  static TrackLineKind? kindOf(TrackPoint p, List<Segment> segments) {
    switch (p.state) {
      case MotionState.run:
        return TrackLineKind.run;
      case MotionState.lift:
        return TrackLineKind.lift;
      case MotionState.stop:
        return null;
      case MotionState.unknown:
      case MotionState.other:
        for (final s in segments) {
          if (p.ts >= s.startTs && p.ts <= s.endTs) {
            if (s.kind == SegmentKind.run) return TrackLineKind.run;
            if (s.kind == SegmentKind.lift) return TrackLineKind.lift;
            return null;
          }
        }
        return null;
    }
  }

  /// Splits the track into run / lift polylines. A new line starts on every
  /// kind change and on gaps longer than [gapMs] (signal loss is not bridged).
  static List<TrackLine> split(List<TrackPoint> points, List<Segment> segments, {int gapMs = 120000}) {
    final out = <TrackLine>[];
    TrackLineKind? current;
    var buf = <LatLng>[];
    int? lastTs;

    void flush() {
      if (current != null && buf.length >= 2) out.add(TrackLine(current!, buf));
      buf = <LatLng>[];
    }

    for (final p in points) {
      if (!p.accepted || !p.hasPosition) continue;
      final k = kindOf(p, segments);
      final gap = lastTs != null && p.ts - lastTs! > gapMs;
      if (k != current || gap) {
        flush();
        current = k;
      }
      if (k != null) buf.add(LatLng(p.lat!, p.lon!));
      lastTs = p.ts;
    }
    flush();
    return out;
  }

  static LatLng? first(List<TrackPoint> points) {
    for (final p in points) {
      if (p.accepted && p.hasPosition) return LatLng(p.lat!, p.lon!);
    }
    return null;
  }

  static LatLng? last(List<TrackPoint> points) {
    for (var i = points.length - 1; i >= 0; i--) {
      final p = points[i];
      if (p.accepted && p.hasPosition) return LatLng(p.lat!, p.lon!);
    }
    return null;
  }

  /// Nearest drawable point to [ts] (points are in ts order; binary search).
  static TrackPoint? nearest(List<TrackPoint> points, int ts) {
    if (points.isEmpty) return null;
    var lo = 0, hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (points[mid].ts < ts) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    TrackPoint? best;
    var bestD = 1 << 62;
    for (var i = lo - 3; i <= lo + 3; i++) {
      if (i < 0 || i >= points.length) continue;
      final p = points[i];
      if (!p.accepted || !p.hasPosition) continue;
      final d = (p.ts - ts).abs();
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  /// Min/max corners of all drawable points, or null when fewer than one.
  static (LatLng, LatLng)? bounds(List<TrackPoint> points) {
    double? minLat, maxLat, minLon, maxLon;
    for (final p in points) {
      if (!p.accepted || !p.hasPosition) continue;
      minLat = minLat == null ? p.lat! : (p.lat! < minLat ? p.lat! : minLat);
      maxLat = maxLat == null ? p.lat! : (p.lat! > maxLat ? p.lat! : maxLat);
      minLon = minLon == null ? p.lon! : (p.lon! < minLon ? p.lon! : minLon);
      maxLon = maxLon == null ? p.lon! : (p.lon! > maxLon ? p.lon! : maxLon);
    }
    if (minLat == null) return null;
    return (LatLng(minLat, minLon!), LatLng(maxLat!, maxLon!));
  }

  static int drawableCount(List<TrackPoint> points) {
    var n = 0;
    for (final p in points) {
      if (p.accepted && p.hasPosition) n++;
    }
    return n;
  }
}
