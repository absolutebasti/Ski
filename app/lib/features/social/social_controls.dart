import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'social_models.dart';

/// Text tabs with a champagne underline — never a Material TabBar
/// (docs/DESIGN.md appendix: "text tabs with an underline in Rangliste").
class SocialSegmentTabs extends StatelessWidget {
  const SocialSegmentTabs({super.key, required this.labels, required this.index, required this.onSelect});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final (i, label) in labels.indexed)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: Pressable(
                    onTap: () => selectWithHaptic(() => onSelect(i)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppText.bodyText(i == index ? c.textPrimary : c.textTertiary, size: 16, weight: i == index ? FontWeight.w700 : FontWeight.w500),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Tokens.medium,
                          curve: Curves.easeOutCubic,
                          height: 2,
                          color: i == index ? c.accent : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Hairline(),
      ],
    );
  }
}

/// h 32 pill that can be tapped: selected = accent wash, else glass.
class SocialFilterChip extends StatelessWidget {
  const SocialFilterChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accentWash : c.glassFill,
            borderRadius: BorderRadius.circular(Tokens.rPill),
            border: Border.all(color: selected ? Colors.transparent : c.hairline, width: c.hairlineWidth),
          ),
          child: Text(label, style: AppText.label(selected ? c.accent : c.textSecondary, size: 12)),
        ),
      ),
    );
  }
}

/// One horizontally scrolling row of [SocialFilterChip]s. A 16 pt edge fade
/// on the side that still has chips off screen makes the row read as
/// scrollable (the metric row has six chips, a phone shows four).
class SocialChipRow extends StatefulWidget {
  const SocialChipRow({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Width of the fade at either edge.
  static const double fade = 16;

  @override
  State<SocialChipRow> createState() => _SocialChipRowState();
}

class _SocialChipRowState extends State<SocialChipRow> {
  final ScrollController _ctrl = ScrollController();
  bool _fadeLeft = false;
  bool _fadeRight = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_update);
    // The extent is known after the first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_update);
    _ctrl.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final left = pos.pixels > 1;
    final right = pos.maxScrollExtent - pos.pixels > 1;
    if (left != _fadeLeft || right != _fadeRight) setState(() { _fadeLeft = left; _fadeRight = right; });
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: widget.labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) =>
          SocialFilterChip(label: widget.labels[i], selected: i == widget.selected, onTap: () => selectWithHaptic(() => widget.onSelect(i))),
    );
    return SizedBox(
      height: 32,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _update();
          return false;
        },
        child: ChipRowFade(left: _fadeLeft, right: _fadeRight, child: list),
      ),
    );
  }
}

