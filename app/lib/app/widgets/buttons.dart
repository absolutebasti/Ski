import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'glyphs.dart';

// One height ramp for every capsule (docs/DESIGN.md §4, .context/plan/buttons-audit.md):
//   Start 76 · Lg 60 (page / dock / single-purpose sheet) · Md 48 (cards,
//   multi-action sheets) · Sm 44 (inline beside text).
// Label, glyph, padding and gap follow the height, so two buttons of the same
// height always share one label size — whatever their variant.

/// Label size, glyph size, horizontal padding and glyph–label gap per height.
({double label, double icon, double pad, double gap}) buttonMetrics(double height) => switch (height) {
      >= 72 => (label: 19, icon: 24, pad: 28, gap: 10),
      >= 56 => (label: 17, icon: 20, pad: 24, gap: 8),
      >= 46 => (label: 16, icon: 20, pad: 20, gap: 8),
      _ => (label: 15, icon: 18, pad: 16, gap: 6),
    };

/// Leading glyph or icon at [size]. Custom glyphs get a 1.9 pt stroke at
/// 20 pt so they carry the same weight as the Inter 700 label beside them.
Widget? _leading(IconData? icon, Glyph? glyph, Color fg, double size) {
  if (glyph != null) return GlyphIcon(glyph, size: size, color: fg, strokeWidth: size * 0.095);
  if (icon != null) return Icon(icon, size: size, color: fg);
  return null;
}

/// Glyph + label, centred; long labels (1.3× text, German) scale down
/// instead of overflowing the capsule.
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, required this.fg, required this.height, this.icon, this.glyph, this.expand = false, this.weight});
  final String label;
  final Color fg;
  final double height;
  final IconData? icon;
  final Glyph? glyph;
  final bool expand;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    final m = buttonMetrics(height);
    final lead = _leading(icon, glyph, fg, m.icon);
    final style = AppText.button(fg, size: m.label);
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (lead != null) ...[lead, if (label.isNotEmpty) SizedBox(width: m.gap)],
        if (label.isNotEmpty)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: weight == null ? style : style.copyWith(fontWeight: weight), maxLines: 1),
            ),
          ),
      ],
    );
  }
}

/// Solid champagne capsule with an ink label. Heights ≥ 72 get the Start glow.
/// Pressed: accentPressed fill + 0.985 scale. Disabled: surfaceRaised fill,
/// hairline edge, quaternary label (docs/DESIGN.md §4).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.height = Tokens.buttonLg, this.icon, this.glyph, this.expand = true, this.glow});

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
    final fg = enabled ? c.onAccent : c.textQuaternary;
    final glowOn = enabled && (glow ?? height >= 72);
    return Pressable(
      onTap: onPressed,
      pressedOpacity: 1,
      child: Builder(
        builder: (context) {
          final pressed = Pressable.pressedOf(context);
          return AnimatedContainer(
            duration: Tokens.motion(context, Tokens.fast),
            curve: Curves.easeOut,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: buttonMetrics(height).pad),
            decoration: BoxDecoration(
              color: !enabled ? c.surfaceRaised : (pressed ? c.accentPressed : c.accent),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: enabled ? Colors.transparent : c.hairline, width: c.hairlineWidth),
              boxShadow: glowOn ? [BoxShadow(color: c.accentGlow, blurRadius: 32, spreadRadius: -6)] : null,
            ),
            child: _ButtonContent(label: label, fg: fg, height: height, icon: icon, glyph: glyph, expand: expand),
          );
        },
      ),
    );
  }
}

/// Glass capsule for secondary actions; [label] empty → square icon-only
/// circle (give it a [semanticsLabel]). [danger] = the destructive variant:
/// same glass, danger label and a danger-wash press.
/// Pressed: hairline fill + 0.985 scale. Disabled: no fill, hairline edge,
/// quaternary label — it must not read as a live control.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.glyph,
    this.height = Tokens.buttonLg,
    this.danger = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Glyph? glyph;
  final double height;
  final bool danger;

  /// Spoken label; required in practice for the icon-only variant.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final iconOnly = label.isEmpty;
    final fg = !enabled ? c.textQuaternary : (danger ? c.danger : c.textPrimary);
    final button = Pressable(
      onTap: onPressed,
      child: Builder(
        builder: (context) {
          final pressed = Pressable.pressedOf(context);
          final fill = !enabled ? Colors.transparent : (pressed ? (danger ? c.dangerWash : c.hairline) : c.glassFill);
          return AnimatedContainer(
            duration: Tokens.motion(context, Tokens.fast),
            curve: Curves.easeOut,
            height: height,
            width: iconOnly ? height : null,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : buttonMetrics(height).pad),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: enabled ? c.glassStroke : c.hairline, width: c.hairlineWidth),
            ),
            child: iconOnly
                ? Center(child: _leading(icon, glyph, fg, height >= 56 ? 24 : 20))
                : _ButtonContent(label: label, fg: fg, height: height, icon: icon, glyph: glyph),
          );
        },
      ),
    );
    if (semanticsLabel == null) return button;
    return Semantics(label: semanticsLabel, child: button);
  }
}

