import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../share/share_card_data.dart';
import '../../share/share_service.dart';
import '../../share/share_strings.dart';
import '../achievement_models.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';

/// Tagesbilanz: one card (h 76) per newly earned medal, at most three, then
/// '+n'. One heavy haptic on first build. Tapping a card shares the medal
/// card (`ShareService.shareCard(ShareCardKind.medal)`).
///
/// [solid] = solid champagne cards (the default). The Tagesbilanz passes
/// `solid: false` when a record card is already on screen, so the medals
/// render as [CardTone.accent] wash cards and the screen keeps exactly one
/// solid champagne moment (docs/DESIGN.md §5).
class NewMedalsBanner extends ConsumerStatefulWidget {
  const NewMedalsBanner({super.key, required this.ids, this.max = 3, this.solid = true});
  final List<String> ids;
  final int max;
  final bool solid;

  @override
  ConsumerState<NewMedalsBanner> createState() => _NewMedalsBannerState();
}

class _NewMedalsBannerState extends ConsumerState<NewMedalsBanner> {
  @override
  void initState() {
    super.initState();
    if (widget.ids.isNotEmpty) {
      // Guarded: no platform channel in tests, no crash if the device refuses.
      try {
        unawaited(HapticFeedback.heavyImpact().catchError((_) {}));
      } catch (_) {
        // No haptics available (tests, simulator): ignore.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) return const SizedBox.shrink();
    final states = {for (final m in ref.watch(achievementsProvider).medals) m.def.id: m};
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final shown = widget.ids.take(widget.max).toList();
    final rest = widget.ids.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in shown) ...[
          _MedalCard(id: id, def: states[id]?.def, solid: widget.solid, onTap: states[id] == null ? null : () => _share(states[id]!)),
          const SizedBox(height: 8),
        ],
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(s.more(rest), style: AppText.numXs(c.accent)),
          ),
      ],
    );
  }

  Future<void> _share(MedalState state) async {
    final data = MedalCardData(def: state.def, earnedAt: state.earnedAt ?? DateTime.now().millisecondsSinceEpoch);
    try {
      await ref.read(shareServiceProvider).shareCard(context, ShareCardKind.medal, data);
    } catch (_) {
      // Share sheet dismissed or render failed: nothing to recover.
    }
  }
}

class _MedalCard extends StatelessWidget {
  const _MedalCard({required this.id, required this.def, required this.solid, this.onTap});
  final String id;
  final MedalDef? def;
  final bool solid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final d = def;
    final title = d == null ? id : s.medalTitle(d);
    // Caption = the medal's hint ('3 Skitage in Folge'), never a bare '3'.
    final caption = d == null ? null : s.medalHint(d);
    final overline = solid ? c.onAccent.withValues(alpha: 0.72) : c.textTertiary;
    final fg = solid ? c.onAccent : c.textPrimary;
    final captionColor = solid ? c.onAccent.withValues(alpha: 0.82) : c.textSecondary;
    final row = Row(
      children: [
        TierRing(tier: d?.tier ?? MedalTier.gold, size: 32, onInk: solid),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.newMedal.overline, style: AppText.label(overline)),
              const SizedBox(height: 3),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(fg)),
              if (caption != null) ...[
                const SizedBox(height: 1),
                Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(captionColor, size: 12)),
              ],
            ],
          ),
        ),
      ],
    );
    const padding = EdgeInsets.symmetric(horizontal: 18);
    return Semantics(
      label: ShareStrings.of(context).shareMedal,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          width: double.infinity,
          child: solid
              ? SurfaceCard(fill: c.accent, border: c.accent, radius: Tokens.r20, padding: padding, child: row)
              : AppCard(tone: CardTone.accent, radius: Tokens.r20, padding: padding, child: row),
        ),
      ),
    );
  }
}
