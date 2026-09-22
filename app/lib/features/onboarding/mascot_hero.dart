import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';

/// The snow leopard. Transparent cut-outs (tools/assets/cutout_leopard.py),
/// so the figure sits directly on the page without a halo.
class Leo extends StatelessWidget {
  const Leo({super.key, this.pose = 'head', this.size = 160});
  final String pose;
  final double size;

  String get _asset => 'assets/mascot/leo-$pose.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Image.asset('assets/mascot/leo-head.png', fit: BoxFit.contain),
      ),
    );
  }
}

/// Mascot speech line: waveform glyph + one sentence.
class MascotLine extends StatelessWidget {
  const MascotLine(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.graphic_eq_rounded, size: 16, color: c.accent)),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: Tokens.medium,
            child: Text(text, key: ValueKey(text), style: AppText.bodyStrong(c.textPrimary, size: 15)),
          ),
        ),
      ],
    );
  }
}
