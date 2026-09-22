import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// A ski route that draws itself (900 ms easeOutQuart) — the onboarding hook.
class RouteHook extends StatefulWidget {
  const RouteHook({super.key, this.height = 150, this.animate = true});
  final double height;
  final bool animate;
  @override
  State<RouteHook> createState() => _RouteHookState();
}

class _RouteHookState extends State<RouteHook> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Tokens.routeDraw);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _RoutePainter(Curves.easeOutQuart.transform(_c.value), c.accent, c.liftGrey)),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.t, this.run, this.lift);
  final double t;
  final Color run, lift;

  Path _route(Size s) {
    final p = Path();
    final w = s.width, h = s.height;
    p.moveTo(w * 0.06, h * 0.92);
    p.cubicTo(w * 0.14, h * 0.55, w * 0.22, h * 0.45, w * 0.30, h * 0.62);
    p.cubicTo(w * 0.36, h * 0.74, w * 0.42, h * 0.40, w * 0.50, h * 0.30);
    p.cubicTo(w * 0.58, h * 0.20, w * 0.62, h * 0.52, w * 0.70, h * 0.58);
    p.cubicTo(w * 0.78, h * 0.64, w * 0.84, h * 0.24, w * 0.94, h * 0.12);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // lift: dashed straight line back up
    final liftPaint = Paint()..color = lift..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final a = Offset(size.width * 0.94, size.height * 0.12), b = Offset(size.width * 0.06, size.height * 0.92);
    final len = (a - b).distance;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len * math.min(1, t * 1.2); d += 12) {
      final s = a + dir * d, e = a + dir * math.min(d + 6, len);
      canvas.drawLine(s, e, liftPaint);
    }
    final path = _route(size);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t);
    canvas.drawPath(drawn, Paint()..color = run.withValues(alpha: 0.25)..strokeWidth = 12..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawPath(drawn, Paint()..color = run..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.92), 4, Paint()..color = run);
    if (t >= 1) canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.12), 4, Paint()..color = run);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.t != t;
}
