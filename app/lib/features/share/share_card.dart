import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import 'share_strings.dart';

/// 1080×1350 share card (docs/PLAN.md §11): graphite field, champagne numbers,
/// mini route, `kAppName` wordmark bottom-right. Always dark, independent of
/// the app theme — it is an image, not a screen. Wrap in a [FittedBox] to
/// preview it in the UI.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.detail});

  static const double width = 1080;
  static const double height = 1350;
  static const double pad = 72;

  final DayDetail detail;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final day = detail.day;
    final st = day.stats;
    final longest = _longestRun();

    return MediaQuery(
      data: const MediaQueryData(size: Size(width, height), devicePixelRatio: 1, textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Tokens.bg),
          child: Padding(
            padding: const EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.dateLong(day.startedAt, locale: l.code), style: AppText.headline(c.textPrimary, size: 44), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(day.resortName ?? s.freeTerrain, style: AppText.bodyText(c.textSecondary, size: 30), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 40),
                Expanded(
                  child: CustomPaint(
                    painter: RoutePainter(points: detail.points, segments: detail.segments, run: c.run, lift: c.liftGrey),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Hero(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitM, label: s.vertical)),
                    Expanded(child: _Hero(value: '${st.runCount}', label: s.runs)),
                    Expanded(child: _Hero(value: Fmt.kmh(st.maxSpeedMs, locale: l.code), unit: s.unitKmh, label: s.topSpeed)),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Stat(value: Fmt.km(st.skiDistanceM, locale: l.code), unit: s.unitKm, label: s.skiKm)),
                    Expanded(child: _Stat(value: longest == null ? '–' : Fmt.metres(longest.dropM, locale: l.code), unit: longest == null ? null : s.unitM, label: s.longestRun)),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        // scaleDown so a long wordmark never overflows the column
                        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: Wordmark()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.label, this.unit});
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
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.hero(c.accent, size: 104), maxLines: 1))),
            if (unit != null) ...[const SizedBox(width: 10), Text(unit!, style: AppText.unit(c.textSecondary, size: 30))],
          ],
        ),
        const SizedBox(height: 10),
        Text(label.toUpperCase(), style: AppText.label(c.textSecondary, size: 22)),
      ],
    );
  }
}

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
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppText.stat(c.textPrimary, size: 56), maxLines: 1),
            if (unit != null) ...[const SizedBox(width: 8), Text(unit!, style: AppText.unit(c.textSecondary, size: 24))],
          ],
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: AppText.label(c.textSecondary, size: 20)),
      ],
    );
  }
}

/// Glyph + `kAppName`, bottom-right of the card.
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
        Text(kAppName, style: AppText.headline(c.textPrimary, size: size * 0.8)),
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

/// Mini route: runs as a champagne line with a soft glow, lifts dashed grey.
/// Equirectangular projection fitted to the box, aspect preserved.
class RoutePainter extends CustomPainter {
  const RoutePainter({required this.points, required this.segments, required this.run, required this.lift, this.runWidth = 6, this.liftWidth = 3});

  final List<TrackPoint> points;
  final List<Segment> segments;
  final Color run;
  final Color lift;
  final double runWidth;
  final double liftWidth;

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
    final inset = runWidth * 2;
    final scale = math.min((size.width - 2 * inset) / spanX, (size.height - 2 * inset) / spanY);
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
      ..strokeJoin = StrokeJoin.round;
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
      !identical(old.points, points) || !identical(old.segments, segments) || old.run != run || old.lift != lift;
}
