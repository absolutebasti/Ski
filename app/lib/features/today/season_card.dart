import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';

/// SAISON hero card: overline, 64 pt champagne vertical, 3-up footer and a
/// per-day bar sparkline bleeding to the card edges. `compact` = Tage variant.
class SeasonCard extends StatelessWidget {
  const SeasonCard({super.key, required this.totals, required this.days, this.previous, this.compact = false, this.goalHm});

  final SeasonTotals totals;
  /// Days of this season (any order) for the sparkline.
  final List<DaySummary> days;
  final SeasonTotals? previous;
  final bool compact;
  /// Season goal from onboarding (vertical metres); null hides the goal line.
  final int? goalHm;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final sorted = [...days]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final bars = sorted.map((d) => d.stats.dropM).toList();
    final delta = previous == null ? null : totals.dropM - previous!.dropM;
    return SurfaceCard(
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
                Text('${l.pick(de: 'Saison', en: 'Season')} ${totals.seasonKey}'.overline, style: AppText.label(c.textTertiary)),
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
                    Text(l.pick(de: 'hm', en: 'm'), style: AppText.unit(c.textTertiary, size: compact ? 14 : 20)),
                  ],
                ),
                if (delta != null && delta.abs() >= 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${delta >= 0 ? '+' : '−'}${Fmt.metres(delta.abs(), locale: l.code)} ${l.pick(de: 'zur Vorsaison', en: 'vs last season')}',
                    style: AppText.caption(delta >= 0 ? c.accent : c.textSecondary),
                  ),
                ],
                if (goalHm != null && goalHm! > 0) ...[
                  SizedBox(height: compact ? 10 : 14),
                  _GoalLine(dropM: totals.dropM, goalHm: goalHm!, compact: compact),
                ],
                SizedBox(height: compact ? 12 : 16),
                MetricStrip(
                  size: 22,
                  items: [
                    ('${totals.dayCount}', l.pick(de: totals.dayCount == 1 ? 'Tag' : 'Tage', en: totals.dayCount == 1 ? 'day' : 'days')),
                    ('${totals.runCount}', l.pick(de: 'Abfahrten', en: 'runs')),
                    (Fmt.kmh(totals.maxSpeedMs, locale: l.code), 'km/h top'),
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
              child: bars.length > 1 ? Sparkline(values: bars, color: c.accent, bars: true) : const SizedBox.shrink(),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
        ],
      ),
    );
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
    final frac = (dropM / goalHm).clamp(0.0, 1.0);
    final pct = (dropM / goalHm * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l.pick(de: 'Ziel', en: 'Goal')} ${Fmt.metres(goalHm.toDouble(), locale: l.code)} ${l.pick(de: 'hm', en: 'm')}'.overline,
                style: AppText.label(c.textTertiary),
              ),
            ),
            Text('$pct %', style: AppText.numXs(frac >= 1 ? c.accent : c.textSecondary)),
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
