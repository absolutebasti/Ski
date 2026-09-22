import 'package:flutter/material.dart';

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

/// Press feedback: scale 0.985 + opacity 0.9, 120 ms. No ripple.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.enabled = true});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: active ? widget.onTap : null,
      onLongPress: active ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: Tokens.fast,
        curve: Curves.easeOut,
        child: AnimatedOpacity(opacity: _down ? 0.9 : 1, duration: Tokens.fast, child: widget.child),
      ),
    );
  }
}
