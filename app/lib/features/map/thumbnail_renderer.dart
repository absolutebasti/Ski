import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';

import '../../app/theme/tokens.dart';
import '../../core/core.dart';
import 'track_geometry.dart';

/// Paints a day's track without tiles: graphite ground, champagne runs with a
/// soft glow, grey dashed lifts. Used for the 600×400 PNG and the list card.
class TrackThumbnailPainter extends CustomPainter {
  TrackThumbnailPainter({
    required this.points,
    this.segments = const [],
    this.background = Tokens.surface,
    this.runColor = Tokens.champagne,
    this.liftColor = Tokens.liftGrey,
    this.padding = 24,
    this.runWidth = 3,
    this.glowWidth = 9,
    this.liftWidth = 1.5,
  }) : lines = TrackGeometry.split(points, segments);

  final List<TrackPoint> points;
  final List<Segment> segments;
  final List<TrackLine> lines;
  final Color background, runColor, liftColor;
  final double padding, runWidth, glowWidth, liftWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final b = TrackGeometry.bounds(points);
    if (b == null || lines.isEmpty) return;

    final project = _Projection(b.$1, b.$2, size, padding);

    final glow = Paint()
      ..color = runColor.withValues(alpha: 0.25)
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
    for (final p in runPaths) {
      canvas.drawPath(p, glow);
    }
    for (final p in runPaths) {
      canvas.drawPath(p, run);
    }
    for (final p in liftPaths) {
      canvas.drawPath(_dashed(p, 6, 5), lift);
    }
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
      !identical(old.points, points) || !identical(old.segments, segments) || old.background != background || old.runColor != runColor;
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
  const TrackThumbnail({super.key, required this.points, this.segments = const [], this.aspectRatio = 1.5});
  final List<TrackPoint> points;
  final List<Segment> segments;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radius - 4),
        child: CustomPaint(
          painter: TrackThumbnailPainter(points: points, segments: segments, background: c.elevated, runColor: c.run, liftColor: c.liftGrey, padding: 12),
        ),
      ),
    );
  }
}
