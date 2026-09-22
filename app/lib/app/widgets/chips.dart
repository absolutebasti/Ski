import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum ChipTone { neutral, accent, ice, danger }

/// h 32 pill. neutral = glass + hairline; tones = 10–12 % wash, no border.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.text, this.tone = ChipTone.neutral, this.icon, this.child});
  final String text;
  final ChipTone tone;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (fill, fg, border) = switch (tone) {
      ChipTone.neutral => (c.glassFill, c.textSecondary, c.hairline),
      ChipTone.accent => (c.accentWash, c.accent, Colors.transparent),
      ChipTone.ice => (c.iceWash, c.ice, Colors.transparent),
      ChipTone.danger => (c.dangerWash, c.danger, Colors.transparent),
    };
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: border, width: c.hairlineWidth)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null) ...[child!, const SizedBox(width: 6)],
          if (child == null && icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
          Text(text, style: AppText.label(fg, size: 12)),
        ],
      ),
    );
  }
}

/// "● Aufnahme läuft · GPS gut" — h 34 glass pill with a pulsing ice dot.
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
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeInOutSine);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: c.glassFill, borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: widget.active ? Tween(begin: 0.35, end: 1.0).animate(anim) : const AlwaysStoppedAnimation(1.0),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.active ? c.ice : c.textTertiary, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Text(widget.text, style: AppText.label(c.textPrimary, size: 12)),
        ],
      ),
    );
  }
}
