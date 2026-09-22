import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// The day's runs as a table (docs/DESIGN.md §5 "Tag — Detail", block 6):
/// rows of 56 pt, hairline-separated, four fixed columns that line up down the
/// whole list — `#7 · 09:21` | `312 hm` | `5,5 km` | `61 km/h`.
class RunList extends StatelessWidget {
  const RunList({super.key, required this.segments});

  final List<Segment> segments;

  static const double rowHeight = 56;
  static const double numberColumn = 52;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final runs = segments.where((x) => x.kind == SegmentKind.run).toList();
    if (runs.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(s.noRuns, style: AppText.bodyText(c.textSecondary, size: 15)),
      );
    }
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < runs.length; i++) ...[
            if (i > 0) const Hairline(inset: 16),
            _RunRow(run: runs[i], fallbackNumber: i + 1, s: s, l: l),
          ],
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.fallbackNumber, required this.s, required this.l});
  final Segment run;
  final int fallbackNumber;
  final DaysStrings s;
  final AppLocale l;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final number = run.runNumber ?? fallbackNumber;
    return Semantics(
      label: s.runLabel(number),
      child: SizedBox(
        height: RunList.rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: RunList.numberColumn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.runNo(number), style: AppText.numXs(c.textTertiary)),
                    const SizedBox(height: 3),
                    Text(Fmt.timeOfDay(run.startTs, locale: l.code), style: AppText.label(c.textQuaternary, size: 10)),
                  ],
                ),
              ),
              _Cell(value: Fmt.metres(run.dropM, locale: l.code), unit: s.unitHm),
              _Cell(value: Fmt.km(run.distanceM, locale: l.code), unit: s.unitKm),
              _Cell(value: Fmt.kmh(run.maxSpeedMs, locale: l.code), unit: s.unitKmh),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tabular column: numeral cream, unit tertiary, right-aligned so the
/// digits stack vertically down the table.
class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.unit});
  final String value, unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppText.numS(c.textPrimary)),
            const SizedBox(width: 4),
            Text(unit, style: AppText.unit(c.textTertiary, size: 11)),
          ],
        ),
      ),
    );
  }
}
