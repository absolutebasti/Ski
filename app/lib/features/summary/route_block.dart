import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/surfaces.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import '../days/day_card.dart' show ContourPattern;

/// Full-bleed top block of the Tagesbilanz (docs/DESIGN.md §5): the day's route
/// on ink with a champagne radial glow, drawing itself over 900 ms easeOutQuart,
/// and a bottom-left plate with the date and the resort.
///
/// Fallback when the day has no positions: the contour surface plus a typeset
/// line — never a pictogram.
class RouteBlock extends StatefulWidget {
  const RouteBlock({
    super.key,
    required this.detail,
    required this.title,
    required this.date,
    required this.noTrackLabel,
    this.resort,
    this.height = 300,
    this.animate = true,
  });

  final DayDetail detail;
  /// Overline on the plate ("TAGESBILANZ").
  final String title;
  final String date;
  final String noTrackLabel;
  final String? resort;
  final double height;
  final bool animate;

  @override
  State<RouteBlock> createState() => _RouteBlockState();
}

class _RouteBlockState extends State<RouteBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: Tokens.routeDraw);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final geo = RouteGeometry.fromDetail(widget.detail);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.ink),
          if (geo == null)
            const Opacity(opacity: 0.6, child: ContourPattern())
          else
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: RoutePainter(
                    t: Curves.easeOutQuart.transform(_ctrl.value),
                    geometry: geo,
                    run: c.accent,
                    lift: c.liftGrey,
                  ),
                ),
              ),
            ),
          if (geo == null)
            Center(child: Text(widget.noTrackLabel.overline, style: AppText.label(c.textTertiary))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.ink.withValues(alpha: 0), c.ink.withValues(alpha: 0.85), c.bg],
                    stops: const [0, 0.6, 1],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 18),
              child: _Plate(title: widget.title, date: widget.date, resort: widget.resort),
            ),
          ),
        ],
      ),
    );
  }
}

