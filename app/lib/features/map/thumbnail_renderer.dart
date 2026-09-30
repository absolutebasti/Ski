import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';

import '../../app/theme/surfaces.dart';
import '../../app/theme/tokens.dart';
import '../../core/core.dart';
import '../../platform/map_snapshot.dart';
import 'map_overlay.dart';
import 'map_region.dart';
import 'route_colors.dart';
import 'track_geometry.dart';

/// Paints a day's track without tiles (docs/DESIGN.md §4 "MAP THUMBNAIL"):
/// graphite #101216 ground, a faint contour hatch, the champagne route at
/// 2.5 pt round caps, lift segments dashed liftGrey 1.5, a 3 pt start dot and
/// a 12 % vignette. Used for the 600×400 PNG, the list card and the hero flight.
class TrackThumbnailPainter extends CustomPainter {
  TrackThumbnailPainter({
    required this.points,
    this.segments = const [],
    this.background = graphite,
    this.runColor = Tokens.champagne,
    this.liftColor = Tokens.liftGrey,
    this.padding = 24,
    this.runWidth = 2.5,
    this.glowWidth = 0,
    this.liftWidth = 1.5,
    this.hatch = true,
    this.vignette = true,
  }) : lines = TrackGeometry.split(points, segments);

  /// The dark thumbnail ground — darker than `surface` so the route dominates.
  /// Widgets pass `AppColors.of(context).routeGround` (light: warm paper).
  static const Color graphite = RouteColors.darkGround;
  static const double hatchOpacity = 0.06;
  static const double vignetteOpacity = 0.12;
  static const double startDotRadius = 3;

  final List<TrackPoint> points;
  final List<Segment> segments;
  final List<TrackLine> lines;
  final Color background, runColor, liftColor;
  final double padding, runWidth, glowWidth, liftWidth;
  final bool hatch, vignette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (hatch) _paintHatch(canvas, size);
    final b = TrackGeometry.bounds(points);
    if (b == null || lines.isEmpty) {
      if (vignette) _paintVignette(canvas, size);
      return;
    }

    final project = _Projection(b.$1, b.$2, size, padding);

    final glow = Paint()
      ..color = runColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final run = Paint()
      ..color = runColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = runWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final lift = Paint()
      ..color = liftColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = liftWidth
      ..strokeCap = StrokeCap.round;

    final runPaths = <Path>[];
    final liftPaths = <Path>[];
    for (final l in lines) {
      final path = Path();
      for (var i = 0; i < l.points.length; i++) {
        final o = project(l.points[i].latitude, l.points[i].longitude);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      (l.kind == TrackLineKind.run ? runPaths : liftPaths).add(path);
    }
    if (glowWidth > 0) {
      for (final p in runPaths) {
        canvas.drawPath(p, glow);
      }
    }
    for (final p in runPaths) {
      canvas.drawPath(p, run);
    }
    for (final p in liftPaths) {
      canvas.drawPath(_dashed(p, 6, 5), lift);
    }
    final first = TrackGeometry.first(points);
    if (first != null) {
      final o = project(first.latitude, first.longitude);
      canvas.drawCircle(o, startDotRadius * (runWidth / 2.5), Paint()..color = runColor);
    }
    if (vignette) _paintVignette(canvas, size);
  }

