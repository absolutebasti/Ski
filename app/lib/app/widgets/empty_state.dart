import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Mascot still + one sentence. Used on Heute (no data) and Tage (empty).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.line, this.asset = 'assets/mascot/toni-square.jpg', this.size = 120});
  final String line;
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(line, textAlign: TextAlign.center, style: AppText.bodyText(c.textSecondary, size: 16)),
        ),
      ],
    );
  }
}
