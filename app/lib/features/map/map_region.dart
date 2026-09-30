import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/painting.dart' show EdgeInsets;

import '../../core/core.dart';

/// A geographic rectangle in the Web-Mercator sense Apple Maps renders:
/// longitude is linear in x, Mercator-y is linear in y. The snapshot for a
/// region whose Mercator aspect equals the image aspect is not re-fitted by
/// MapKit, so [project] maps a coordinate onto the image 1:1.
class MapRegion {
  const MapRegion({required this.north, required this.south, required this.west, required this.east});

  final double north, south, west, east;

  /// Centre latitude as MapKit reads it (centre ± span / 2).
  double get lat => (north + south) / 2;
  double get lon => (west + east) / 2;
  double get latSpan => north - south;
  double get lonSpan => east - west;

  /// Metres covered east–west / north–south at the centre latitude.
  double get widthM => lonSpan * MapGeo.metresPerDegLon(lat);
  double get heightM => latSpan * MapGeo.metresPerDegLat;

  /// `(lat, lon)` → unit coordinates on the image (0,0 top-left, 1,1 bottom-right).
  Offset project(double latitude, double longitude) {
    final top = MapGeo.mercY(north), bottom = MapGeo.mercY(south);
    return Offset((longitude - west) / lonSpan, (top - MapGeo.mercY(latitude)) / (top - bottom));
  }

  Map<String, Object?> toJson() => {'north': north, 'south': south, 'west': west, 'east': east};

  static MapRegion? fromJson(Object? j) {
    if (j is! Map) return null;
    final n = (j['north'] as num?)?.toDouble(), s = (j['south'] as num?)?.toDouble();
    final w = (j['west'] as num?)?.toDouble(), e = (j['east'] as num?)?.toDouble();
    if (n == null || s == null || w == null || e == null || n <= s || e <= w) return null;
    return MapRegion(north: n, south: s, west: w, east: e);
  }

  @override
  String toString() => 'MapRegion(n $north, s $south, w $west, e $east)';
}

/// Plain `(south, west, north, east)` bounds in degrees.
typedef GeoBounds = ({double south, double west, double north, double east});

/// The stored frame of a background snapshot: region + the image size in pt.
/// Written as `<id>_hero.json` next to the PNG so the overlay never has to
/// guess how the image was framed.
class MapFrame {
  const MapFrame({required this.region, required this.size});
  final MapRegion region;
  final Size size;

  String encode() => jsonEncode({'region': region.toJson(), 'width': size.width, 'height': size.height});

  static MapFrame? decode(String source) {
    try {
      final j = jsonDecode(source);
      if (j is! Map) return null;
      final r = MapRegion.fromJson(j['region']);
      final w = (j['width'] as num?)?.toDouble(), h = (j['height'] as num?)?.toDouble();
      if (r == null || w == null || h == null || w <= 0 || h <= 0) return null;
      return MapFrame(region: r, size: Size(w, h));
    } on FormatException {
      return null;
    }
  }
}

/// Geometry for static map snapshots: bounds, padding, Mercator fit and the
/// route simplification the channel receives.
class MapGeo {
  const MapGeo._();

  static const double metresPerDegLat = 110574;
  static double metresPerDegLon(double lat) => 111320 * math.cos(lat * math.pi / 180);

  /// Default padding: 20 % of the track's span on every side.
  static const double defaultPad = 0.2;
  /// Smallest area a snapshot shows (both axes), so a short day still reads as terrain.
  static const double minSpanM = 1500;
  /// Point budget for the route sent across the channel.
  static const int maxRoutePoints = 500;

