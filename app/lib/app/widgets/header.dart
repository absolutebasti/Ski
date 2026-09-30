import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'glyphs.dart';

/// Screen head: display title 30 + caption, trailing glass circle(s).
/// Use as the first sliver child or a plain widget above a scroll view.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.caption, this.trailing, this.leading, this.padding = const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 16)});
  final String title;
  final String? caption;
  final List<Widget>? trailing;
  final Widget? leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.displayTitle(c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (caption != null) ...[const SizedBox(height: 4), Text(caption!, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            for (final (i, w) in trailing!.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
          ],
        ],
      ),
    );
  }
}

/// Glass circle with a glyph — header actions, overlays (40 pt, glyph 20) and
/// sheet / strip close or share controls ([size] 32, glyph 16). Taps land up
/// to the 44 pt target around it ([HitSlop]); press = Pressable scale + a
/// hairline fill; without [onTap] the glyph dims to quaternary.
class HeaderButton extends StatelessWidget {
  const HeaderButton({super.key, required this.glyph, this.onTap, this.tooltip, this.size = 40});
  final Glyph glyph;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return HitSlop(
      child: Semantics(
        button: true,
        label: tooltip,
        enabled: enabled ? null : false,
        child: Pressable(
          onTap: onTap,
          semantics: false,
          child: Builder(
            builder: (context) {
              final pressed = Pressable.pressedOf(context);
              return AnimatedContainer(
                duration: Tokens.motion(context, Tokens.fast),
                curve: Curves.easeOut,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: pressed ? c.hairline : c.glassFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
                ),
                child: Center(child: GlyphIcon(glyph, size: size >= 40 ? 20 : 16, color: enabled ? c.textPrimary : c.textQuaternary)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Trailing chevron of anything that opens something: 16 pt tertiary on a
/// row or card (docs/DESIGN.md §7 "16 chevrons"), [inline] 12 pt beside
/// caption / overline text. [color] only for chevrons over imagery.
class RowChevron extends StatelessWidget {
  const RowChevron({super.key, this.inline = false, this.color});
  final bool inline;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      GlyphIcon(Glyph.chevronRight, size: inline ? 12 : 16, color: color ?? AppColors.of(context).textTertiary);
}

/// Overline section title with optional trailing tabular text.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(Tokens.pad, Tokens.sectionGap, Tokens.pad, 8)});
  final String text;
  final Widget? trailing;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: padding,
      // Dynamic Type: the overline keeps its intrinsic width (min 96 pt stay
      // reserved for the trailing), a long trailing (season totals) wraps inside
      // the rest instead of overflowing. Align (not textAlign) keeps the 1×
      // pixels identical to the old unbounded layout.
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final titleMax = !w.isFinite ? double.infinity : (trailing == null ? w : (w - 12 - 96).clamp(0.0, w));
          return Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: titleMax),
                child: Text(text.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bottom action dock (L2): solid 94 % surface, top hairline, safe-area padding.
class BottomDock extends StatelessWidget {
  const BottomDock({super.key, required this.child, this.blur = false});
  final Widget child;
  final bool blur;
  @override
  Widget build(BuildContext context) {
    return GlassLayer(
      blur: blur,
      topHairline: true,
      opacity: 0.94,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(Tokens.pad, 16, Tokens.pad, 16), child: child),
      ),
    );
  }
}
