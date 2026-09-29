import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'rider.dart';

/// Empty state in the Rider pattern: surface card, the rider (pose selectable),
/// headline, one statement line, optional primary action. `asset` and `size`
/// stay for source compatibility (`size` scales the rider).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.line,
    this.asset = '',
    this.size = 132,
    this.headline,
    this.actionLabel,
    this.onAction,
    this.pose = 'hero',
  });
  final String line;
  /// Ignored since the rider replaced the photo; kept so old call sites compile.
  final String asset;
  final double size;
  final String? headline;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String pose;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Rider(pose: pose, size: size)),
          const SizedBox(height: 16),
          if (headline != null) ...[Text(headline!, style: AppText.headline(c.textPrimary)), const SizedBox(height: 8)],
          RiderLine(line),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(label: actionLabel!, onPressed: onAction, height: 52, glow: false),
          ],
        ],
      ),
    );
  }
}
