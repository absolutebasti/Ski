import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';

/// Segmented control (docs/DESIGN.md §5 Rangliste 2.): h 40 capsule track in
/// glass, the selected segment a raised pill (hairlineStrong in dark, white
/// with a hairline edge in light) that slides 200 ms; selected label cream
/// Inter 700, the others secondary Inter 600 — every segment reads as a
/// button, not as plain text. Used for Saison · Monat · Woche and the
/// Einstellungen rows (System · Hell · Dunkel, Sprache). 44 pt hit area.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.value, this.onChanged, this.height = 40});

  /// (value, label) pairs, left to right.
  final List<(T, String)> options;
  final T value;

  /// Null = shown but switched off (no pointer, no haptic).
  final ValueChanged<T>? onChanged;
  final double height;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final n = options.length;
    final index = options.indexWhere((o) => o.$1 == value);
    final track = c.isDark ? c.glassFill : c.hairline.withValues(alpha: 0.55);
    final thumb = c.isDark ? c.hairlineStrong : c.surface;
    final inner = height - 2 * _inset;
    return HitSlop(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(_inset),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: c.glassStroke, width: c.hairlineWidth),
        ),
        child: Stack(
          children: [
            if (index >= 0)
              AnimatedAlign(
                alignment: Alignment(n <= 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                duration: Tokens.motion(context, const Duration(milliseconds: 200)),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(inner / 2),
                      border: Border.all(color: c.isDark ? c.glassStroke : c.hairlineStrong, width: c.hairlineWidth),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                for (final (i, o) in options.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      inMutuallyExclusiveGroup: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onChanged == null
                            ? null
                            : () {
                                if (i != index) unawaited(HapticFeedback.selectionClick());
                                onChanged!(o.$1);
                              },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedDefaultTextStyle(
                                duration: Tokens.motion(context, const Duration(milliseconds: 200)),
                                style: i == index
                                    ? AppText.button(c.textPrimary, size: 15)
                                    : AppText.button(c.textSecondary, size: 15).copyWith(fontWeight: FontWeight.w600),
                                child: Text(o.$2, maxLines: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS-proportioned switch, 51 × 31 with a 27 pt thumb: champagne track with
/// an ink thumb when on (the CTA pairing), hairlineStrong track with a grey
/// thumb when off (white thumb on a hairline track in light). No Material
/// thumb, outline or ripple; 200 ms slide, 44 pt hit area, dims when
/// [onChanged] is null.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Size size = Size(51, 31);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onChanged != null;
    final d = Tokens.motion(context, const Duration(milliseconds: 200));
    final track = value ? c.accent : (c.isDark ? c.hairlineStrong : c.hairline);
    final thumb = value ? c.onAccent : (c.isDark ? c.textSecondary : c.surface);
    return HitSlop(
      child: Semantics(
        toggled: value,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: d,
              curve: Curves.easeOut,
              width: size.width,
              height: size.height,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(size.height / 2)),
              child: AnimatedAlign(
                duration: d,
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: d,
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: thumb,
                    shape: BoxShape.circle,
                    border: c.isDark || value ? null : Border.all(color: c.hairlineStrong, width: c.hairlineWidth),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
