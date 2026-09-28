import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../achievement_models.dart';
import '../achievements_strings.dart';

/// Streak chip without a flame: the small chevron mark + '3 Tage am Stück'.
/// Renders nothing below 2 days. `compact` = 26 pt version for the season card.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak, this.compact = false});
  final StreakState streak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (streak.current < 2) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    return Container(
      height: compact ? 26 : 32,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: BoxDecoration(color: c.accentWash, borderRadius: BorderRadius.circular(Tokens.rPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphIcon(Glyph.chevron, size: compact ? 10 : 12, color: c.accent),
          SizedBox(width: compact ? 6 : 8),
          Text(s.streak(streak.current), style: AppText.label(c.accent, size: compact ? 11 : 12)),
        ],
      ),
    );
  }
}
