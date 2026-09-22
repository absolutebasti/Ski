import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum ChipTone { neutral, accent, ice, danger }

class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.text, this.tone = ChipTone.neutral, this.icon});
  final String text;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = switch (tone) {
      ChipTone.neutral => c.textSecondary,
      ChipTone.accent => c.accent,
      ChipTone.ice => c.ice,
      ChipTone.danger => c.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
          Text(text, style: AppText.label(color, size: 12)),
        ],
      ),
    );
  }
}

/// "● Aufnahme läuft · GPS gut" with a pulsing dot.
class RecordingPill extends StatefulWidget {
  const RecordingPill({super.key, required this.text, this.active = true});
  final String text;
  final bool active;
  @override
  State<RecordingPill> createState() => _RecordingPillState();
}

class _RecordingPillState extends State<RecordingPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Tokens.pulse)..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(999), border: Border.all(color: c.hairline)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: widget.active ? Tween(begin: 0.35, end: 1.0).animate(_c) : const AlwaysStoppedAnimation(1.0),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.active ? c.ice : c.textTertiary, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Text(widget.text, style: AppText.label(c.textPrimary, size: 12)),
        ],
      ),
    );
  }
}
