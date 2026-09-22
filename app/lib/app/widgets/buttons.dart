import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Champagne capsule with ink label — the one primary action per screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.height = Tokens.minTarget, this.icon, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, color: enabled ? c.onAccent : c.textTertiary, size: 22), const SizedBox(width: 10)],
        Text(label, style: AppText.button(enabled ? c.onAccent : c.textTertiary)),
      ],
    );
    return _Pressable(
      onPressed: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: enabled ? Tokens.champagneGradient : null,
          color: enabled ? null : c.elevated,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: child,
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.height = Tokens.minTarget});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _Pressable(
      onPressed: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(color: c.elevated, borderRadius: BorderRadius.circular(height / 2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: c.textPrimary, size: 20), const SizedBox(width: 8)],
            Text(label, style: AppText.button(c.textPrimary, size: 16)),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onPressed});
  final Widget child;
  final VoidCallback? onPressed;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: Tokens.fast,
        child: AnimatedOpacity(opacity: _down ? 0.85 : 1, duration: Tokens.fast, child: widget.child),
      ),
    );
  }
}

/// Press and hold for [duration]; a ring fills, then [onConfirmed] fires with a heavy haptic.
/// Used for "Tag beenden" so a glove cannot end the day by accident.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.duration = Tokens.hold,
    this.height = Tokens.holdButton,
    this.color,
    this.icon = Icons.stop_rounded,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration duration;
  final double height;
  final Color? color;
  final IconData icon;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        unawaited(HapticFeedback.heavyImpact());
        widget.onConfirmed();
        if (mounted) _ctrl.reset();
      }
    });

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    unawaited(HapticFeedback.selectionClick());
    _ctrl.forward(from: 0);
  }

  void _cancel() {
    if (!mounted) return;
    if (_ctrl.status != AnimationStatus.completed) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = widget.color ?? c.danger;
    // Raw pointer events: no gesture arena, so a long hold with a glove is never
    // cancelled by a competing long-press recogniser.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(color: Color.lerp(c.hairline, color, _ctrl.value)!, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _ctrl.value,
                      child: Container(color: color.withValues(alpha: 0.28)),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: _ctrl.value, strokeWidth: 2.5, color: color, backgroundColor: c.hairline),
                        Icon(widget.icon, size: 12, color: c.textPrimary),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.label, style: AppText.button(c.textPrimary, size: 17)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
