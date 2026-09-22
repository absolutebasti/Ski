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

  /// The thumbnail ground — darker than `surface` so the route dominates.
  static const Color graphite = Color(0xFF101216);
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

  /// PNG bytes for [detail] (no I/O). Public so tests and the share card can reuse it.
  static Future<Uint8List> renderPng(DayDetail detail, {int width = width, int height = height}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    TrackThumbnailPainter(points: detail.points, segments: detail.segments).paint(canvas, size);
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
  static Future<String> render(DayDetail detail, {Directory? dir}) async {
    final root = dir ?? await getApplicationDocumentsDirectory();
    final thumbs = Directory('${root.path}/thumbs');
    if (!thumbs.existsSync()) thumbs.createSync(recursive: true);
    final file = File('${thumbs.path}/${detail.day.id}.png');
    await file.writeAsBytes(await renderPng(detail), flush: true);
    return file.path;
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
            background: TrackThumbnailPainter.graphite,
            runColor: c.run,
            liftColor: c.liftGrey,
            padding: padding,
          ),
        ),
      ),
    );
  }
}
