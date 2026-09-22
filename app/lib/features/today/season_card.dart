import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';

/// SAISON hero card: overline, 64 pt champagne vertical, 3-up footer and a
/// per-day bar sparkline bleeding to the card edges. `compact` = Tage variant.
class SeasonCard extends StatelessWidget {
  const SeasonCard({super.key, required this.totals, required this.days, this.previous, this.compact = false});

  final SeasonTotals totals;
  /// Days of this season (any order) for the sparkline.
  final List<DaySummary> days;
  final SeasonTotals? previous;
  final bool compact;

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
                    Text(Fmt.metres(totals.dropM, locale: l.code), style: (compact ? AppText.numL(c.accent) : AppText.numXl(c.accent))),
                    const SizedBox(width: 8),
                    Text(l.pick(de: 'hm', en: 'm'), style: AppText.unit(c.textTertiary, size: compact ? 14 : 20)),
                    if (delta != null && delta.abs() >= 1) ...[
                      const Spacer(),
                      Text(
                        '${delta >= 0 ? '+' : '−'}${Fmt.metres(delta.abs(), locale: l.code)} ${l.pick(de: 'zur Vorsaison', en: 'vs last season')}',
                        style: AppText.caption(delta >= 0 ? c.accent : c.textSecondary),
                      ),
                    ],
                  ],
                ),
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
