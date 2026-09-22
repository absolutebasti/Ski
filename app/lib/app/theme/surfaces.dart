import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Apple-style squircle shape with a hairline border.
class Squircle {
  const Squircle._();

  static ShapeBorder border(double radius, {Color? side, double width = 0.5}) => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side == null ? BorderSide.none : BorderSide(color: side, width: width),
      );

  static ShapeBorder plain(double radius) => RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
}

/// L1 card surface: fill + hairline + a faint highlight on the top 24 px.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.radius = Tokens.r20,
    this.padding = const EdgeInsets.all(Tokens.cardPad),
    this.fill,
    this.border,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? fill;
  final Color? border;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      clipBehavior: clip,
      decoration: ShapeDecoration(
        color: fill ?? c.surface,
        shape: Squircle.border(radius, side: border ?? c.hairline, width: c.hairlineWidth),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: c.isDark ? 0.07 : 0.0), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// L2 floating layer (tab bar, sheets): blur + translucent fill + hairline.
/// Set [blur] false over moving content (live map) — solid 94 % fill instead.
class GlassLayer extends StatelessWidget {
  const GlassLayer({super.key, required this.child, this.blur = true, this.radius = 0, this.topHairline = false, this.opacity = 0.88});
  final Widget child;
  final bool blur;
  final double radius;
  final bool topHairline;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fill = c.surface.withValues(alpha: blur ? opacity : 0.94);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius > 0 ? BorderRadius.vertical(top: Radius.circular(radius)) : null,
        border: topHairline ? Border(top: BorderSide(color: c.glassStroke, width: c.hairlineWidth)) : null,
      ),
      child: child,
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: radius > 0 ? BorderRadius.vertical(top: Radius.circular(radius)) : BorderRadius.zero,
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: Tokens.glassBlur, sigmaY: Tokens.glassBlur), child: box),
    );
  }
}

/// Page background: 240 pt gradient from bgTop to bg, then flat.
class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.bgTop, c.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.32]),
      ),
      child: child,
    );
  }
}

/// 0.5 px (dark) / 1 px (light) divider.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.inset = 0});
  final double inset;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(padding: EdgeInsets.only(left: inset), child: SizedBox(height: c.hairlineWidth, child: ColoredBox(color: c.hairline)));
  }
}

/// 40×40 glass circle button used in headers and overlays.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({super.key, required this.icon, this.onTap, this.size = 40, this.iconSize = 20, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c.glassFill, shape: BoxShape.circle, border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
          child: Icon(icon, size: iconSize, color: c.textPrimary),
        ),
      ),
    );
    return b;
  }
}
