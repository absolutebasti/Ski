import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import 'share_strings.dart';

/// Output sizes of the share card (docs/DESIGN.md §5 "Share Card").
/// [portrait] is the default so existing callers keep their 1080×1350 image.
enum ShareFormat {
  /// Feed / WhatsApp — the full card with the bottom stat row.
  portrait(1080, 1350),

  /// Square feed — drops the bottom stat row.
  square(1080, 1080),

  /// Instagram story — route at 900 pt, wordmark 120 pt above the edge.
  story(1080, 1920);

  const ShareFormat(this.width, this.height);

  final double width;
  final double height;

  Size get size => Size(width, height);

  /// File-name suffix so the three variants never overwrite each other.
  String get slug => switch (this) { ShareFormat.portrait => '4x5', ShareFormat.square => '1x1', ShareFormat.story => '9x16' };
}

/// The share card (docs/DESIGN.md §5): always dark, independent of the app
/// theme — it is an image, not a screen. Graphite field with a champagne
/// radial and 3 % grain, the drawn route as the hero surface, champagne
/// numerals with the overline above them, `kAppName` wordmark bottom-right.
/// Wrap in a [FittedBox] to preview it in the UI.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.detail, this.format = ShareFormat.portrait});

  /// Legacy constants — the default (portrait) size.
  static const double width = 1080;
  static const double height = 1350;
  static const double pad = 72;

  /// Route block height per format.
  static const double routePortrait = 560;
  static const double routeSquare = 500;
  static const double routeStory = 900;

  static double routeHeight(ShareFormat f) => switch (f) {
        ShareFormat.portrait => routePortrait,
        ShareFormat.square => routeSquare,
        ShareFormat.story => routeStory,
      };

  final DayDetail detail;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final day = detail.day;
    final st = day.stats;
    final longest = _longestRun();
    final size = format.size;
    final story = format == ShareFormat.story;

    final head = <Widget>[
      Text(Fmt.dateLong(day.startedAt, locale: l.code), style: AppText.headline(c.textPrimary, size: 44), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      Text(day.resortName ?? s.freeTerrain, style: AppText.bodyText(c.textSecondary, size: 30), maxLines: 1, overflow: TextOverflow.ellipsis),
    ];

    final route = SizedBox(
      height: routeHeight(format),
      child: CustomPaint(
        painter: RoutePainter(
          points: detail.points,
          segments: detail.segments,
          run: c.run,
          lift: c.liftGrey,
          startDot: 14,
          inset: 40,
        ),
        child: const SizedBox.expand(),
      ),
    );

    final hero = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 5, child: _Hero(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitM, label: s.vertical, size: 120)),
        Expanded(flex: 2, child: _Hero(value: '${st.runCount}', label: s.runs, size: 104)),
        Expanded(flex: 3, child: _Hero(value: Fmt.kmh(st.maxSpeedMs, locale: l.code), unit: s.unitKmh, label: s.topSpeed, size: 104)),
      ],
    );

    final stats = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 3, child: _Stat(value: Fmt.km(st.skiDistanceM, locale: l.code), unit: s.unitKm, label: s.skiKm)),
        Expanded(
          flex: 4,
          child: _Stat(
            value: longest == null ? '–' : Fmt.metres(longest.dropM, locale: l.code),
            unit: longest == null ? null : s.unitM,
            label: s.longestRun,
          ),
        ),
        const Expanded(
          flex: 4,
          // scaleDown so a long wordmark never overflows the column
          child: Align(alignment: Alignment.bottomRight, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: Wordmark())),
        ),
      ],
    );

    final body = <Widget>[
      ...head,
      const SizedBox(height: 40),
      route,
      const Spacer(),
      hero,
      const SizedBox(height: 28),
      const _CardHairline(),
      const SizedBox(height: 24),
      if (format == ShareFormat.portrait)
        stats
      else ...[
        if (story) const Spacer(),
        const Align(alignment: Alignment.bottomRight, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: Wordmark())),
      ],
    ];

    return MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: 1, textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Tokens.bg),
          child: Stack(
            children: [
              // champagne radial, 700 px, top-right at 8 %
              Positioned(
                right: -180,
                top: -180,
                width: 700,
                height: 700,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [c.accent.withValues(alpha: 0.08), c.accent.withValues(alpha: 0)]),
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: const GrainPainter(), isComplex: true)),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, story ? 120 : pad),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Segment? _longestRun() {
    Segment? best;
    for (final r in detail.runs) {
      if (best == null || r.dropM > best.dropM) best = r;
    }
    return best;
  }
}

/// Overline above a champagne numeral with a baseline-aligned unit.
class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.label, this.unit, required this.size});
  final String value;
  final String label;
  final String? unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.overline, style: AppText.label(c.textSecondary, size: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.numXxl(c.accent).copyWith(fontSize: size), maxLines: 1))),
            if (unit != null) ...[const SizedBox(width: 10), Text(unit!, style: AppText.unit(c.textSecondary, size: 34))],
          ],
        ),
      ],
    );
  }
}

/// 56 pt cream numeral with its overline, bottom row of the card.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.unit});
  final String value;
  final String label;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.overline, style: AppText.label(c.textSecondary, size: 20), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.numXxl(c.textPrimary).copyWith(fontSize: 56), maxLines: 1))),
            if (unit != null) ...[const SizedBox(width: 8), Text(unit!, style: AppText.unit(c.textSecondary, size: 22))],
          ],
        ),
      ],
    );
  }
}