/// Fades [child] out over [SocialChipRow.fade] pt at the edges that are set —
/// a ShaderMask with dstIn so the page gradient shows through the fade.
class ChipRowFade extends StatelessWidget {
  const ChipRowFade({super.key, required this.left, required this.right, required this.child});
  final bool left;
  final bool right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!left && !right) return child;
    return ShaderMask(
      shaderCallback: (bounds) {
        final w = bounds.width <= 0 ? 1.0 : bounds.width;
        final f = (SocialChipRow.fade / w).clamp(0.0, 0.5);
        return LinearGradient(
          colors: [
            left ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            right ? Colors.transparent : Colors.white,
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(Offset.zero & bounds.size);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// h 32 pill that opens a picker: label + a small chevron, glass like an
/// unselected [SocialFilterChip] but with the label in primary. The Gebiet
/// chip of the Rangliste ('Gebiet: Kitzbühel ›').
class SocialPickerChip extends StatelessWidget {
  const SocialPickerChip({super.key, required this.label, this.onTap, this.semanticsLabel});

  final String label;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: BoxDecoration(
              color: c.glassFill,
              borderRadius: BorderRadius.circular(Tokens.rPill),
              border: Border.all(color: c.hairline, width: c.hairlineWidth),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(c.textPrimary, size: 12))),
                const SizedBox(width: 4),
                GlyphIcon(Glyph.chevronRight, size: 12, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 40 pt glass circle with the two-rider glyph and a count badge — the
/// 'Freunde' header action of the Rangliste. [pending] > 0 draws a champagne
/// badge with the number (capped at 9+). The circle mirrors `HeaderButton`,
/// which has no badge slot.
class FriendsHeaderButton extends StatelessWidget {
  const FriendsHeaderButton({super.key, required this.pending, this.onTap, this.label});

  final int pending;
  final VoidCallback? onTap;

  /// Accessibility label ('Freunde, 2 Anfragen').
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.glassFill, shape: BoxShape.circle, border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
                  child: Center(child: CustomPaint(size: const Size(20, 20), painter: FriendsGlyphPainter(c.textPrimary))),
                ),
              ),
              if (pending > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    key: const ValueKey('friends-badge'),
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.bg, width: 1.5)),
                    child: Text(pending > 9 ? '9+' : '$pending', style: AppText.numXs(c.onAccent).copyWith(fontSize: 11, height: 1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two riders side by side — a local glyph until `Glyph.friends` exists in
/// the app glyph set. 24-unit grid like `GlyphPainter`.
class FriendsGlyphPainter extends CustomPainter {
  FriendsGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 24 * 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Front rider: head + shoulders.
    canvas.drawCircle(Offset(9 * s, 8 * s), 3.5 * s, p);
    final front = Path()
      ..moveTo(3 * s, 20 * s)
      ..quadraticBezierTo(3 * s, 14 * s, 9 * s, 14 * s)
      ..quadraticBezierTo(15 * s, 14 * s, 15 * s, 20 * s);
    canvas.drawPath(front, p);
    // Second rider behind, half hidden.
    final back = Path()
      ..moveTo(16 * s, 5.2 * s)
      ..arcToPoint(Offset(16 * s, 11.3 * s), radius: Radius.circular(3.1 * s))
      ..moveTo(17.5 * s, 14.4 * s)
      ..quadraticBezierTo(21 * s, 15.5 * s, 21 * s, 20 * s);
    canvas.drawPath(back, p);
  }

  @override
  bool shouldRepaint(FriendsGlyphPainter old) => old.color != color;
}

/// selectionClick before a segment / chip selection (docs/DESIGN.md motion).
void selectWithHaptic(VoidCallback select) {
  unawaited(HapticFeedback.selectionClick());
  select();
}

/// Avatar: the rider's picture when [avatarUrl] loads, initials otherwise;
/// champagne ring for the leader.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 36, this.ring = false, this.accent = false, this.avatarUrl});

  final String name;
  final double size;
  final bool ring;
  final bool accent;

  /// https URL of the picture; null or a failed load → initials.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final initials = Text(
      initialsOf(name),
      style: AppText.label(accent ? c.accent : c.textSecondary, size: size * 0.34),
    );
    final url = avatarUrl;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent ? Color.alphaBlend(c.accentWash, c.surfaceRaised) : c.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: ring ? c.accent : c.hairline, width: ring ? 1.5 : c.hairlineWidth),
      ),
      child: url == null || url.isEmpty
          ? initials
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => initials,
            ),
    );
  }
}

/// Signed-out / not-opted-in / offline / empty: the Rider, one line, one action.
class SocialStateBlock extends StatelessWidget {
  const SocialStateBlock({
    super.key,
    required this.pose,
    required this.headline,
    required this.line,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// One of [Rider.poses].
  final String pose;
  final String headline;
  final String line;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Rider(pose: pose, size: 128)),
          const SizedBox(height: 16),
          Text(headline, style: AppText.headline(c.textPrimary)),
          const SizedBox(height: 10),
          RiderLine(line),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(label: actionLabel!, onPressed: onAction, height: 52, glow: false),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            SecondaryButton(label: secondaryLabel!, onPressed: onSecondary, height: 48),
          ],
        ],
      ),
    );
  }
}
