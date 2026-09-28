import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';

/// Placeholder while the day loads: the shape of the Tagesbilanz as
/// 6 %-opacity skeleton blocks (docs/DESIGN.md — no spinner, no shimmer).
/// Local to the summary feature until the lead promotes it to lib/app/widgets.
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key, this.rows = 3});

  /// Number of card-sized rows under the top block.
  final int rows;

  /// Height of the full-bleed top block placeholder.
  static const double topHeight = 300;

  /// Height of one skeleton row.
  static const double rowHeight = 112;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fill = c.textPrimary.withValues(alpha: 0.06);
    return Semantics(
      label: 'Lädt',
      excludeSemantics: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(height: topHeight, color: fill),
          const SizedBox(height: 28),
          for (var i = 0; i < rows; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
              child: Container(
                height: rowHeight,
                decoration: ShapeDecoration(color: fill, shape: Squircle.plain(Tokens.r20)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