/// Full-width 0.5 px rule at 10 % white.
class _CardHairline extends StatelessWidget {
  const _CardHairline();
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 0.5, child: ColoredBox(color: Colors.white.withValues(alpha: 0.10)));
}

/// Glyph + `kAppName`, bottom-right of the card (chevron 56, wordmark 46).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(size: Size.square(size), painter: const GlyphPainter(color: Tokens.textPrimary)),
        SizedBox(width: size * 0.25),
        Text(kAppName, style: AppText.headline(c.textPrimary, size: size * 46 / 56)),
      ],
    );
  }
}

/// The brand glyph: `M212 592 L416 312 L812 752` on a 1024 grid, stroke 88, round caps.
class GlyphPainter extends CustomPainter {
  const GlyphPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width, size.height) / 1024;
    final path = Path()
      ..moveTo(212 * k, 592 * k)
      ..lineTo(416 * k, 312 * k)
      ..lineTo(812 * k, 752 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 88 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(GlyphPainter old) => old.color != color;
}

/// 3 % monochrome grain — the cheap trick that makes the card look produced.
/// Deterministic (fixed seed) so two renders of the same day are identical.
class GrainPainter extends CustomPainter {
  const GrainPainter({this.opacity = 0.03, this.seed = 20260922});
  final double opacity;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final n = (size.width * size.height / 120).round().clamp(0, 40000);
    if (n == 0) return;
    final rnd = math.Random(seed);
    final pts = Float32List(n * 2);
    for (var i = 0; i < n; i++) {
      pts[i * 2] = rnd.nextDouble() * size.width;
      pts[i * 2 + 1] = rnd.nextDouble() * size.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(GrainPainter old) => old.opacity != opacity || old.seed != seed;
}

/// Mini route: runs as a champagne line with a soft glow, lifts dashed grey,
/// a start dot at the first accepted fix. Equirectangular projection fitted to
/// the box, aspect preserved.
class RoutePainter extends CustomPainter {
  const RoutePainter({
    required this.points,
    required this.segments,
    required this.run,
    required this.lift,
    this.runWidth = 6,
    this.liftWidth = 3,
    this.startDot = 0,
    this.inset,
  });

  final List<TrackPoint> points;
  final List<Segment> segments;
  final Color run;
  final Color lift;
  final double runWidth;
  final double liftWidth;

  /// Diameter of the champagne start dot; 0 hides it.
  final double startDot;

  /// Padding around the fitted route; defaults to `runWidth * 2`.
  final double? inset;

  @override
  void paint(Canvas canvas, Size size) {
    final pos = points.where((p) => p.accepted && p.hasPosition).toList();
    if (pos.length < 2) return;
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in pos) {
      minLat = math.min(minLat, p.lat!);
      maxLat = math.max(maxLat, p.lat!);
      minLon = math.min(minLon, p.lon!);
      maxLon = math.max(maxLon, p.lon!);
    }
    final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = math.max(1e-6, (maxLon - minLon) * cosLat);
    final spanY = math.max(1e-6, maxLat - minLat);
    final pad = inset ?? runWidth * 2;
    final scale = math.min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanY);
    final ox = (size.width - spanX * scale) / 2;
    final oy = (size.height - spanY * scale) / 2;
    Offset project(TrackPoint p) => Offset(ox + (p.lon! - minLon) * cosLat * scale, oy + (maxLat - p.lat!) * scale);

    final runPaths = <Path>[];
    final liftPaths = <Path>[];
    final ordered = [...segments]..sort((a, b) => a.idx.compareTo(b.idx));
    for (final s in ordered) {
      if (s.kind != SegmentKind.run && s.kind != SegmentKind.lift) continue;
      Path? path;
      for (final p in pos) {
        if (p.ts < s.startTs) continue;
        if (p.ts > s.endTs) break;
        final o = project(p);
        if (path == null) {
          path = Path()..moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      if (path == null) continue;
      (s.kind == SegmentKind.run ? runPaths : liftPaths).add(path);
    }
    // No segments yet (live preview): draw the whole track as one run.
    if (runPaths.isEmpty && liftPaths.isEmpty) {
      final path = Path()..moveTo(project(pos.first).dx, project(pos.first).dy);
      for (final p in pos.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      runPaths.add(path);
    }

    final liftPaint = Paint()
      ..color = lift
      ..style = PaintingStyle.stroke
      ..strokeWidth = liftWidth
      ..strokeCap = StrokeCap.round;
    for (final p in liftPaths) {
      canvas.drawPath(_dashed(p, liftWidth * 4, liftWidth * 3), liftPaint);
    }
    final glow = Paint()
      ..color = run.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = runWidth * 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, runWidth);
    final line = Paint()
      ..color = run
      ..style = PaintingStyle.stroke
      ..strokeWidth = runWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in runPaths) {
      canvas.drawPath(p, glow);
    }
    for (final p in runPaths) {
      canvas.drawPath(p, line);
    }
    if (startDot > 0) canvas.drawCircle(project(pos.first), startDot / 2, Paint()..color = run);
  }

  static Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(metric.length, d + dash);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      !identical(old.points, points) ||
      !identical(old.segments, segments) ||
      old.run != run ||
      old.lift != lift ||
      old.startDot != startDot ||
      old.inset != inset;
}
