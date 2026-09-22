import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'sparkline.dart';

/// Overline ABOVE the numeral, unit baseline-aligned beside it.
/// Sizes: 92 (xxl) · 64 (xl) · 44 (l) · 34 (m) · 22 (s) · 15 (xs).
class HeroNumber extends StatelessWidget {
  const HeroNumber({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.size = 64,
    this.color,
    this.align = CrossAxisAlignment.start,
    this.tick = false,
  });

  final String value;
  final String label;
  final String? unit;
  final double size;
  final Color? color;
  final CrossAxisAlignment align;
  /// 28×2 champagne tick rule above the overline.
  final bool tick;

  static TextStyle numeralStyle(Color c, double size) => switch (size) {
        >= 80 => AppText.numXxl(c),
        >= 56 => AppText.numXl(c),
        >= 40 => AppText.numL(c),
        >= 28 => AppText.numM(c),
        >= 18 => AppText.numS(c),
        _ => AppText.numXs(c),
      }
          .copyWith(fontSize: size);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final numeral = color ?? c.textPrimary;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tick) ...[Container(width: 28, height: 2, color: c.accent), const SizedBox(height: 10)],
        Text(label.overline, style: AppText.label(c.textTertiary)),
        SizedBox(height: size >= 56 ? 10 : 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(value, style: numeralStyle(numeral, size), maxLines: 1, overflow: TextOverflow.clip)),
            if (unit != null) ...[const SizedBox(width: 6), Text(unit!, style: AppText.unit(c.textTertiary, size: AppText.unitFor(size)))],
          ],
        ),
      ],
    );
  }
}

enum TileTone { plain, accent, ice }

/// 88 pt stat tile: overline on top, numeric-m + unit at the bottom. Two per row.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.icon,
    this.onTap,
    this.highlight = false,
    this.tone,
    this.sparkline,
    this.size = 34,
  });

  final String value;
  final String label;
  final String? unit;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlight;
  final TileTone? tone;
  final List<double>? sparkline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = tone ?? (highlight ? TileTone.accent : TileTone.plain);
    final numeral = switch (t) { TileTone.accent => c.accent, TileTone.ice => c.ice, TileTone.plain => c.textPrimary };
    final border = switch (t) { TileTone.accent => c.accent.withValues(alpha: 0.5), TileTone.ice => c.ice.withValues(alpha: 0.4), TileTone.plain => c.hairline };
    final fill = switch (t) { TileTone.accent => Color.alphaBlend(c.accent.withValues(alpha: 0.06), c.surface), TileTone.ice => Color.alphaBlend(c.iceWash, c.surface), TileTone.plain => c.surface };
    final body = SurfaceCard(
      radius: Tokens.r14,
      padding: const EdgeInsets.all(14),
      fill: fill,
      border: border,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[Icon(icon, size: 12, color: c.textTertiary), const SizedBox(width: 4)],
                    Flexible(child: Text(label.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: Text(value, style: AppText.numM(numeral).copyWith(fontSize: size), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (unit != null) ...[const SizedBox(width: 5), Text(unit!, style: AppText.unit(c.textTertiary, size: 13))],
                  ],
                ),
              ],
            ),
            if (sparkline != null && sparkline!.length > 1)
              Positioned(right: 0, bottom: 0, width: 72, height: 28, child: Opacity(opacity: 0.6, child: Sparkline(values: sparkline!, color: numeral))),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

/// Three equal-width value/overline pairs in one row (list rows, PB strip, footers).
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.items, this.size = 15, this.color, this.alignEnd = false});
  /// (value, unitOrLabel) — the second string is drawn as an overline.
  final List<(String, String)> items;
  final double size;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        for (final (i, it) in items.indexed)
          Expanded(
            child: Column(
              crossAxisAlignment: alignEnd && i == items.length - 1 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.$1, style: HeroNumber.numeralStyle(color ?? c.textPrimary, size), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(it.$2.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
      ],
    );
  }
}

/// Personal-best tile: h 64, accent wash, overline + numeric-s champagne.
class PbTile extends StatelessWidget {
  const PbTile({super.key, required this.label, required this.value, this.unit, this.onTap});
  final String label;
  final String value;
  final String? unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: Color.alphaBlend(c.accent.withValues(alpha: 0.08), c.surface),
        shape: Squircle.border(Tokens.r14, side: c.accent.withValues(alpha: 0.45), width: c.hairlineWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(value, style: AppText.numS(c.accent), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (unit != null) ...[const SizedBox(width: 4), Text(unit!, style: AppText.unit(c.textTertiary, size: 11))],
            ],
          ),
        ],
      ),
    );
    return onTap == null ? body : GestureDetector(onTap: onTap, child: body);
  }
}

/// Ski / Lift / Pause / Signalverlust as one 12 pt bar with 2 pt gaps + legend.
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
      (liftMs, c.lift, labels[1]),
      (pause, c.hairlineStrong, labels[2]),
      if (signalLossMs > 0) (signalLossMs, c.signalLoss, labels.length > 3 ? labels[3] : ''),
    ].where((p) => p.$1 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 12,
          child: Row(
            children: [
              for (final (i, p) in parts.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (p.$1 * 1000 / total).round().clamp(1, 1000),
                  child: DecoratedBox(decoration: BoxDecoration(color: p.$2, borderRadius: BorderRadius.circular(6))),
                ),
              ],
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in parts)
                Expanded(
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$2, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(children: [
                            TextSpan(text: _min(p.$1), style: AppText.numXs(c.textPrimary)),
                            TextSpan(text: '  ${p.$3.overline}', style: AppText.label(c.textTertiary, size: 10)),
                          ]),
                        ),
                      ),
                    ],
                  ),
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
