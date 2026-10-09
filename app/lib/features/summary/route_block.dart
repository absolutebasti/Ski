import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/surfaces.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import '../days/day_card.dart' show ContourPattern;
import '../map/map_images.dart';
import '../map/map_overlay.dart';
import '../map/map_region.dart';
import '../map/map_strings.dart';
import '../map/thumbnail_renderer.dart';

/// Full-bleed top block of the Tagesbilanz (docs/DESIGN.md §5): the day's route
/// on ink with a champagne radial glow, drawing itself over 900 ms easeOutQuart,
/// and a bottom-left plate with the date and the resort.
///
/// With an Apple-Maps snapshot (`<id>_hero.png` + `_hero.json`, written at End
/// when online) the satellite image is the ground and the same animated route
/// is drawn on top, projected through the stored [MapFrame] so it sits on the
/// terrain 1:1. Offline / no snapshot: the ink ground as before. The snapshot
/// usually lands a few seconds after End: the block listens to
/// [mapImageRevisionProvider], switches to the satellite ground when it
/// arrives and draws the route again on it.
///
/// Fallback when the day has no positions: the contour surface plus a typeset
/// line — never a pictogram.
class RouteBlock extends ConsumerStatefulWidget {
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

  /// Plate distance from the block bottom: the Apple wordmark strip
  /// (AppleWordmark.clearance) plus 4 pt stays below it.
  static const double plateBottom = AppleWordmark.clearance + 4;

  /// Key of the bottom scrim (tests).
  static const scrimKey = ValueKey('route-block-scrim');

  @override
  ConsumerState<RouteBlock> createState() => _RouteBlockState();
}

