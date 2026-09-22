import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// 'Abfahrt 7 · 10:42 · 312 hm · 2,1 km · 61 km/h · 14 %' — one row per run,
/// in the order they were skied.
class RunList extends StatelessWidget {
  const RunList({super.key, required this.segments});

  final List<Segment> segments;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final runs = segments.where((x) => x.kind == SegmentKind.run).toList();
    if (runs.isEmpty) {
      return Text(s.noRuns, style: AppText.bodyText(c.textSecondary, size: 15));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < runs.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.hairline),
          _RunRow(run: runs[i], fallbackNumber: i + 1, s: s, l: l),
        ],
      ],
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
    final line = s.runLine(
      number: run.runNumber ?? fallbackNumber,
      clock: Fmt.timeOfDay(run.startTs, locale: l.code),
      dropM: Fmt.metres(run.dropM, locale: l.code),
      km: Fmt.km(run.distanceM, locale: l.code),
      kmh: Fmt.kmh(run.maxSpeedMs, locale: l.code),
      gradient: Fmt.percent(run.avgGradientPct.abs(), locale: l.code),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(line, style: AppText.bodyText(c.textPrimary, size: 15)),
    );
  }
}
