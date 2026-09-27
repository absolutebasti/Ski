import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/core.dart';
import '../achievement_models.dart';
import '../achievements_providers.dart';
import '../achievements_strings.dart';
import 'level_ring.dart';

/// Medaillen sheet: 96 pt level ring + next-level line, then one section per
/// metric with four tier tiles. Locked tiles sit at 45 % with a progress rule.
class MedalsSheet {
  const MedalsSheet._();

  /// Opacity of a locked tile (tests look for it).
  static const double lockedOpacity = 0.45;

  static Future<void> show(BuildContext context) => AppSheet.show<void>(
        context,
        expand: true,
        title: AchievementsStrings.of(context).medalsTitle,
        builder: (_) => const MedalsSheetBody(),
      );
}

/// Body of the sheet; exposed so the lead can embed it in a page if needed.
class MedalsSheetBody extends ConsumerWidget {
  const MedalsSheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final byMetric = <AchievementMetric, List<MedalState>>{};
    for (final m in a.medals) {
      byMetric.putIfAbsent(m.def.metric, () => []).add(m);
    }
    final nextAt = a.level.nextAtM;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.paddingOf(context).bottom + Tokens.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
            child: Row(
              children: [
                LevelRing(level: a.level, size: 96),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.level} ${a.level.index}'.overline, style: AppText.label(c.textTertiary)),
                      const SizedBox(height: 6),
                      Text(s.levelTitle(a.level), style: AppText.headline(c.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        nextAt == null ? s.topLevel : s.nextLevel((nextAt - a.level.distanceM).clamp(0, double.infinity), a.level.index + 1),
                        style: AppText.caption(c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final metric in AchievementMetric.values)
            if (byMetric[metric] case final medals?) ...[
              SectionLabel(
                s.metric(metric),
                padding: const EdgeInsets.fromLTRB(Tokens.pad, Tokens.sectionGap, Tokens.pad, 10),
                trailing: Text('${medals.where((m) => m.earned).length} / ${medals.length}', style: AppText.numXs(c.textSecondary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
                child: _TileRow(medals: medals),
              ),
            ],
        ],
      ),
    );
  }
}

/// Four tiles per row; a metric with fewer tiers keeps the column widths.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.medals});
  final List<MedalState> medals;

  @override
  Widget build(BuildContext context) {
    final rows = <List<MedalState>>[];
    for (var i = 0; i < medals.length; i += 4) {
      rows.add(medals.sublist(i, (i + 4).clamp(0, medals.length)));
    }
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: i < row.length ? MedalTile(state: row[i]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One medal: tier ring, title, threshold + unit, earned date or progress rule.
class MedalTile extends StatelessWidget {
  const MedalTile({super.key, required this.state});
  final MedalState state;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final def = state.def;
    final (value, unit) = s.threshold(def);
    final earnedAt = state.earnedAt;
    return Opacity(
      key: ValueKey('medal-${def.id}'),
      opacity: state.earned ? 1 : MedalsSheet.lockedOpacity,
      child: SurfaceCard(
        radius: Tokens.r14,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TierRing(tier: def.tier, earned: state.earned, size: 34),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Text(
                s.medalTitle(def),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(c.textPrimary, size: 12),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: AppText.numXs(c.textPrimary)),
                  if (unit != null) ...[const SizedBox(width: 3), Text(unit, style: AppText.unit(c.textTertiary, size: 11))],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (earnedAt != null)
              Text(Fmt.dateShort(earnedAt, locale: l.code), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(c.textSecondary, size: 11))
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(1.5),
                child: SizedBox(
                  height: 3,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(color: c.hairlineStrong),
                      FractionallySizedBox(widthFactor: state.progress.clamp(0.0, 1.0), child: Container(color: c.accent)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
