import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../onboarding/mascot_hero.dart';
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
                    onTap: () => onSelect(i),
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

/// One horizontally scrolling row of [SocialFilterChip]s.
class SocialChipRow extends StatelessWidget {
  const SocialChipRow({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SocialFilterChip(label: labels[i], selected: i == selected, onTap: () => onSelect(i)),
      ),
    );
  }
}

/// Avatar: initials in a circle, champagne ring for the leader.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 36, this.ring = false, this.accent = false});

  final String name;
  final double size;
  final bool ring;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent ? Color.alphaBlend(c.accentWash, c.surfaceRaised) : c.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: ring ? c.accent : c.hairline, width: ring ? 1.5 : c.hairlineWidth),
      ),
      child: Text(
        initialsOf(name),
        style: AppText.label(accent ? c.accent : c.textSecondary, size: size * 0.34),
      ),
    );
  }
}

/// Signed-out / not-opted-in / offline / empty: Leo, one line, one action.
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
          Center(child: Leo(pose: pose, size: 128)),
          const SizedBox(height: 16),
          Text(headline, style: AppText.headline(c.textPrimary)),
          const SizedBox(height: 10),
          MascotLine(line),
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
