import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// The eight numbers below the time bar (docs/PLAN.md §3 row "Tag", block 5).
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.detail});

  final DayDetail detail;

  /// Biggest single run drop of the day, metres.
  static double longestRunDropM(DayDetail d) {
    var best = 0.0;
    for (final r in d.runs) {
      if (r.dropM > best) best = r.dropM;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = detail.day.stats;
    final high = st.maxAltM, low = st.minAltM;
    final tiles = <Widget>[
      StatTile(value: Fmt.km(st.skiDistanceM, locale: l.code), unit: s.unitKm, label: s.skiKm),
      StatTile(value: Fmt.km(st.liftDistanceM, locale: l.code), unit: s.unitKm, label: s.liftKm),
      StatTile(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitHm, label: s.drop),
      StatTile(value: Fmt.metres(st.ascentM, locale: l.code), unit: s.unitHm, label: s.ascent),
      StatTile(value: Fmt.kmh(st.avgSkiSpeedMs, locale: l.code), unit: s.unitKmh, label: s.avgSkiSpeed),
      StatTile(value: Fmt.metres(longestRunDropM(detail), locale: l.code), unit: s.unitHm, label: s.longestRun),
      StatTile(
        value: high == null || low == null ? '—' : '${Fmt.metres(high, locale: l.code)}/${Fmt.metres(low, locale: l.code)}',
        unit: high == null || low == null ? null : s.unitM,
        label: s.highLow,
      ),
      StatTile(value: '${st.liftCount}', label: s.lifts),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: tiles,
    );
  }
}
