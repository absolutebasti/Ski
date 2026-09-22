import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';

/// Full-width mascot card: 16:9 still with an ink gradient, headline, body, action.
/// `EmptyState(line:)` (v1 signature) still works and renders the compact form.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.line,
    this.asset = 'assets/mascot/toni-still.jpg',
    this.size = 120,
    this.headline,
    this.actionLabel,
    this.onAction,
  });
  final String line;
  final String asset;
  final double size;
  final String? headline;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.r28),
      child: Stack(
        children: [
          AspectRatio(aspectRatio: 16 / 10, child: Image.asset(asset, fit: BoxFit.cover)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, c.ink.withValues(alpha: 0.55), c.ink.withValues(alpha: 0.96)], stops: const [0.25, 0.6, 1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (headline != null) ...[Text(headline!, style: AppText.headline(Tokens.textPrimary)), const SizedBox(height: 8)],
                Text(line, style: AppText.bodyText(Tokens.textSecondary, size: 15)),
                if (actionLabel != null) ...[
                  const SizedBox(height: 16),
                  PrimaryButton(label: actionLabel!, onPressed: onAction, height: 52, expand: false, glow: false),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
