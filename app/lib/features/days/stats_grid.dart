import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// The eight numbers below the time bar (docs/DESIGN.md §5 "Tag — Detail",
/// block 5): a 2×4 grid of 88 pt tiles with the overline above the numeral, so
/// all eight baselines line up.
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.detail});

  final DayDetail detail;

  static const double tileHeight = 88;

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
      StatTile(value: Fmt.km(st.skiDistanceM, locale: l.code), unit: s.unitKm, label: s.skiKm, size: 28),
      StatTile(value: Fmt.km(st.liftDistanceM, locale: l.code), unit: s.unitKm, label: s.liftKm, size: 28),
      StatTile(value: Fmt.metres(st.dropM, locale: l.code), unit: s.unitHm, label: s.drop, size: 28),
      StatTile(value: Fmt.metres(st.ascentM, locale: l.code), unit: s.unitHm, label: s.ascent, size: 28),
      StatTile(value: Fmt.kmh(st.avgSkiSpeedMs, locale: l.code), unit: s.unitKmh, label: s.avgSkiSpeedShort, size: 28),
      StatTile(value: Fmt.metres(longestRunDropM(detail), locale: l.code), unit: s.unitHm, label: s.longestRun, size: 28),
      StatTile(
        value: high == null || low == null ? '–' : '${Fmt.metres(high, locale: l.code)}/${Fmt.metres(low, locale: l.code)}',
        unit: high == null || low == null ? null : s.unitM,
        label: s.highLowShort,
        size: 24,
      ),
      StatTile(value: '${st.liftCount}', label: s.lifts, size: 28),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: Tokens.cardGap,
        crossAxisSpacing: Tokens.cardGap,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (context, i) => tiles[i],
    );
  }
}