/// Date plate over the route. Translucent ink, no blur — glass stays on the tab
/// bar and sheets (docs/DESIGN.md §0.6).
class _Plate extends StatelessWidget {
  const _Plate({required this.title, required this.date, this.resort});
  final String title;
  final String date;
  final String? resort;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: c.ink.withValues(alpha: 0.62),
        shape: Squircle.border(Tokens.r14, side: c.glassStroke, width: c.hairlineWidth),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.overline, style: AppText.label(c.textTertiary)),
          const SizedBox(height: 6),
          Text(date, style: AppText.headline(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (resort != null) ...[
            const SizedBox(height: 2),
            Text(resort!, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// One polyline of the day in unit coordinates (0–1, aspect preserved).
class RouteStroke {
  const RouteStroke(this.run, this.points);
  /// true = Abfahrt (champagne), false = Lift/Transfer (dashed grey).
  final bool run;
  final List<Offset> points;
}

/// The day's track projected into a unit square, split into run and lift parts.
class RouteGeometry {
  const RouteGeometry(this.strokes, this.start, this.end);
  final List<RouteStroke> strokes;
  final Offset start;
  final Offset end;

  bool get hasRun => strokes.any((s) => s.run && s.points.length > 1);

  /// null when the day has fewer than two positions — the caller draws the
  /// contour fallback then.
  static RouteGeometry? fromDetail(DayDetail detail) {
    final pts = [for (final p in detail.points) if (p.hasPosition) p];
    if (pts.length < 2) return null;
    var minLat = pts.first.lat!, maxLat = minLat, minLon = pts.first.lon!, maxLon = minLon;
    for (final p in pts) {
      minLat = math.min(minLat, p.lat!);
      maxLat = math.max(maxLat, p.lat!);
      minLon = math.min(minLon, p.lon!);
      maxLon = math.max(maxLon, p.lon!);
    }
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180).abs().clamp(0.05, 1.0);
    final w = (maxLon - minLon) * kx, h = maxLat - minLat;
    final span = math.max(w, h);
    if (span <= 0) return null;
    Offset norm(TrackPoint p) => Offset(
          ((p.lon! - minLon) * kx - w / 2) / span + 0.5,
          ((maxLat - p.lat!) - h / 2) / span + 0.5,
        );

    final segs = [...detail.segments]..sort((a, b) => a.startTs.compareTo(b.startTs));
    final strokes = <RouteStroke>[];
    var si = 0;
    List<Offset>? current;
    var currentRun = false;
    int? lastTs;
    Offset? lastPoint;
    for (final p in pts) {
      while (si < segs.length && segs[si].endTs < p.ts) {
        si++;
      }
      final seg = si < segs.length && p.ts >= segs[si].startTs ? segs[si] : null;
      final isRun = seg?.kind == SegmentKind.run;
      final gap = lastTs != null && p.ts - lastTs > 120000;
      final o = norm(p);
      if (current == null || isRun != currentRun || gap) {
        current = <Offset>[];
        // Stitch to the previous point so the line does not break at a handover.
        if (!gap && lastPoint != null) current.add(lastPoint);
        strokes.add(RouteStroke(isRun, current));
        currentRun = isRun;
      }
      current.add(o);
      lastTs = p.ts;
      lastPoint = o;
    }
    return RouteGeometry(strokes, norm(pts.first), norm(pts.last));
  }
}

/// Draws [geometry] inset into the canvas: champagne radial glow, dashed lifts,
/// the run stroke revealed up to [t] (0–1) along its total length.
class RoutePainter extends CustomPainter {
  const RoutePainter({required this.t, required this.geometry, required this.run, required this.lift, this.inset = 34, this.strokeWidth = 4});

  final double t;
  final RouteGeometry geometry;
  final Color run;
  final Color lift;
  final double inset;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(inset, inset, math.max(1, size.width - inset * 2), math.max(1, size.height - inset * 2));
    final side = math.min(rect.width, rect.height);
    final ox = rect.left + (rect.width - side) / 2, oy = rect.top + (rect.height - side) / 2;
    Offset map(Offset n) => Offset(ox + n.dx * side, oy + n.dy * side);

    // Champagne radial glow behind the route (one of the three gradients).
    final centre = Offset(size.width / 2, size.height * 0.46);
    final glowRect = Rect.fromCircle(center: centre, radius: 210);
    canvas.drawCircle(
      centre,
      210,
      Paint()
        ..shader = RadialGradient(colors: [run.withValues(alpha: 0.10), run.withValues(alpha: 0)]).createShader(glowRect),
    );

    // Lifts: grey dashes that appear slightly ahead of the run stroke.
    final liftPaint = Paint()
      ..color = lift
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final liftPath = Path();
    for (final s in geometry.strokes) {
      if (s.run || s.points.length < 2) continue;
      liftPath.addPolygon([for (final p in s.points) map(p)], false);
    }
    _drawDashed(canvas, liftPath, liftPaint, math.min(1, t * 1.2));

    // Runs: one path, revealed along the cumulative length.
    final runPath = Path();
    for (final s in geometry.strokes) {
      if (!s.run || s.points.length < 2) continue;
      runPath.addPolygon([for (final p in s.points) map(p)], false);
    }
    final drawn = _extract(runPath, t);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = run.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = run
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(map(geometry.start), 4, Paint()..color = run);
    if (t >= 1) {
      canvas.drawCircle(map(geometry.end), 3, Paint()..color = run.withValues(alpha: 0.7));
    }
  }

  static Path _extract(Path path, double t) {
    if (t >= 1) return path;
    final out = Path();
    if (t <= 0) return out;
    final metrics = path.computeMetrics().toList();
    var total = 0.0;
    for (final m in metrics) {
      total += m.length;
    }
    var budget = total * t;
    for (final m in metrics) {
      if (budget <= 0) break;
      final take = math.min(budget, m.length);
      out.addPath(m.extractPath(0, take), Offset.zero);
      budget -= take;
    }
    return out;
  }

  static void _drawDashed(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final m in path.computeMetrics()) {
      final end = m.length * t;
      for (var d = 0.0; d < end; d += 11) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, end)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter old) =>
      old.t != t || old.geometry != geometry || old.run != run || old.lift != lift;
}