  /// Mercator y in degree units (same scale as longitude).
  static double mercY(double lat) {
    final r = lat.clamp(-85.0, 85.0) * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + r / 2)) * 180 / math.pi;
  }

  static double latFromMercY(double y) => (2 * math.atan(math.exp(y * math.pi / 180)) - math.pi / 2) * 180 / math.pi;

  /// Bounds of the accepted positions (every position with [acceptedOnly]
  /// false — what the Tagesbilanz RouteGeometry draws), null below two points.
  static GeoBounds? trackBounds(List<TrackPoint> points, {bool acceptedOnly = true}) {
    double? s, w, n, e;
    var count = 0;
    for (final p in points) {
      if (!p.hasPosition || (acceptedOnly && !p.accepted)) continue;
      count++;
      final lat = p.lat!, lon = p.lon!;
      s = s == null ? lat : math.min(s, lat);
      n = n == null ? lat : math.max(n, lat);
      w = w == null ? lon : math.min(w, lon);
      e = e == null ? lon : math.max(e, lon);
    }
    if (count < 2) return null;
    return (south: s!, west: w!, north: n!, east: e!);
  }

  /// A square around a resort centre: its radius, kept between 1 and 5 km so
  /// umbrella areas do not zoom out to a region map.
  static GeoBounds resortBounds(Resort r) {
    final km = r.radiusKm.clamp(1.0, 5.0);
    final dLat = km * 1000 / metresPerDegLat;
    final dLon = km * 1000 / math.max(1.0, metresPerDegLon(r.lat));
    return (south: r.lat - dLat, west: r.lon - dLon, north: r.lat + dLat, east: r.lon + dLon);
  }

  /// [b] grown by [pad] × span on every side, then widened to [minSpan] metres
  /// per axis around its centre.
  static GeoBounds pad(GeoBounds b, {double pad = defaultPad, double minSpan = minSpanM}) {
    final cLat = (b.north + b.south) / 2, cLon = (b.east + b.west) / 2;
    var latSpan = (b.north - b.south) * (1 + 2 * pad);
    var lonSpan = (b.east - b.west) * (1 + 2 * pad);
    latSpan = math.max(latSpan, minSpan / metresPerDegLat);
    lonSpan = math.max(lonSpan, minSpan / math.max(1.0, metresPerDegLon(cLat)));
    return (south: cLat - latSpan / 2, west: cLon - lonSpan / 2, north: cLat + latSpan / 2, east: cLon + lonSpan / 2);
  }

  /// The region for an image of [size] pt in which [content] fills the
  /// [inset] rectangle as far as the aspect allows, centred in it. The region's
  /// Mercator aspect equals the image aspect, so MapKit renders it unchanged.
  static MapRegion fit(GeoBounds content, Size size, {EdgeInsets inset = EdgeInsets.zero}) {
    final x0 = content.west, x1 = content.east;
    final y0 = mercY(content.south), y1 = mercY(content.north);
    final wx = math.max(x1 - x0, 1e-9), wy = math.max(y1 - y0, 1e-9);
    final availW = math.max(1.0, size.width - inset.horizontal);
    final availH = math.max(1.0, size.height - inset.vertical);
    final k = math.min(availW / wx, availH / wy); // pt per degree unit
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final ix = inset.left + availW / 2, iy = inset.top + availH / 2;
    final west = cx - ix / k;
    final east = west + size.width / k;
    final topY = cy + iy / k;
    final bottomY = topY - size.height / k;
    return MapRegion(north: latFromMercY(topY), south: latFromMercY(bottomY), west: west, east: east);
  }

  /// The accepted positions in order, Douglas–Peucker simplified until at most
  /// [maxPoints] remain (tolerance starts at 2 m and doubles).
  static List<(double, double)> simplifiedRoute(List<TrackPoint> points, {int maxPoints = maxRoutePoints}) {
    final pts = <(double, double)>[
      for (final p in points)
        if (p.accepted && p.hasPosition) (p.lat!, p.lon!),
    ];
    if (pts.length <= maxPoints) return pts;
    final lat0 = pts.first.$1;
    final kx = metresPerDegLon(lat0), ky = metresPerDegLat;
    final xy = [for (final p in pts) Offset(p.$2 * kx, p.$1 * ky)];
    var eps = 2.0;
    var keep = _douglasPeucker(xy, eps);
    while (keep.length > maxPoints && eps < 1e6) {
      eps *= 2;
      keep = _douglasPeucker(xy, eps);
    }
    if (keep.length > maxPoints) {
      // Degenerate input (all points kept at any tolerance): even stride.
      final step = keep.length / maxPoints;
      keep = [for (var i = 0; i < maxPoints; i++) keep[(i * step).floor()]];
    }
    return [for (final i in keep) pts[i]];
  }

  /// Indices kept by Douglas–Peucker at tolerance [eps] (iterative, no recursion).
  static List<int> _douglasPeucker(List<Offset> p, double eps) {
    final n = p.length;
    final keep = List<bool>.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;
    final stack = <(int, int)>[(0, n - 1)];
    final eps2 = eps * eps;
    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();
      if (b <= a + 1) continue;
      final pa = p[a], pb = p[b];
      final d = pb - pa;
      final len2 = d.dx * d.dx + d.dy * d.dy;
      var maxD = -1.0;
      var idx = -1;
      for (var i = a + 1; i < b; i++) {
        final v = p[i] - pa;
        double dist2;
        if (len2 == 0) {
          dist2 = v.dx * v.dx + v.dy * v.dy;
        } else {
          final t = ((v.dx * d.dx + v.dy * d.dy) / len2).clamp(0.0, 1.0);
          final q = v - d * t;
          dist2 = q.dx * q.dx + q.dy * q.dy;
        }
        if (dist2 > maxD) {
          maxD = dist2;
          idx = i;
        }
      }
      if (maxD > eps2) {
        keep[idx] = true;
        stack
          ..add((a, idx))
          ..add((idx, b));
      }
    }
    return [for (var i = 0; i < n; i++) if (keep[i]) i];
  }
}
