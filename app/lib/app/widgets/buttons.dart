import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'glyphs.dart';

/// Solid champagne capsule with an ink label. Heights ≥ 72 get the Start glow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.height = 60, this.icon, this.glyph, this.expand = true, this.glow});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;
  final Glyph? glyph;
  final bool expand;
  /// Defaults to true for the 76 pt Start button.
  final bool? glow;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final big = height >= 72;
    final fg = enabled ? c.onAccent : c.textQuaternary;
    final label = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (glyph != null) ...[GlyphIcon(glyph!, size: big ? 24 : 22, color: fg), const SizedBox(width: 10)],
        if (glyph == null && icon != null) ...[Icon(icon, color: fg, size: big ? 24 : 22), const SizedBox(width: 10)],
        Text(this.label, style: AppText.button(fg, size: big ? 19 : 17)),
      ],
    );
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: enabled ? c.accent : c.surfaceRaised,
          borderRadius: BorderRadius.circular(height / 2),
          border: enabled ? null : Border.all(color: c.hairline, width: c.hairlineWidth),
          boxShadow: enabled && (glow ?? big) ? [BoxShadow(color: c.accentGlow, blurRadius: 32, spreadRadius: -6)] : null,
        ),
        child: label,
      ),
    );
  }
}

/// Glass capsule for secondary actions; [label] empty → 56×56 icon-only.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.glyph, this.height = Tokens.minTarget, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Glyph? glyph;
  final double height;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = danger ? c.danger : c.textPrimary;
    final iconOnly = label.isEmpty;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        width: iconOnly ? height : null,
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 22),
        decoration: BoxDecoration(
          color: c.glassFill,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (glyph != null) GlyphIcon(glyph!, size: 20, color: fg),
            if (glyph == null && icon != null) Icon(icon, color: fg, size: 20),
            if (!iconOnly && (glyph != null || icon != null)) const SizedBox(width: 8),
            if (!iconOnly) Text(label, style: AppText.button(fg, size: 16)),
          ],
        ),
      ),
    );
  }
}

/// Press and hold for [duration]: a danger sweep fills from the left and the
/// label inverts at the sweep edge. Raw pointer events (glove-safe).
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
    ..addListener(_haptics)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        unawaited(HapticFeedback.heavyImpact());
        widget.onConfirmed();
        if (mounted) _ctrl.reset();
      }
    });
  bool _tick33 = false, _tick66 = false;

  void _haptics() {
    if (_ctrl.value > 0.33 && !_tick33) {
      _tick33 = true;
      unawaited(HapticFeedback.selectionClick());
    }
    if (_ctrl.value > 0.66 && !_tick66) {
      _tick66 = true;
      unawaited(HapticFeedback.selectionClick());
    }
    if (_ctrl.value < 0.05) _tick33 = _tick66 = false;
  }

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
    final radius = BorderRadius.circular(widget.height / 2);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          Widget content(Color fg) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: const Size(24, 24), painter: _RingPainter(t, fg, c.hairlineStrong)),
                        GlyphIcon(Glyph.stop, size: 12, color: fg),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.label, style: AppText.button(fg, size: 17)),
                ],
              );
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: radius,
              border: Border.all(color: Color.lerp(c.hairlineStrong, color, t)!, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, box) {
                  final sweep = box.maxWidth * t;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // base label
                      Center(child: content(c.textPrimary)),
                      // danger sweep with the inverted label clipped to it
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: sweep,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            maxWidth: box.maxWidth,
                            minWidth: box.maxWidth,
                            child: ColoredBox(
                              color: color,
                              child: Center(child: content(c.onAccent == c.bg ? Tokens.ink : c.onAccent)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.fg, this.track);
  final double t;
  final Color fg, track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1.25, 1.25, size.width - 2.5, size.height - 2.5);
    canvas.drawArc(r, 0, 6.2832, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawArc(r, -1.5708, 6.2832 * t, false, Paint()..color = fg..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t || old.fg != fg;
}
