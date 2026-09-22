import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../recording/live_state_provider.dart';
import '../recording/live_track_provider.dart';
import '../recording/recording_controller.dart';
import 'map_strings.dart';
import 'track_map.dart';

/// Full-height live map over the ring of recent points (docs/DESIGN.md §5
/// "Karte — Sheet"): 44 pt glass circles top, a Slopes-style GPS-quality pill,
/// and a solid readout bar (never a blur over a moving raster) that carries the
/// inline hold-to-end so the day can be finished without leaving the map.
class MapSheet {
  const MapSheet._();

  static Future<void> show(BuildContext context, {VoidCallback? onEnd}) =>
      AppSheet.show<void>(context, expand: true, builder: (_) => MapSheetBody(onEnd: onEnd));
}

/// Exposed for tests; use [MapSheet.show] in the app.
class MapSheetBody extends ConsumerStatefulWidget {
  const MapSheetBody({super.key, this.tilesEnabled = true, this.onEnd});
  final bool tilesEnabled;

  /// Overrides the built-in "end the day and open Tagesbilanz" flow.
  final VoidCallback? onEnd;

  static const double readoutRadius = 24;
  static const double holdHeight = 56;

  @override
  ConsumerState<MapSheetBody> createState() => _MapSheetBodyState();
}

class _MapSheetBodyState extends ConsumerState<MapSheetBody> {
  final ValueNotifier<int> _locate = ValueNotifier(0);
  bool _ending = false;

  @override
  void dispose() {
    _locate.dispose();
    super.dispose();
  }

  Future<void> _end() async {
    final onEnd = widget.onEnd;
    if (onEnd != null) {
      onEnd();
      return;
    }
    if (_ending) return;
    _ending = true;
    final nav = Navigator.of(context);
    final s = MapStrings.of(context);
    final id = await ref.read(recordingControllerProvider.notifier).endDay();
    if (!mounted) return;
    _ending = false;
    if (id == null) {
      showToast(context, s.tooShort);
      return;
    }
    if (nav.canPop()) nav.pop();
    await nav.pushNamed('${AppRoutes.summary}/$id');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = MapStrings.of(context);
    final points = ref.watch(liveTrackProvider);
    final live = ref.watch(liveStateProvider);
    final recording = ref.watch(recordingControllerProvider).isRecording;
    final hasFix = points.any((p) => p.accepted && p.hasPosition);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Tokens.r28)),
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: TrackMap(
                points: points,
                segments: const [],
                follow: true,
                tilesEnabled: widget.tilesEnabled,
                locateSignal: _locate,
              ),
            ),
            // Top row: close · title · locate
            Positioned(
              left: Tokens.pad - 4,
              right: Tokens.pad - 4,
              top: 12,
              child: Row(
                children: [
                  _GlassCircle(glyph: Glyph.close, tooltip: s.close, onTap: () => Navigator.of(context).maybePop()),
                  Expanded(child: Center(child: Text(s.title, style: AppText.title(c.textPrimary)))),
                  _GlassCircle(glyph: Glyph.locate, tooltip: s.locate, onTap: hasFix ? () => _locate.value++ : null),
                ],
              ),
            ),
            // Status row, Slopes-style: GPS quality + what the engine sees.
            Positioned(
              left: Tokens.pad,
              right: Tokens.pad,
              top: 12 + 44 + 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GpsQualityPill(quality: live.gps),
                  if (hasFix) StateChip(text: s.stateWord(live.state, live.stats.runCount), tone: _chipTone(live.state)),
                ],
              ),
            ),
            Positioned(
              left: Tokens.pad - 4,
              right: Tokens.pad - 4,
              bottom: 16 + bottomInset,
              child: _Readout(
                live: live,
                hasFix: hasFix,
                showEnd: recording || widget.onEnd != null,
                onEnd: _end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ChipTone _chipTone(MotionState s) => switch (s) {
      MotionState.run => ChipTone.accent,
      MotionState.lift => ChipTone.ice,
      _ => ChipTone.neutral,
    };

/// Bottom readout, r24, surface at 94 % (no BackdropFilter over a moving map):
/// tempo · höhe, and the inline 56 pt hold-to-end below them at full width —
/// the capsule needs the whole row for 'Tag beenden · halten'.
class _Readout extends StatelessWidget {
  const _Readout({required this.live, required this.hasFix, required this.showEnd, required this.onEnd});
  final LiveState live;
  final bool hasFix, showEnd;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = MapStrings.of(context);
    final locale = AppLocale.of(context).code;

    return Container(
      decoration: ShapeDecoration(
        color: c.surface.withValues(alpha: 0.94),
        shape: Squircle.border(MapSheetBody.readoutRadius, side: c.hairline, width: c.hairlineWidth),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFix)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: HeroNumber(
                    label: s.speed,
                    value: Fmt.kmh(live.speedMs, locale: locale),
                    unit: s.unitKmh,
                    size: 34,
                    color: c.ice,
                  ),
                ),
                const SizedBox(width: 12),
                HeroNumber(
                  label: s.altitude,
                  value: live.altM == null ? s.dash : Fmt.metres(live.altM!, locale: locale),
                  unit: live.altM == null ? null : s.unitM,
                  size: 22,
                  align: CrossAxisAlignment.end,
                ),
              ],
            )
          else
            Text(s.waitingForGps, style: AppText.bodyText(c.textSecondary, size: 15)),
          if (showEnd) ...[
            const SizedBox(height: 14),
            HoldToConfirmButton(label: s.endDay, height: MapSheetBody.holdHeight, onConfirmed: onEnd),
          ],
        ],
      ),
    );
  }
}

/// Slopes-style GPS pill: three ice bars + the word.
class GpsQualityPill extends StatelessWidget {
  const GpsQualityPill({super.key, required this.quality});
  final GpsQuality quality;

  static int barsFor(GpsQuality q) => switch (q) {
        GpsQuality.none => 0,
        GpsQuality.weak => 1,
        GpsQuality.ok => 2,
        GpsQuality.good || GpsQuality.veryGood => 3,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = MapStrings.of(context);
    final filled = barsFor(quality);
    final on = quality == GpsQuality.none ? c.danger : c.ice;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.glassFill, c.ink.withValues(alpha: 0.62)),
        borderRadius: BorderRadius.circular(Tokens.rPill),
        border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 2.5),
                  Container(
                    width: 3,
                    height: 5.0 + i * 3.5,
                    decoration: BoxDecoration(
                      color: i < filled ? on : c.textQuaternary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(s.gpsPill(quality), style: AppText.label(quality == GpsQuality.none ? c.danger : c.textPrimary, size: 12)),
        ],
      ),
    );
  }
}

/// 44 pt glass circle with one of the app's own glyphs.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.glyph, required this.tooltip, this.onTap});
  final Glyph glyph;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color.alphaBlend(c.glassFill, c.ink.withValues(alpha: 0.62)),
            shape: BoxShape.circle,
            border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
          ),
          child: Center(child: GlyphIcon(glyph, size: 20, color: onTap == null ? c.textTertiary : c.textPrimary)),
        ),
      ),
    );
  }
}
