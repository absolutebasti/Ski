import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glyphs.dart';

/// Modal bottom sheet: r28, glass, handle, optional header row with close.
class AppSheet {
  const AppSheet._();

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool expand = false, bool dismissible = true, String? title}) {
    final c = AppColors.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: c.ink.withValues(alpha: 0.55),
      builder: (ctx) {
        final content = Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.hairlineStrong, borderRadius: BorderRadius.circular(2))),
            ),
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 14, Tokens.pad, 12),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AppText.headline(c.textPrimary))),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(ctx).maybePop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: c.glassFill, shape: BoxShape.circle, border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
                        child: Center(child: GlyphIcon(Glyph.close, size: 16, color: c.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
              const Hairline(),
            ],
            if (expand)
              Expanded(child: builder(ctx))
            else
              Flexible(child: Padding(padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, Tokens.pad), child: builder(ctx))),
          ],
        );
        return GlassLayer(
          radius: Tokens.r28,
          opacity: 0.92,
          child: SizedBox(height: expand ? MediaQuery.sizeOf(ctx).height * 0.92 : null, child: content),
        );
      },
    );
  }
}
