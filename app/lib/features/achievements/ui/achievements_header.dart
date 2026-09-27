import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';
import 'medals_sheet.dart';
import 'streak_chip.dart';

/// Top of the Rangliste tab: 64 pt level ring, LEVEL overline, points
/// numeral, chips (streak, km, medal count) and the points formula.
/// The whole card opens [MedalsSheet].
class AchievementsHeader extends ConsumerWidget {
  const AchievementsHeader({super.key, this.padding = const EdgeInsets.symmetric(horizontal: Tokens.pad)});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final earned = a.earned.length;
    return Padding(
      padding: padding,
      child: Semantics(
        label: s.openMedals,
        child: Pressable(
          onTap: () => MedalsSheet.show(context),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LevelRing(level: a.level, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.levelLine(a.level).overline, style: AppText.label(c.textSecondary)),
                          const SizedBox(height: 10),
                          Text(s.points.overline, style: AppText.label(c.textTertiary)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(Fmt.metres(a.points.toDouble(), locale: l.code), style: AppText.numL(c.accent)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StreakChip(streak: a.streak),
                    StateChip(text: '${Fmt.km(a.distanceM, decimals: 0, locale: l.code)} ${s.unitKm}'),
                    StateChip(text: s.medalCount(earned, a.medals.length)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.formula, style: AppText.caption(c.textTertiary, size: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
