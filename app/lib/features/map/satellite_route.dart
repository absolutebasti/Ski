import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import '../summary/route_block.dart' show RouteGeometry, RoutePainter;
import 'map_images.dart';
import 'map_overlay.dart';
import 'map_strings.dart';
import 'thumbnail_renderer.dart';

/// The day's route on the Apple Maps satellite image written at End — the
/// same ground as the Tagesbilanz, without any tile server (launch audit
/// 2026-10-09: no interactive tile map in v1). Offline or before the snapshot
/// exists: the route on ink. [scrubTs] puts a marker where the rider was.
///
/// The bottom [AppleWordmark.clearance] pt stay free of text and the scrim
/// opens a window over the Apple wordmark (MapKit terms); the attribution
/// line sits bottom-right.
class SatelliteRoute extends ConsumerWidget {
  const SatelliteRoute({super.key, required this.detail, this.scrubTs});

  final DayDetail detail;
  final int? scrubTs;

  /// Route area without a snapshot: clear of the header buttons on top and of
  /// the date plate at the bottom.
  static const EdgeInsets inkInset = EdgeInsets.fromLTRB(34, 72, 34, 120);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The snapshot may land while the screen is open (render after End).
    ref.watch(mapImageRevisionProvider);
    final c = AppColors.of(context);
    final base = detail.day.mapThumbPath;
    final frame = ThumbnailRenderer.heroFrameFor(base);
    final project = frame?.region.project;
    final geo = RouteGeometry.fromDetail(detail, project: project);
    final ts = scrubTs;
    final marker = ts == null ? null : RouteGeometry.positionAt(detail, ts, project: project);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.ink),
        if (frame != null) ...[
          Image.file(
            File(ThumbnailRenderer.heroPathFor(base!)),
            fit: BoxFit.cover,
            alignment: Alignment.bottomLeft,
            excludeFromSemantics: true,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
          ColoredBox(color: AppColors.dark.ink.withValues(alpha: 0.22)),
        ],
        if (geo != null)
          RepaintBoundary(
            child: CustomPaint(
              painter: RoutePainter(
                t: 1,
                geometry: geo,
                run: frame == null ? c.accent : AppColors.dark.accent,
                lift: frame == null ? c.liftGrey : AppColors.dark.textSecondary,
                inset: inkInset,
                imageSize: frame?.size,
                marker: marker,
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: WordmarkScrim(
                gradientHeight: 150,
                imageSize: frame?.size,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.ink.withValues(alpha: 0), c.ink.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ),
        ),
        if (frame != null)
          Positioned(
            right: Tokens.pad,
            bottom: 12,
            child: ExcludeSemantics(
              child: Text(MapStrings.of(context).appleAttribution, style: AppText.caption(AppColors.dark.textTertiary, size: 10)),
            ),
          ),
      ],
    );
  }
}