  /// Faint diagonal contour lines — the surface reads as terrain, not as a box.
  void _paintHatch(Canvas canvas, Size size) {
    final p = Paint()
      ..color = liftColor.withValues(alpha: hatchOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final step = math.max(10.0, size.shortestSide / 14);
    for (var i = -size.height; i < size.width + size.height; i += step) {
      final path = Path()..moveTo(i, size.height);
      for (var y = size.height; y >= 0; y -= 8) {
        path.lineTo(i + (size.height - y) * 0.6 + math.sin(y / 34 + i / 90) * 3, y);
      }
      canvas.drawPath(path, p);
    }
  }

  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.78,
          colors: [Colors.transparent, Tokens.ink.withValues(alpha: vignetteOpacity)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(TrackThumbnailPainter old) =>
      !identical(old.points, points) ||
      !identical(old.segments, segments) ||
      old.background != background ||
      old.runColor != runColor ||
      old.runWidth != runWidth ||
      old.padding != padding ||
      old.hatch != hatch ||
      old.vignette != vignette;
}

/// Equirectangular projection with cos(lat) correction, aspect-preserving fit.
class _Projection {
  _Projection(LatLng sw, LatLng ne, Size size, double pad)
      : _cos = math.cos(((sw.latitude + ne.latitude) / 2) * math.pi / 180),
        _minLat = sw.latitude,
        _maxLat = ne.latitude,
        _minLon = sw.longitude,
        _maxLon = ne.longitude {
    final w = (_maxLon - _minLon) * _cos;
    final h = _maxLat - _minLat;
    final availW = math.max(1.0, size.width - 2 * pad);
    final availH = math.max(1.0, size.height - 2 * pad);
    // Degenerate spans (single point / straight N-S track) get a tiny extent.
    final sw_ = w <= 0 ? 1e-6 : w;
    final sh_ = h <= 0 ? 1e-6 : h;
    _scale = math.min(availW / sw_, availH / sh_);
    _dx = pad + (availW - sw_ * _scale) / 2;
    _dy = pad + (availH - sh_ * _scale) / 2;
  }

  final double _cos, _minLat, _maxLat, _minLon, _maxLon;
  late final double _scale, _dx, _dy;

  Offset call(double lat, double lon) => Offset(
        _dx + (lon - _minLon) * _cos * _scale,
        _dy + (_maxLat - lat) * _scale,
      );
}

/// Renders the 600×400 PNG once at End (`days.mapThumbPath`); the list never loads tiles.
class ThumbnailRenderer {
  const ThumbnailRenderer._();

  static const int width = 600;
  static const int height = 400;

  /// The dark ground the PNG is rendered on (same as [TrackThumbnailPainter.graphite]).
  static const Color graphite = TrackThumbnailPainter.graphite;

  /// PNG bytes for [detail] (no I/O). Public so tests and the share card can reuse it.
  /// [ground] / [route] default to the dark pair; pass `c.routeGround` / `c.run`
  /// to render for the light theme.
  static Future<Uint8List> renderPng(DayDetail detail, {int width = width, int height = height, Color? ground, Color? route, Color? lift}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    TrackThumbnailPainter(
      points: detail.points,
      segments: detail.segments,
      background: ground ?? graphite,
      runColor: route ?? Tokens.champagne,
      liftColor: lift ?? Tokens.liftGrey,
    ).paint(canvas, size);
    final image = await recorder.endRecording().toImage(width, height);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('thumbnail encode failed');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Writes `thumbs/<dayId>.png` under the app documents dir (or [dir]) and
  /// returns the absolute path.
  static Future<String> render(DayDetail detail, {Directory? dir, Color? ground, Color? route, Color? lift, String suffix = ''}) async {
    final root = dir ?? await getApplicationDocumentsDirectory();
    final thumbs = Directory('${root.path}/thumbs');
    if (!thumbs.existsSync()) thumbs.createSync(recursive: true);
    final file = File('${thumbs.path}/${detail.day.id}$suffix.png');
    await file.writeAsBytes(await renderPng(detail, ground: ground, route: route, lift: lift), flush: true);
    return file.path;
  }

  /// Light-theme colours for the second thumbnail (AppColors.light has no context at End).
  static const Color lightGround = RouteColors.lightGround;
  static const Color lightRoute = RouteColors.lightRun;
  static const Color lightLift = RouteColors.lightLift;

  /// Writes `<id>.png` (graphite, the stored path) and `<id>_light.png`; the
  /// day card picks the light file when the light theme is active.
  static Future<String> renderBoth(DayDetail detail, {Directory? dir}) async {
    final dark = await render(detail, dir: dir);
    try {
      await render(detail, dir: dir, ground: lightGround, route: lightRoute, lift: lightLift, suffix: '_light');
    } catch (_) {}
    return dark;
  }

  /// Path of the light variant next to a stored dark thumbnail.
  static String lightPathFor(String darkPath) => darkPath.replaceFirst(_png, '_light.png');

  // --------------------------------------------------------------- map images

  // Day card: 2×, route drawn natively, rendered at exactly the card's size
  // (MapCardGeometry: screen − 41 pt wide, 176 pt high at the default text
  // size) so it is shown 1:1 with the Apple wordmark whole in the visible
  // bottom-left corner. The route sits in the top band (MapCardGeometry.routeInset).

  /// Tagesbilanz ground height (the route block is 300 pt high); the width is
  /// the screen's, so the image is shown 1:1 with the Apple wordmark whole in
  /// the bottom-left. No route: the block draws its animated route over it.
  static const double heroHeight = 300;
  static Size heroSizeFor(double screenWidth) => Size(screenWidth, heroHeight);
  /// Same as RoutePainter.defaultInset: the route clears the date plate, which
  /// sits above the wordmark strip. The route block projects through the
  /// stored MapFrame, so any region lines up.
  static const EdgeInsets heroInset = EdgeInsets.fromLTRB(34, 34, 34, 130);

  static const double mapScale = 2;
  static const double mapRouteWidth = 2.5;

  static final RegExp _png = RegExp(r'\.png$');

  /// `<id>_map.png` next to the stored `<id>.png`.
  static String mapPathFor(String basePath) => basePath.replaceFirst(_png, '_map.png');

  /// `<id>_hero.png` next to the stored `<id>.png`.
  static String heroPathFor(String basePath) => basePath.replaceFirst(_png, '_hero.png');

  /// `<id>_hero.json` — the region and size the hero image was rendered for.
  static String heroFramePathFor(String basePath) => basePath.replaceFirst(_png, '_hero.json');

  /// `<id>.png` for a `<id>_map.png` path.
  static String basePathForMap(String mapPath) => mapPath.replaceFirst(RegExp(r'_map\.png$'), '.png');

  /// The area the card image shows: the track's bounds padded 20 % (min
  /// 1.5 km per axis), else the resort centre ± its radius (1–5 km, min
  /// 1.5 km), else null.
  static GeoBounds? mapBounds(DayDetail detail, {Resort? resort}) {
    final track = MapGeo.trackBounds(detail.points);
    if (track != null) return MapGeo.pad(track);
    if (resort != null) return MapGeo.pad(MapGeo.resortBounds(resort), pad: 0);
    return null;
  }

  /// Apple-Maps satellite images for [detail] via [source] (iOS MapKit):
  /// `thumbs/<id>_map.png` for the day card (bounds from [mapBounds], route
  /// simplified to ≤ 500 points and drawn natively) and, when the day has a
  /// track, `thumbs/<id>_hero.png` + `_hero.json` for the Tagesbilanz ground
  /// (bare imagery framed like RoutePainter). Returns the `_map.png` path, or
  /// null when no card image came back (offline, not iOS, no track and no
  /// resort) — the path PNGs from [renderBoth] stay the fallback and the
  /// missing `_map.png` is the retry signal (see MapImages). Never throws.
  ///
  /// [cardSize] / [heroSize] default to this phone's card and hero geometry
  /// (MapCardGeometry.current()).
  static Future<String?> renderMap(
    DayDetail detail, {
    Resort? resort,
    MapSnapshotSource source = const MethodChannelMapSnapshotSource(),
    Directory? dir,
    Size? cardSize,
    Size? heroSize,
  }) async {
    try {
      final bounds = mapBounds(detail, resort: resort);
      if (bounds == null) return null;
      if (cardSize == null || heroSize == null) {
        final (screenWidth, textScaler) = MapCardGeometry.current();
        cardSize ??= MapCardGeometry.imageSize(screenWidth: screenWidth, textScaler: textScaler);
        heroSize ??= heroSizeFor(screenWidth);
      }
      final mapSize = cardSize;
      final cardRegion = MapGeo.fit(bounds, mapSize, inset: MapCardGeometry.routeInset(mapSize));
      final heroContent = MapGeo.trackBounds(detail.points, acceptedOnly: false);
      final heroRegion = heroContent == null ? null : MapGeo.fit(MapGeo.pad(heroContent), heroSize, inset: heroInset);

      MapSnapshotRequest request(MapRegion r, Size size, List<(double, double)> route) => MapSnapshotRequest(
            lat: r.lat,
            lon: r.lon,
            latSpan: r.latSpan,
            lonSpan: r.lonSpan,
            width: size.width,
            height: size.height,
            scale: mapScale,
            route: route,
            routeColor: Tokens.champagne.toARGB32(),
            routeWidth: mapRouteWidth,
          );
      final answers = await Future.wait([
        _safe(source, request(cardRegion, mapSize, MapGeo.simplifiedRoute(detail.points))),
        if (heroRegion != null) _safe(source, request(heroRegion, heroSize, const [])),
      ]);
      final card = answers.first;
      final hero = answers.length > 1 ? answers[1] : null;
      if (card == null) return null;

      final root = dir ?? await getApplicationDocumentsDirectory();
      final thumbs = Directory('${root.path}/thumbs');
      if (!thumbs.existsSync()) thumbs.createSync(recursive: true);
      final base = '${thumbs.path}/${detail.day.id}.png';
      final mapPath = mapPathFor(base);
      await File(mapPath).writeAsBytes(card, flush: true);
      if (hero != null && heroRegion != null) {
        await File(heroPathFor(base)).writeAsBytes(hero, flush: true);
        await File(heroFramePathFor(base)).writeAsString(MapFrame(region: heroRegion, size: heroSize).encode(), flush: true);
      }
      return mapPath;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _safe(MapSnapshotSource source, MapSnapshotRequest r) async {
    try {
      final bytes = await source.snapshot(r);
      return bytes == null || bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// The stored hero frame for a day's `<id>.png`, when image and frame exist.
  static MapFrame? heroFrameFor(String? basePath) {
    if (basePath == null || basePath.isEmpty) return null;
    try {
      final img = File(heroPathFor(basePath));
      final json = File(heroFramePathFor(basePath));
      if (!img.existsSync() || !json.existsSync()) return null;
      return MapFrame.decode(json.readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }
}

/// Same drawing as the PNG, live in a list card (for days without a file yet).
class TrackThumbnail extends StatelessWidget {
  const TrackThumbnail({super.key, required this.points, this.segments = const [], this.aspectRatio = 1.5, this.radius = Tokens.r10, this.padding = 12});
  final List<TrackPoint> points;
  final List<Segment> segments;
  final double aspectRatio;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Squircle.plain(radius)),
        child: CustomPaint(
          painter: TrackThumbnailPainter(
            points: points,
            segments: segments,
            background: c.routeGround,
            runColor: c.run,
            liftColor: c.liftGrey,
            padding: padding,
          ),
        ),
      ),
    );
  }
}
