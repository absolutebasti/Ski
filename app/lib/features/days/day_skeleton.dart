import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import 'day_detail_screen.dart';

/// Placeholder rows while the Tage list loads: the shape of what is coming as
/// 6 %-opacity blocks (docs/DESIGN.md §5 — no spinner, no shimmer).
class DayListSkeleton extends StatelessWidget {
  const DayListSkeleton({super.key, this.rows = 3, this.header = true});

  /// Number of 112 pt list rows.
  final int rows;

  /// Draw the season-card and header blocks above the rows.
  final bool header;

  static const double rowHeight = 112;
  static const double cardHeight = 148;

  @override
  Widget build(BuildContext context) {
    final fill = _fill(context);
    return Semantics(
      label: 'Lädt',
      excludeSemantics: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 32),
        children: [
          if (header) ...[
            _Block(height: 34, width: 96, fill: fill, radius: Tokens.r10),
            const SizedBox(height: 24),
            _Block(height: cardHeight, fill: fill),
            const SizedBox(height: Tokens.sectionGap),
          ],
          for (var i = 0; i < rows; i++) ...[
            _Block(height: rowHeight, fill: fill),
            const SizedBox(height: Tokens.cardGap),
          ],
        ],
      ),
    );
  }
}

/// Placeholder for the Tag detail: the full-bleed map block, the 3-up and the
/// cards below it, all 6 % blocks.
class DayDetailSkeleton extends StatelessWidget {
  const DayDetailSkeleton({super.key, this.mapHeight = DayDetailScreen.heroHeight});

  final double mapHeight;

  @override
  Widget build(BuildContext context) {
    final fill = _fill(context);
    return Semantics(
      label: 'Lädt',
      excludeSemantics: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(height: mapHeight, color: fill),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 24, Tokens.pad, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: _Block(height: 64, fill: fill, radius: Tokens.r10)),
                    ],
                  ],
                ),
                const SizedBox(height: Tokens.sectionGap),
                _Block(height: 172, fill: fill),
                const SizedBox(height: Tokens.cardGap),
                _Block(height: 96, fill: fill),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _fill(BuildContext context) => AppColors.of(context).textPrimary.withValues(alpha: 0.06);

class _Block extends StatelessWidget {
  const _Block({required this.height, required this.fill, this.width, this.radius = Tokens.r20});
  final double height;
  final double? width;
  final Color fill;
  final double radius;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          width: width ?? double.infinity,
          decoration: ShapeDecoration(color: fill, shape: Squircle.plain(radius)),
        ),
      );
}
