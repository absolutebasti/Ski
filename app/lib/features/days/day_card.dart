import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// 112 pt list row: route thumbnail, date + resort, a 3-up metric strip,
/// crest for records, chevron. Used on Tage and as "Letzter Tag" on Heute.
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day, this.onTap, this.onLongPress});

  final DaySummary day;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = day.stats;
    final isPb = day.isTopSpeedPb || day.isBiggestDayPb;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.cardGap),
      child: AppCard(
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(tag: 'route-${day.id}', child: DayThumb(path: day.mapThumbPath, width: 84, square: true)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(Fmt.dateShort(day.startedAt, locale: l.code), style: AppText.title(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isPb) ...[
                        Semantics(label: s.pbBadge, child: GlyphIcon(Glyph.crest, size: 16, color: c.accent)),
                        const SizedBox(width: 8),
                      ],
                      GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(day.resortName ?? s.freeTerrain, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  MetricStrip(
                    size: 15,
                    items: [
                      ('${st.runCount}', s.runs),
                      (Fmt.metres(st.dropM, locale: l.code), s.unitHm),
                      (Fmt.kmh(st.maxSpeedMs, locale: l.code), s.unitKmh),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route thumbnail: the PNG written at End, else a quiet contour pattern.
/// There is no state in which a placeholder pictogram ships.
class DayThumb extends StatefulWidget {
  const DayThumb({super.key, required this.path, this.width = 108, this.square = false});
  final String? path;
  final double width;
  final bool square;

  @override
  State<DayThumb> createState() => _DayThumbState();
}

class _DayThumbState extends State<DayThumb> {
  late bool _exists = _check();

  bool _check() {
    final p = widget.path;
    if (p == null || p.isEmpty) return false;
    try {
      return File(p).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  @override
  void didUpdateWidget(DayThumb old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _exists = _check();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = widget.square ? widget.width : widget.width / 1.5;
    return Container(
      width: widget.width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: const Color(0xFF101216), shape: Squircle.border(Tokens.r10, side: c.hairline, width: c.hairlineWidth)),
      child: _exists
          ? Image.file(File(widget.path!), fit: BoxFit.cover, errorBuilder: (context, error, stack) => const ContourPattern())
          : const ContourPattern(),
    );
  }
}

/// Faint diagonal contour hatch — the "no track" surface.
class ContourPattern extends StatelessWidget {
  const ContourPattern({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ContourPainter(AppColors.of(context).textTertiary.withValues(alpha: 0.18)), size: Size.infinite);
}

class _ContourPainter extends CustomPainter {
  _ContourPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final n = (math.max(size.width, size.height) / 9).ceil();
    for (var i = 0; i < n * 2; i++) {
      final path = Path();
      final y0 = i * 9.0 - size.height * 0.5;
      path.moveTo(0, y0);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(x, y0 + math.sin((x + i * 13) / 22) * 3 + x * 0.35);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ContourPainter old) => old.color != color;
}
