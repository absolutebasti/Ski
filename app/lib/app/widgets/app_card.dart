import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

enum CardTone { plain, accent, ice, danger }

/// L1 card: surface fill, hairline, top highlight, squircle r20. Optional
/// [tone] wash, [header] overline and press feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.cardPad),
    this.onTap,
    this.onLongPress,
    this.elevated = false,
    this.tone = CardTone.plain,
    this.header,
    this.trailing,
    this.radius = Tokens.r20,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool elevated;
  final CardTone tone;
  /// Uppercase overline drawn above [child].
  final String? header;
  final Widget? trailing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (fill, border) = switch (tone) {
      CardTone.plain => (elevated ? c.surfaceRaised : c.surface, c.hairline),
      CardTone.accent => (Color.alphaBlend(c.accentWash, c.surface), c.accent.withValues(alpha: 0.45)),
      CardTone.ice => (Color.alphaBlend(c.iceWash, c.surface), c.ice.withValues(alpha: 0.4)),
      CardTone.danger => (Color.alphaBlend(c.dangerWash, c.surface), c.danger.withValues(alpha: 0.45)),
    };
    final body = SurfaceCard(
      radius: radius,
      padding: padding,
      fill: fill,
      border: border,
      child: header == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(header!.overline, style: AppText.label(c.textTertiary))),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
    );
    if (onTap == null && onLongPress == null) return body;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

/// Press feedback: scale 0.985 + opacity 0.9, 120 ms. No ripple. The one
/// press motion of the app — every tappable control goes through it.
/// Descendants read the pressed state with [Pressable.pressedOf] (the
/// buttons darken their fill with it); [pressedOpacity] 1 keeps the scale
/// only (the solid champagne CTA, whose pressed state is a fill change).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.enabled = true, this.pressedOpacity = 0.9, this.semantics = true});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double pressedOpacity;

  /// False when the caller already describes the node (its own button /
  /// label Semantics): only the tap action is contributed then.
  final bool semantics;

  /// True while a finger is down on the nearest enclosing [Pressable].
  static bool pressedOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_PressedScope>()?.pressed ?? false;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    if (!active) _down = false; // disabled mid-press: no stuck pressed state later
    final down = _down;
    final press = Tokens.motion(context, Tokens.fast); // zero under reduced motion
    final gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _set(true) : null,
      // Always registered: a disabled button still swallows its tap instead of
      // passing it to a tappable card behind it.
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: active ? widget.onTap : null,
      onLongPress: active ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: down ? 0.985 : 1,
        duration: press,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: down ? widget.pressedOpacity : 1,
          duration: press,
          child: _PressedScope(pressed: down, child: widget.child),
        ),
      ),
    );
    if (!widget.semantics) return gesture;
    return Semantics(button: active, enabled: active, child: gesture);
  }
}

class _PressedScope extends InheritedWidget {
  const _PressedScope({required this.pressed, required super.child});
  final bool pressed;
  @override
  bool updateShouldNotify(_PressedScope old) => old.pressed != pressed;
}

/// Grows the hit area of a small control to [minSize] (44 pt) on each axis
/// without changing its layout: a 32 pt chip or a 40 pt glass circle keeps
/// its pixels but takes taps up to 6 / 2 pt outside its edge. Hits inside the
/// slop are forwarded to the child at the nearest point of its bounds. Must
/// be the outermost widget of the control (a wrapper around it clips the
/// slop to its own size again).
class HitSlop extends SingleChildRenderObjectWidget {
  const HitSlop({super.key, this.minSize = Tokens.tapTarget, required Widget super.child});
  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitSlop(minSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderHitSlop).minSize = minSize;
}

class _RenderHitSlop extends RenderProxyBox {
  _RenderHitSlop(this.minSize);
  double minSize;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final dx = ((minSize - size.width) / 2).clamp(0.0, double.infinity);
    final dy = ((minSize - size.height) / 2).clamp(0.0, double.infinity);
    if (!Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy).contains(position)) return false;
    // Size.contains is exclusive at the far edge: stay a hair inside.
    final inside = Offset(
      position.dx.clamp(0.0, (size.width - 0.01).clamp(0.0, double.infinity)),
      position.dy.clamp(0.0, (size.height - 0.01).clamp(0.0, double.infinity)),
    );
    if (hitTestChildren(result, position: inside) || hitTestSelf(inside)) {
      result.add(BoxHitTestEntry(this, inside));
      return true;
    }
    return false;
  }
}