class _RouteBlockState extends ConsumerState<RouteBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: Tokens.routeDraw);
  bool _started = false;
  late _Ground _ground = _Ground.of(widget.detail);

  @override
  void initState() {
    super.initState();
    // The snapshot lands after End (network): MapImages bumps the revision.
    ref.listenManual(mapImageRevisionProvider, (_, _) => _recheck());
  }

  void _recheck() {
    if (!mounted) return;
    final next = _Ground.of(widget.detail);
    final arrived = _ground.frame == null && next.frame != null;
    setState(() => _ground = next);
    // The route was drawn on ink with its own framing: draw it again on the terrain.
    if (arrived && widget.animate && !Tokens.reduced(context)) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(RouteBlock old) {
    super.didUpdateWidget(old);
    // A refreshed detail (e.g. a new map path) re-checks too.
    if (!identical(old.detail, widget.detail)) _ground = _Ground.of(widget.detail);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !Tokens.reduced(context)) {
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
    final frame = _ground.frame;
    final geo = frame == null
        ? RouteGeometry.fromDetail(widget.detail)
        : RouteGeometry.fromDetail(widget.detail, project: frame.region.project);
    // Over imagery the route keeps the dark-theme pair in both themes (like the
    // share card): bright champagne and a light dash read on rock and forest.
    final run = frame == null ? c.accent : AppColors.dark.accent;
    final lift = frame == null ? c.liftGrey : AppColors.dark.textSecondary;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.ink),
          if (frame != null) ...[
            RepaintBoundary(child: _SatelliteImage(path: _ground.imagePath!)),
            ColoredBox(color: AppColors.dark.ink.withValues(alpha: 0.22)),
          ],
          if (geo == null && frame == null)
            const Opacity(opacity: 0.6, child: ContourPattern())
          else if (geo != null)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: RoutePainter(
                    t: Curves.easeOutQuart.transform(_ctrl.value),
                    geometry: geo,
                    run: run,
                    lift: lift,
                    imageSize: frame?.size,
                  ),
                ),
              ),
            ),
          if (geo == null)
            Center(child: Text(widget.noTrackLabel.overline, style: AppText.label(frame == null ? c.textTertiary : AppColors.dark.textSecondary))),
          // Fade into the page over the bottom 120 pt; over a snapshot the
          // scrim opens a window on the Apple wordmark (bottom-left, whole).
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: RouteBlock.scrimKey,
                painter: WordmarkScrim(
                  gradientHeight: 120,
                  imageSize: frame?.size,
                  // The image already lies under a 22 % ink veil.
                  veil: WordmarkScrim.defaultVeil.withValues(alpha: 0.12),
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
              padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, RouteBlock.plateBottom),
              child: _Plate(title: widget.title, date: widget.date, resort: widget.resort),
            ),
          ),
          // On the plate's bottom line, where the fade is still dark ink in
          // both themes (lower down it turns into the light page in light mode).
          if (frame != null)
            Positioned(
              right: Tokens.pad,
              bottom: RouteBlock.plateBottom,
              child: ExcludeSemantics(
                child: Text(MapStrings.of(context).appleAttribution, style: AppText.caption(AppColors.dark.textTertiary, size: 10)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Which ground the block has: the snapshot path + frame, or nothing.
class _Ground {
  const _Ground(this.imagePath, this.frame);
  final String? imagePath;
  final MapFrame? frame;

  static _Ground of(DayDetail detail) {
    final base = detail.day.mapThumbPath;
    final frame = ThumbnailRenderer.heroFrameFor(base);
    if (frame == null) return const _Ground(null, null);
    return _Ground(ThumbnailRenderer.heroPathFor(base!), frame);
  }
}

/// The hero snapshot, cover-fitted bottom-left (the painter uses the same fit;
/// the corner with the Apple wordmark is never cropped), fading in when it
/// decodes after the route has started drawing.
class _SatelliteImage extends StatelessWidget {
  const _SatelliteImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final fade = Tokens.motion(context, Tokens.routeDraw ~/ 3);
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      alignment: Alignment.bottomLeft,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: Curves.easeOut, child: child),
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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
    // The block's ground is ink (or imagery under an ink veil) in every theme,
    // so the plate keeps the dark palette: light-theme text would be dark on dark.
    const c = AppColors.dark;
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
  ///
  /// [project] maps a position onto a map image (unit coordinates of the
  /// image, see [MapRegion.project]); without it the track is normalised into
  /// a unit square with the aspect preserved.
  static RouteGeometry? fromDetail(DayDetail detail, {Offset Function(double lat, double lon)? project}) {
    final pts = [for (final p in detail.points) if (p.hasPosition) p];
    if (pts.length < 2) return null;
    final norm = project != null ? (TrackPoint p) => project(p.lat!, p.lon!) : _unitSquare(pts);
    if (norm == null) return null;
    return _build(detail, pts, norm);
  }

  /// Where the rider was at [ts] (first position at or after it), in the same
  /// unit coordinates as [fromDetail] — the altitude-profile scrub marker.
  static Offset? positionAt(DayDetail detail, int ts, {Offset Function(double lat, double lon)? project}) {
    final pts = [for (final p in detail.points) if (p.hasPosition) p];
    if (pts.length < 2) return null;
    final norm = project != null ? (TrackPoint p) => project(p.lat!, p.lon!) : _unitSquare(pts);
    if (norm == null) return null;
    return norm(pts.firstWhere((p) => p.ts >= ts, orElse: () => pts.last));
  }

  static Offset Function(TrackPoint)? _unitSquare(List<TrackPoint> pts) {
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
    return (TrackPoint p) => Offset(
          ((p.lon! - minLon) * kx - w / 2) / span + 0.5,
          ((maxLat - p.lat!) - h / 2) / span + 0.5,
        );
  }

  static RouteGeometry _build(DayDetail detail, List<TrackPoint> pts, Offset Function(TrackPoint) norm) {
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

/// Draws [geometry] inset into the canvas: champagne radial glow centred on
/// the route, dashed lifts, the run stroke revealed up to [t] (0–1) along its
/// total length.
///
/// [inset] keeps the route clear of the date plate: the default leaves 130 pt
/// at the bottom (plate ≈ 80 pt + 38 pt margin over the Apple wordmark strip +
/// breathing room), 34 pt on the other sides. [routeRect] exposes the area the
/// route is mapped into.
///
/// With [imageSize] the geometry is in unit coordinates of a map image that is
/// cover-fitted into the canvas (BoxFit.cover, bottom-left like the Image);
/// the route is mapped onto that rectangle instead, so it lands on the imagery
/// 1:1. The inset is then already baked into the image's framing
/// (ThumbnailRenderer.heroInset).
class RoutePainter extends CustomPainter {
  const RoutePainter({
    required this.t,
    required this.geometry,
    required this.run,
    required this.lift,
    this.inset = defaultInset,
    this.strokeWidth = 4,
    this.imageSize,
    this.marker,
  });

  /// Default inset: the bottom clears the date plate.
  static const EdgeInsets defaultInset = EdgeInsets.fromLTRB(34, 34, 34, 130);

  final double t;
  final RouteGeometry geometry;
  final Color run;
  final Color lift;
  final EdgeInsets inset;
  final double strokeWidth;
  /// Size (pt) of the map image the geometry was projected onto; null = unit square.
  final Size? imageSize;
  /// Optional position marker (unit coordinates, see RouteGeometry.positionAt).
  final Offset? marker;

  /// The square the unit route is mapped into for a canvas of [size]: the
  /// inset rectangle, shrunk to a centred square so the aspect stays intact.
  /// No route pixel lies outside it (apart from half the stroke width).
  Rect routeRect(Size size) {
    final img = imageSize;
    if (img != null && img.width > 0 && img.height > 0) return AppleWordmark.coverBottomLeft(img, size).$1;
    final rect = Rect.fromLTWH(
      inset.left,
      inset.top,
      math.max(1, size.width - inset.horizontal),
      math.max(1, size.height - inset.vertical),
    );
    final side = math.min(rect.width, rect.height);
    return Rect.fromLTWH(rect.left + (rect.width - side) / 2, rect.top + (rect.height - side) / 2, side, side);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final square = routeRect(size);
    Offset map(Offset n) => Offset(square.left + n.dx * square.width, square.top + n.dy * square.height);
    if (imageSize != null) canvas.clipRect(Offset.zero & size);

    // Champagne radial glow behind the route (one of the three gradients),
    // centred on the route bounds rather than on the canvas.
    final centre = _boundsCentre(map);
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
    final m = marker;
    if (m != null) {
      final at = map(m);
      canvas.drawCircle(at, 9, Paint()..color = run.withValues(alpha: 0.25));
      canvas.drawCircle(at, 6, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(at, 4, Paint()..color = run);
    }
  }

  /// Centre of the drawn strokes' bounding box in canvas coordinates.
  Offset _boundsCentre(Offset Function(Offset) map) {
    var minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final s in geometry.strokes) {
      for (final p in s.points) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    if (!minX.isFinite) return map(const Offset(0.5, 0.5));
    return map(Offset((minX + maxX) / 2, (minY + maxY) / 2));
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
      old.t != t || old.geometry != geometry || old.run != run || old.lift != lift || old.inset != inset || old.imageSize != imageSize || old.marker != marker;
}
