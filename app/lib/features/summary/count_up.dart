import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';

/// Staggered count-up of the Tagesbilanz numbers (docs/DESIGN.md §6):
/// 400 ms easeOutCubic each, 90 ms apart, driven by one controller so the
/// whole thing settles in tests and honours reduce-motion.
const Duration kCountUpStagger = Duration(milliseconds: 90);

Duration countUpTotal(int steps) =>
    Tokens.countUp + kCountUpStagger * (steps - 1 < 0 ? 0 : steps - 1);

/// Slice [index] of [steps] out of a controller running for [countUpTotal].
Animation<double> countUpStep(AnimationController controller, int index, int steps) {
  final total = countUpTotal(steps).inMilliseconds;
  final start = (kCountUpStagger.inMilliseconds * index) / total;
  final end = (kCountUpStagger.inMilliseconds * index + Tokens.countUp.inMilliseconds) / total;
  return CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOutCubic));
}

/// A [HeroNumber] whose value counts up from zero along [animation].
class CountUpNumber extends StatelessWidget {
  const CountUpNumber({
    super.key,
    required this.animation,
    required this.value,
    required this.format,
    required this.label,
    this.unit,
    this.size = 56,
    this.color,
  });

  final Animation<double> animation;
  final double value;
  final String Function(double) format;
  final String label;
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: HeroNumber(
            value: format(value * animation.value),
            unit: unit,
            label: label,
            size: size,
            color: color,
          ),
        ),
      );
}
