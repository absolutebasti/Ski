import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../map/map_images.dart';
import '../map/map_overlay.dart';
import '../map/map_strings.dart';
import '../map/thumbnail_renderer.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// 112 pt list row: route thumbnail, date + resort, a 3-up metric strip,
/// crest for records, chevron. Used on Tage and as "Letzter Tag" on Heute.
///
/// When the Apple-Maps snapshot `<id>_map.png` exists (written at End, online
/// only) it becomes the ground of a 172 pt card (MapCardGeometry): the route
/// in the free top band, date, resort and numerals below it, the Apple
/// wordmark uncovered in the bottom-left strip. Else
/// the themed path PNG, else the contour. A card built without the snapshot
/// asks [MapImages.ensure] for it (once per session per day); the card
/// re-checks its files whenever [mapImageRevisionProvider] is bumped.
class DayCard extends ConsumerWidget {
  const DayCard({super.key, required this.day, this.onTap, this.onLongPress});

  final DaySummary day;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Key of the scrim over the map image (tests).
  static const scrimKey = ValueKey('day-card-map-scrim');

  /// `<id>_map.png` for [basePath] when it exists on disk.
  static String? mapImagePath(String? basePath) {
    if (basePath == null || basePath.isEmpty) return null;
    final map = ThumbnailRenderer.mapPathFor(basePath);
    if (map == basePath) return null;
    try {
      return File(map).existsSync() ? map : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = day.stats;
    final isPb = day.isTopSpeedPb || day.isBiggestDayPb;
    // A snapshot landing after End (or on a later online launch) bumps the
    // revision: rebuild and look for the file again.
    ref.watch(mapImageRevisionProvider);
    final mapPath = mapImagePath(day.mapThumbPath);
    if (mapPath == null) {
      // Ended offline or recorded before the feature: retry in the background.
      final images = ref.read(mapImagesProvider);
      final id = day.id;
      scheduleMicrotask(() => images.ensure(id));
    }

    final text = Column(
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
            RowChevron(color: mapPath == null ? null : c.textSecondary),
          ],
        ),
        const SizedBox(height: 2),
        Text(day.resortName ?? s.freeTerrain, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        // Real labels (ABFAHRTEN / HÖHENMETER / TOP-SPEED); the unit
        // joins the numeral once MetricStrip takes an overline-first triple.
        MetricStrip(
          size: 15,
          items: [
            ('${st.runCount}', s.runs),
            // Units as overlines: the list row's 65 pt columns cannot hold 'HÖHENMETER'.
            (Fmt.metres(st.dropM, locale: l.code), s.unitHm),
            (Fmt.kmh(st.maxSpeedMs, locale: l.code), s.unitKmh),
          ],
        ),
      ],
    );

    if (mapPath != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Tokens.cardGap),
        child: AppCard(
          onTap: onTap,
          onLongPress: onLongPress,
          padding: EdgeInsets.zero,
          // No Hero here: the day detail opens on a different map, so a flight
          // from this card would jump. The path-thumbnail row keeps its Hero.
          child: _MapGround(path: mapPath, child: text),
        ),
      );
    }

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
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}

/// The satellite snapshot as the card ground, rendered at exactly this card's
/// size (MapCardGeometry: card width × 172 pt, taller with larger text) and
/// shown 1:1 — cover, bottom-left aligned, so even a mismatched image never
/// loses the corner with the Apple wordmark. Top: the free route band. Middle:
/// the text over a bottom-up scrim in the route ground colour (graphite dark /
/// paper light). Bottom strip: the wordmark uncovered (the scrim opens a window
/// over it) and 'Karten: © Apple' on the right.
class _MapGround extends StatelessWidget {
  const _MapGround({required this.path, required this.child});
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ground = c.routeGround;
    final height = MapCardGeometry.height(MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.hasBoundedWidth ? box.maxWidth : MapCardGeometry.width(MediaQuery.sizeOf(context).width);
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Stack(
            alignment: AlignmentDirectional.bottomStart,
            children: [
              Positioned.fill(child: ColoredBox(color: ground)),
              Positioned.fill(
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomLeft,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => const ContourPattern(),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: DayCard.scrimKey,
                    painter: WordmarkScrim(
                      imageSize: Size(width, height),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          ground.withValues(alpha: 0.94),
                          ground.withValues(alpha: 0.84),
                          ground.withValues(alpha: 0.50),
                          ground.withValues(alpha: 0.10),
                        ],
                        // 172 pt card: dense under the numerals and the
                        // attribution, ~0.5 at the title line (62 pt), light
                        // over the route band.
                        stops: const [0, 0.45, 0.62, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: MapCardGeometry.textPadding, child: child),
              Positioned(
                right: 12,
                bottom: AppleWordmark.bottom,
                child: ExcludeSemantics(
                  child: Text(MapStrings.of(context).appleAttribution, style: AppText.caption(c.textTertiary, size: 10)),
                ),
              ),
            ],
          ),
        );
      },
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

  /// Light theme: prefer `<id>_light.png` when the recorder wrote one.
  String _themedPath(BuildContext context, String path) {
    if (AppColors.of(context).isDark) return path;
    final light = ThumbnailRenderer.lightPathFor(path);
    try {
      return File(light).existsSync() ? light : path;
    } on FileSystemException {
      return path;
    }
  }

  bool _check() {
    final p = widget.path;
    if (p == null || p.isEmpty) return false;
    try {
      return File(p).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  /// Every parent rebuild re-checks (one stat): the path PNG can land after
  /// the row was built, e.g. with a map-image revision bump.
  @override
  void didUpdateWidget(DayThumb old) {
    super.didUpdateWidget(old);
    _exists = _check();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = widget.square ? widget.width : widget.width / 1.5;
    return Container(
      width: widget.width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: c.routeGround, shape: Squircle.border(Tokens.r10, side: c.hairline, width: c.hairlineWidth)),
      child: _exists
          ? Image.file(File(_themedPath(context, widget.path!)), fit: BoxFit.cover, errorBuilder: (context, error, stack) => const ContourPattern())
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
