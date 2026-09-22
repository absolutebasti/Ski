import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Big tabular number with a unit and a small uppercase label below.
class HeroNumber extends StatelessWidget {
  const HeroNumber({super.key, required this.value, required this.label, this.unit, this.size = 56, this.color, this.align = CrossAxisAlignment.start});

  final String value;
  final String label;
  final String? unit;
  final double size;
  final Color? color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppText.hero(color ?? c.textPrimary, size: size), maxLines: 1),
            if (unit != null) ...[const SizedBox(width: 6), Text(unit!, style: AppText.unit(c.textSecondary, size: size * 0.28))],
          ],
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: AppText.label(c.textSecondary)),
      ],
    );
  }
}

/// Compact stat: number + unit on one line, label below. Use in 2-column grids.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.unit, this.icon, this.onTap, this.highlight = false});

  final String value;
  final String label;
  final String? unit;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(color: highlight ? c.accent : c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(value, style: AppText.stat(highlight ? c.accent : c.textPrimary, size: 26), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (unit != null) ...[const SizedBox(width: 4), Text(unit!, style: AppText.unit(c.textSecondary, size: 13))],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 12, color: c.textSecondary), const SizedBox(width: 4)],
              Flexible(child: Text(label, style: AppText.label(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(Tokens.radius), onTap: onTap, child: body);
  }
}

/// Ski / Lift / Pause / Signalverlust proportions as one bar with a legend.
class StackedTimeBar extends StatelessWidget {
  const StackedTimeBar({
    super.key,
    required this.skiMs,
    required this.liftMs,
    required this.pauseMs,
    this.signalLossMs = 0,
    this.otherMs = 0,
    required this.labels,
    this.showLegend = true,
  });

  final int skiMs, liftMs, pauseMs, signalLossMs, otherMs;
  /// [ski, lift, pause, signalLoss] localized labels.
  final List<String> labels;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pause = pauseMs + otherMs;
    final total = (skiMs + liftMs + pause + signalLossMs).clamp(1, 1 << 62);
    final parts = <(int, Color, String)>[
      (skiMs, c.run, labels[0]),
      (liftMs, c.liftGrey, labels[1]),
      (pause, c.hairline, labels[2]),
      if (signalLossMs > 0) (signalLossMs, c.danger.withValues(alpha: 0.6), labels.length > 3 ? labels[3] : ''),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final p in parts)
                  if (p.$1 > 0) Expanded(flex: (p.$1 * 1000 / total).round().clamp(1, 1000), child: ColoredBox(color: p.$2)),
              ],
            ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final p in parts)
                if (p.$1 > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('${p.$3} ${_min(p.$1)}', style: AppText.label(c.textSecondary, size: 12)),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }

  static String _min(int ms) {
    final m = ms ~/ 60000;
    return m >= 60 ? '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
  }
}
