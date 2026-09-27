import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../achievement_models.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';

/// Tagesbilanz: one solid champagne card (h 76) per newly earned medal,
/// at most three, then '+n'. One heavy haptic on first build.
class NewMedalsBanner extends ConsumerStatefulWidget {
  const NewMedalsBanner({super.key, required this.ids, this.max = 3});
  final List<String> ids;
  final int max;

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
    final defs = {for (final m in ref.watch(achievementsProvider).medals) m.def.id: m.def};
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final shown = widget.ids.take(widget.max).toList();
    final rest = widget.ids.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in shown) ...[
          _MedalCard(id: id, def: defs[id]),
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
}

class _MedalCard extends StatelessWidget {
  const _MedalCard({required this.id, required this.def});
  final String id;
  final MedalDef? def;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final d = def;
    final title = d == null ? id : s.medalTitle(d);
    final threshold = d == null ? null : s.threshold(d);
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: SurfaceCard(
        fill: c.accent,
        border: c.accent,
        radius: Tokens.r20,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            TierRing(tier: d?.tier ?? MedalTier.gold, size: 32, onInk: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.newMedal.overline, style: AppText.label(c.onAccent.withValues(alpha: 0.72))),
                  const SizedBox(height: 4),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(c.onAccent)),
                ],
              ),
            ),
            if (threshold != null) ...[
              const SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(threshold.$1, style: AppText.numS(c.onAccent)),
                  if (threshold.$2 != null) ...[const SizedBox(width: 4), Text(threshold.$2!, style: AppText.unit(c.onAccent.withValues(alpha: 0.72), size: 11))],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
