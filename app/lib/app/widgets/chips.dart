import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';

enum ChipTone { neutral, accent, ice, danger }

/// h 32 pill. neutral = glass + hairline; tones = 10–12 % wash, no border.
/// Icon 14 + 6 pt gap, text 13 Inter 600 (sentence case — no overline
/// tracking). With [onTap] it is a selectable chip: press feedback and a
/// 44 pt hit area around the 32 pt pill.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.text, this.tone = ChipTone.neutral, this.icon, this.child, this.onTap, this.selected});
  final String text;
  final ChipTone tone;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;

  /// Reported to assistive tech when the chip is one of a choice group.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (fill, fg, border) = switch (tone) {
      ChipTone.neutral => (c.glassFill, c.textSecondary, c.hairline),
      ChipTone.accent => (c.accentWash, c.accent, Colors.transparent),
      ChipTone.ice => (c.iceWash, c.ice, Colors.transparent),
      ChipTone.danger => (c.dangerWash, c.danger, Colors.transparent),
    };
    final pill = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: border, width: c.hairlineWidth)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null) ...[child!, const SizedBox(width: 6)],
          if (child == null && icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
          // Flexible: a chip squeezed by its parent (Row inside a sheet at
          // phone width) ellipsises instead of overflowing.
          Flexible(child: Text(text, style: AppText.chip(fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    if (onTap == null && selected == null) return pill;
    return HitSlop(child: Semantics(selected: selected, child: Pressable(onTap: onTap, child: pill)));
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
  late final AnimationController _c = AnimationController(vsync: this, duration: Tokens.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant RecordingPill old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  /// The dot pulses only while [RecordingPill.active] and motion is allowed;
  /// otherwise the controller rests at 1 (full opacity, no ticker).
  void _syncPulse() {
    if (widget.active && !Tokens.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 1;
    }
  }

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
          Text(widget.text, style: AppText.chip(c.textPrimary, size: 12, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
