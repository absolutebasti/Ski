import 'package:flutter/material.dart';

/// 1.5 pt line with a dot on the last point; no axes. Champagne by default.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color, this.strokeWidth = 1.5, this.bars = false});
  final List<double> values;
  final Color? color;
  final double strokeWidth;
  /// Draw as thin bars (per-day vertical) instead of a line.
  final bool bars;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(painter: _SparkPainter(values, c, strokeWidth, bars), size: Size.infinite);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.stroke, this.bars);
  final List<double> values;
  final Color color;
  final double stroke;
  final bool bars;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = bars ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final range = (max - min).abs() < 1e-9 ? 1.0 : max - min;
    if (bars) {
      final n = values.length;
      final gap = 3.0;
      final w = ((size.width - gap * (n - 1)) / n).clamp(2.0, 14.0);
      final p = Paint()..color = color.withValues(alpha: 0.35);
      final hi = Paint()..color = color;
      var maxI = 0;
      for (var i = 1; i < n; i++) {
        if (values[i] > values[maxI]) maxI = i;
      }
      for (var i = 0; i < n; i++) {
        final h = ((values[i] - min) / range * size.height).clamp(2.0, size.height);
        final x = i * (w + gap);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, w, h), const Radius.circular(2)), i == maxI ? hi : p);
      }
      return;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width : i / (values.length - 1) * size.width;
      final y = size.height - (values[i] - min) / range * (size.height - stroke * 2) - stroke;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    final last = path.computeMetrics().last;
    final end = last.getTangentForOffset(last.length)?.position;
    if (end != null) canvas.drawCircle(end, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color || old.bars != bars;
}
