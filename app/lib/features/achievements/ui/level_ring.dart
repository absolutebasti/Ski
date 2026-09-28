import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../achievement_models.dart';
import '../achievements_strings.dart';

/// Level ring: champagne arc = `level.progress` on a dim track, a disc in the
/// centre with the level index. 64 pt in the header, 96 pt in the medals
/// sheet. The top level draws a full ring.
///
/// The disc is ink in the dark theme and the raised surface in the light one,
/// so the numeral (textPrimary) is always visible on it.
class LevelRing extends StatelessWidget {
  const LevelRing({super.key, required this.level, this.size = 64});
  final LevelState level;
  final double size;

  /// Disc colour behind the numeral (exposed for tests).
  static Color discColor(AppColors c) => c.isDark ? c.ink : c.surfaceRaised;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AchievementsStrings.of(context);
    final stroke = size / 16;
    final progress = level.nextAtM == null ? 1.0 : level.progress.clamp(0.0, 1.0);
    final inner = size - stroke * 2 - 6;
    return Semantics(
      label: s.levelSemantics(level),
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _LevelRingPainter(progress: progress, arc: c.accent, track: c.accent.withValues(alpha: 0.16), stroke: stroke),
          child: Center(
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(color: discColor(c), shape: BoxShape.circle),
              alignment: Alignment.center,
              padding: EdgeInsets.all(inner * 0.16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${level.index}', style: size >= 96 ? AppText.numL(c.textPrimary) : AppText.numM(c.textPrimary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelRingPainter extends CustomPainter {
  const _LevelRingPainter({required this.progress, required this.arc, required this.track, required this.stroke});
  final double progress;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (progress <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) => old.progress != progress || old.arc != arc || old.track != track || old.stroke != stroke;
}

/// Tier colours (docs/GAMIFICATION.md §4): bronze, silver, gold = accent,
/// black = ink with a champagne hairline.
Color tierColor(AppColors c, MedalTier tier) => switch (tier) {
      MedalTier.bronze => const Color(0xFFB08D57),
      MedalTier.silver => const Color(0xFFC9CDD3),
      MedalTier.gold => c.accent,
      MedalTier.black => c.ink,
    };

/// Tier ring: a circle in the tier colour. Earned = solid disc with a small
/// ink core; locked = stroke only. Black tier keeps a champagne hairline so it
/// reads on the ink surface.
class TierRing extends StatelessWidget {
  const TierRing({super.key, required this.tier, this.earned = true, this.size = 36, this.onInk = false});
  final MedalTier tier;
  final bool earned;
  final double size;
  /// Drawn on a champagne surface (banner): ink stroke instead of the tier colour.
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final colour = onInk ? c.onAccent : tierColor(c, tier);
    final border = tier == MedalTier.black && !onInk ? c.accent : colour;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? colour : Colors.transparent,
        border: Border.all(color: border, width: earned ? (tier == MedalTier.black ? 1.0 : 2.0) : 1.5),
      ),
      child: earned
          ? Center(
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tier == MedalTier.black && !onInk ? c.accent : (onInk ? c.accent : c.ink)),
              ),
            )
          : null,
    );
  }
}
