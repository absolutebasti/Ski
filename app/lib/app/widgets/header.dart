import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
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

/// 40 pt glass circle with a glyph — header actions, overlays.
class HeaderButton extends StatelessWidget {
  const HeaderButton({super.key, required this.glyph, this.onTap, this.tooltip});
  final Glyph glyph;
  final VoidCallback? onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.glassFill, shape: BoxShape.circle, border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
          child: Center(child: GlyphIcon(glyph, size: 20, color: c.textPrimary)),
        ),
      ),
    );
  }
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
      child: Row(
        children: [
          Expanded(child: Text(text.overline, style: AppText.label(c.textTertiary))),
          ?trailing,
        ],
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