/// Tertiary text action: no fill, no border, secondary label (Inter 600); a
/// faint capsule shows only while pressed. For the quiet way out under a
/// primary — 'Überspringen', 'Kein Ziel', 'Nein danke', 'Abbrechen'.
/// Never smaller than the 44 pt tap target.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onPressed, this.icon, this.glyph, this.height = Tokens.buttonSm, this.danger = false, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Glyph? glyph;
  final double height;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final fg = !enabled ? c.textQuaternary : (danger ? c.danger : c.textSecondary);
    final h = height < Tokens.tapTarget ? Tokens.tapTarget : height;
    return Pressable(
      onTap: onPressed,
      child: Builder(
        builder: (context) {
          final pressed = Pressable.pressedOf(context);
          return AnimatedContainer(
            duration: Tokens.motion(context, Tokens.fast),
            curve: Curves.easeOut,
            height: h,
            constraints: const BoxConstraints(minWidth: Tokens.tapTarget),
            padding: EdgeInsets.symmetric(horizontal: buttonMetrics(h).pad),
            decoration: BoxDecoration(
              color: pressed ? (c.isDark ? c.glassFill : c.hairline.withValues(alpha: 0.5)) : Colors.transparent,
              borderRadius: BorderRadius.circular(h / 2),
            ),
            child: _ButtonContent(label: label, fg: fg, height: h, icon: icon, glyph: glyph, expand: expand, weight: FontWeight.w600),
          );
        },
      ),
    );
  }
}

/// 'Mit Apple anmelden': Apple's black style in dark (ink fill, cream label),
/// its white style in light (surface fill, ink label) — both with a 1 pt
/// hairlineStrong edge. The one capsule that is neither champagne nor glass.
class AppleButton extends StatelessWidget {
  const AppleButton({super.key, required this.label, this.onPressed, this.height = Tokens.buttonLg});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final fg = enabled ? c.textPrimary : c.textQuaternary;
    final m = buttonMetrics(height);
    return Pressable(
      onTap: onPressed,
      child: Builder(
        builder: (context) {
          final pressed = Pressable.pressedOf(context);
          final fill = c.isDark ? (pressed ? c.surface : c.ink) : (pressed ? c.bg : c.surface);
          return AnimatedContainer(
            duration: Tokens.motion(context, Tokens.fast),
            curve: Curves.easeOut,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: m.pad),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: c.hairlineStrong, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, color: fg, size: m.label + 5),
                SizedBox(width: m.gap + 2),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: AppText.button(fg, size: m.label), maxLines: 1))),
              ],
            ),
          );
        },
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
    this.semanticsHint,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration duration;
  final double height;
  final Color? color;
  /// Glyph inside the progress ring; the default stop draws the app's own
  /// stop glyph, any other icon is drawn as is (e.g. delete for Konto löschen).
  final IconData icon;
  /// Spoken hint after [label]; defaults to 'Halten' in a German locale, 'Hold' otherwise.
  final String? semanticsHint;

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
    final hint = widget.semanticsHint ?? (Localizations.maybeLocaleOf(context)?.languageCode == 'de' ? 'Halten' : 'Hold');
    // One button node: the label is painted twice (base + inverted sweep copy)
    // and would otherwise be read twice.
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      hint: hint,
      child: ExcludeSemantics(child: _buildBody(c, color, radius)),
    );
  }

  Widget _buildBody(AppColors c, Color color, BorderRadius radius) {
    final m = buttonMetrics(widget.height);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          Widget content(Color fg) => Padding(
                padding: EdgeInsets.symmetric(horizontal: m.pad),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(size: const Size(24, 24), painter: _RingPainter(t, fg, c.hairlineStrong)),
                          if (widget.icon == Icons.stop_rounded) GlyphIcon(Glyph.stop, size: 12, color: fg) else Icon(widget.icon, size: 14, color: fg),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(widget.label, style: AppText.button(fg, size: m.label), maxLines: 1),
                      ),
                    ),
                  ],
                ),
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
