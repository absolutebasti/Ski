import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The mascot: a rider in an all-black outfit with a mirrored gold visor.
/// Faceless, minimal, adult. Assets are transparent cut-outs in
/// `assets/mascot/rider-<pose>.png` (tools/assets/generate_rider.py).
///
/// Poses: `hero` (standing on skis, poles planted), `lean` (leaning on crossed
/// poles), `carve` (mid-turn, side view), `celebrate` (poles raised),
/// `point` (pointing at the viewer), `look` (head and shoulders, visor).
class Rider extends StatelessWidget {
  const Rider({super.key, this.pose = 'hero', this.size = 160, this.alignment = Alignment.bottomCenter});
  final String pose;
  final double size;
  final Alignment alignment;

  static const poses = ['hero', 'lean', 'carve', 'celebrate', 'point', 'look'];

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/mascot/rider-$pose.png',
          fit: BoxFit.contain,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/mascot/rider-hero.png',
            fit: BoxFit.contain,
            alignment: alignment,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
}

/// One-line mascot statement: a 2 pt champagne tick + sentence. No speech
/// bubble, no waveform — the rider does not chat, he states.
class RiderLine extends StatelessWidget {
  const RiderLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 11), child: Container(width: 20, height: 2, color: c.accent)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.bodyStrong(c.textPrimary))),
      ],
    );
  }
}
