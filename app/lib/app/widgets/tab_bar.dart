import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glyphs.dart';

class AppTab {
  const AppTab({required this.label, required this.glyph});
  final String label;
  final Glyph glyph;
}

/// Custom tab bar: glass, top hairline, 24×2 champagne bar above the selected
/// icon (no Material pill). [recording] pulses an ice ring around the first tab.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.tabs, required this.index, required this.onSelect, this.recording = false});
  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return GlassLayer(
      blur: true,
      opacity: 0.72,
      topHairline: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final (i, t) in tabs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: t.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: _TabItem(tab: t, selected: i == index, pulse: recording && i == 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({required this.tab, required this.selected, required this.pulse});
  final AppTab tab;
  final bool selected;
  final bool pulse;
  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Tokens.pulse);
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TabItem old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.pulse && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = widget.selected ? c.textPrimary : c.textTertiary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: Tokens.medium,
          width: 24,
          height: 2,
          decoration: BoxDecoration(color: widget.selected ? c.accent : Colors.transparent, borderRadius: BorderRadius.circular(1)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                FadeTransition(
                  opacity: Tween(begin: 0.25, end: 0.9).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutSine)),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.ice, width: 1.5))),
                ),
              GlyphIcon(widget.tab.glyph, size: 24, color: widget.pulse ? c.ice : fg),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(widget.tab.label, style: AppText.label(fg, size: 11).copyWith(letterSpacing: 0.66)),
      ],
    );
  }
}
