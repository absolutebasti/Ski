import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../achievements/achievement_models.dart';
import '../achievements/ui/streak_chip.dart';
import '../share/share_card_data.dart';
import '../share/share_service.dart';
import 'season_goal_sheet.dart';
import 'today_strings.dart';

/// SAISON hero card: overline, 64 pt champagne vertical, 3-up footer and a
/// per-day bar sparkline bleeding to the card edges. `compact` = Tage variant.
///
/// Interactions: the share glyph (and a long press on the card) hands a
/// [SeasonCardData] to [ShareService]; a tap on the goal line opens
/// [SeasonGoalSheet]. Both read providers only on tap, so the card stays
/// cheap to pump.
class SeasonCard extends ConsumerWidget {
  const SeasonCard({super.key, required this.totals, required this.days, this.previous, this.compact = false, this.goalHm, this.streak, this.shareable = true});

  final SeasonTotals totals;
  /// Days of this season (any order) for the sparkline.
  final List<DaySummary> days;
  final SeasonTotals? previous;
  final bool compact;
  /// Season goal (vertical metres); null or ≤ 0 hides the goal line.
  final int? goalHm;
  /// Consecutive ski days; the chip shows from 2 (features/achievements).
  final StreakState? streak;
  /// Share glyph + long press; off for previews without a share sink.
  final bool shareable;

  /// The sparkline always gets at least this many slots, so a three-day season
  /// draws three thin bars and eleven empty stubs instead of three fat blocks.
  static const int minSlots = 14;

  /// Per-day vertical in date order, right-padded with zeros to [minSlots].
  static List<double> sparkValues(List<DaySummary> days) {
    final sorted = [...days]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final bars = sorted.map((d) => d.stats.dropM).toList();
    while (bars.length < minSlots) {
      bars.add(0);
    }
    return bars;
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(shareServiceProvider).shareCard(context, ShareCardKind.season, SeasonCardData.fromTotals(totals));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final bars = sparkValues(days);
    final delta = previous == null ? null : totals.dropM - previous!.dropM;
    final goal = goalHm;
    final card = SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 16 : 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${s.season} ${totals.seasonKey}'.overline, style: AppText.label(c.textTertiary))),
                    if (streak != null) StreakChip(streak: streak!, compact: true),
                    if (shareable) ...[
                      const SizedBox(width: 8),
                      HeaderButton(key: const ValueKey('season-share'), glyph: Glyph.share, tooltip: s.shareSeason, onTap: () => _share(context, ref)),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Flexible + FittedBox: a five-digit season never pushes the unit off the card.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(Fmt.metres(totals.dropM, locale: l.code), style: (compact ? AppText.numL(c.accent) : AppText.numXl(c.accent))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.unitHm, style: AppText.unit(c.textTertiary, size: compact ? 14 : 20)),
                  ],
                ),
                if (delta != null && delta.abs() >= 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${delta >= 0 ? '+' : '−'}${Fmt.metres(delta.abs(), locale: l.code)} ${l.pick(de: 'zur Vorsaison', en: 'vs last season')}',
                    style: AppText.caption(delta >= 0 ? c.accent : c.textSecondary),
                  ),
                ],
                if (goal != null && goal > 0) ...[
                  SizedBox(height: compact ? 10 : 14),
                  Semantics(
                    button: true,
                    label: s.editGoal,
                    child: Pressable(
                      key: const ValueKey('season-goal-line'),
                      onTap: () => SeasonGoalSheet.show(context),
                      child: _GoalLine(dropM: totals.dropM, goalHm: goal, compact: compact),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 12 : 16),
                MetricStrip(
                  size: 22,
                  items: [
                    ('${totals.dayCount}', l.pick(de: totals.dayCount == 1 ? 'Tag' : 'Tage', en: totals.dayCount == 1 ? 'day' : 'days')),
                    ('${totals.runCount}', s.runs),
                    (Fmt.kmh(totals.maxSpeedMs, locale: l.code), s.topSpeed),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          SizedBox(
            height: compact ? 28 : 36,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: days.isNotEmpty ? Sparkline(values: bars, color: c.accent, bars: true) : const SizedBox.shrink(),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
        ],
      ),
    );
    if (!shareable) return card;
    return GestureDetector(behavior: HitTestBehavior.deferToChild, onLongPress: () => _share(context, ref), child: card);
  }
}

/// 'ZIEL 20.000 HM · 29 %' + a 4 pt champagne progress rule.
class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.dropM, required this.goalHm, required this.compact});
  final double dropM;
  final int goalHm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = TodayStrings.of(context);
    final frac = (dropM / goalHm).clamp(0.0, 1.0);
    final pct = (dropM / goalHm * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${s.goal} ${Fmt.metres(goalHm.toDouble(), locale: l.code)} ${s.unitHm}'.overline,
                style: AppText.label(c.textTertiary),
              ),
            ),
            Text('$pct %', style: AppText.numXs(frac >= 1 ? c.accent : c.textSecondary)),
            const SizedBox(width: 6),
            GlyphIcon(Glyph.chevronRight, size: 12, color: c.textTertiary),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: c.accent.withValues(alpha: 0.16)),
                FractionallySizedBox(widthFactor: frac, child: Container(color: c.accent)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
