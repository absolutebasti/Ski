import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glyphs.dart';
import 'header.dart';

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
              // The 32 pt glass circle (spec) sits in a real 44 × 44 tap box;
              // the padding gives back the 6 pt so the pixels stay where the
              // 20 / 14 / 12 insets put them.
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad - 6, 6),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AppText.headline(c.textPrimary))),
                    const SizedBox(width: 6),
                    SizedBox.square(
                      dimension: Tokens.tapTarget,
                      child: Center(
                        child: HeaderButton(
                          glyph: Glyph.close,
                          size: 32,
                          tooltip: MaterialLocalizations.of(ctx).closeButtonLabel,
                          onTap: () => Navigator.of(ctx).maybePop(),
                        ),
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
