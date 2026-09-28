import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../../share/share_card_data.dart';
import '../../share/share_service.dart';
import '../../share/share_strings.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';
import 'medals_sheet.dart';

/// Top of the Rangliste tab: 64 pt level ring with the next-level line beside
/// it, LEVEL overline, points numeral, one caption ('Level nach km · Punkte
/// für die Rangliste') and a fixed three-column row SERIE · KM · MEDAILLEN.
/// The whole card opens [MedalsSheet]; the points formula lives there. The
/// level ring itself shares the level card (`ShareService.shareCard(ShareCardKind.level)`).
class AchievementsHeader extends ConsumerWidget {
  const AchievementsHeader({super.key, this.padding = const EdgeInsets.symmetric(horizontal: Tokens.pad)});
  final EdgeInsets padding;

  Future<void> _shareLevel(BuildContext context, WidgetRef ref) async {
    final level = ref.read(achievementsProvider).level;
    try {
      await ref.read(shareServiceProvider).shareCard(context, ShareCardKind.level, LevelCardData(level: level));
    } catch (_) {
      // Share sheet dismissed or render failed: nothing to recover.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final earned = a.earned.length;
    final nextAt = a.level.nextAtM;
    final nextLine = nextAt == null ? s.topLevel : s.nextLevelShort((nextAt - a.level.distanceM).clamp(0, double.infinity), a.level.index + 1);
    final streak = a.streak.current;
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: ShareStrings.of(context).shareLevel,
                      child: Pressable(
                        key: const ValueKey('achievements-level-ring'),
                        onTap: () => _shareLevel(context, ref),
                        child: LevelRing(level: a.level, size: 64),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.levelLine(a.level).overline, style: AppText.label(c.textSecondary)),
                          const SizedBox(height: 4),
                          Text(nextLine, style: AppText.caption(c.textSecondary, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                const SizedBox(height: 10),
                Text(s.levelCaption, style: AppText.caption(c.textTertiary, size: 12)),
                const SizedBox(height: 14),
                const Hairline(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HeaderStat(label: s.serie, value: streak > 0 ? '$streak' : s.dash, unit: streak > 0 ? s.unitDays(streak) : null),
                    ),
                    const _ColumnRule(),
                    Expanded(
                      child: _HeaderStat(
                        label: s.unitKm,
                        value: Fmt.km(a.distanceM, decimals: 0, locale: l.code),
                        unit: s.unitKm,
                      ),
                    ),
                    const _ColumnRule(),
                    Expanded(
                      child: _HeaderStat(label: s.medals, value: s.medalRatio(earned, a.medals.length)),
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
}

/// One header column: overline above, numeral + tertiary unit below.
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppText.numS(c.textPrimary)),
              if (unit != null) ...[const SizedBox(width: 4), Text(unit!, style: AppText.unit(c.textTertiary, size: 12))],
            ],
          ),
        ),
      ],
    );
  }
}

/// Vertical hairline between the three header columns.
class _ColumnRule extends StatelessWidget {
  const _ColumnRule();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: c.hairlineWidth,
        height: 36,
        child: DecoratedBox(decoration: BoxDecoration(color: c.hairline)),
      ),
    );
  }
}
