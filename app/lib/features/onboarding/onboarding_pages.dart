import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'mascot_hero.dart';
import 'onboarding_strings.dart';

/// Page 1 — full-bleed hero clip with a graphite gradient, copy sitting on top.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const MascotHero(),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, Tokens.pad, Tokens.pad, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MascotLine(text: s.p1Mascot),
                const SizedBox(height: 16),
                Text(s.p1Headline, style: AppText.headline(c.textPrimary)),
                const SizedBox(height: 12),
                Text(s.p1Body, style: AppText.bodyText(c.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Page 2 — three steps, plus the iOS status-pill mock.
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    return _PageScroll(
      children: [
        MascotCard(caption: s.p2Mascot),
        const SizedBox(height: 24),
        Text(s.p2Headline, style: AppText.headline(c.textPrimary)),
        const SizedBox(height: 20),
        _NumberedRow(index: 1, text: s.p2Row1),
        _NumberedRow(index: 2, text: s.p2Row2),
        _NumberedRow(index: 3, text: s.p2Row3),
        const SizedBox(height: 20),
        AppCard(
          child: Row(
            children: [
              _StatusPillMock(color: c.ice),
              const SizedBox(width: 12),
              Expanded(child: Text(s.p2Pill, style: AppText.bodyText(c.textSecondary, size: 15))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(s.p2Body, style: AppText.bodyText(c.textSecondary)),
      ],
    );
  }
}

/// Page 3 — what iOS will ask, in the order it asks it.
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({
    super.key,
    required this.denied,
    required this.granted,
    required this.grantedAlways,
    required this.onOpenSettings,
  });

  /// Location was refused — show the inline settings hint (onboarding still finishes).
  final bool denied;

  /// Location was granted (while-in-use or always).
  final bool granted;
  final bool grantedAlways;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    return _PageScroll(
      children: [
        MascotCard(caption: s.p3Mascot),
        const SizedBox(height: 24),
        Text(s.p3Headline, style: AppText.headline(c.textPrimary)),
        const SizedBox(height: 12),
        Text(s.p3Body, style: AppText.bodyText(c.textSecondary)),
        const SizedBox(height: 16),
        _IconRow(icon: Icons.location_on_rounded, text: s.p3ItemA),
        _IconRow(icon: Icons.lock_clock_rounded, text: s.p3ItemB),
        _IconRow(icon: Icons.speed_rounded, text: s.p3ItemC),
        if (denied) ...[
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_off_rounded, size: 18, color: c.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.denied, style: AppText.bodyText(c.textPrimary, size: 15))),
                  ],
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: s.openSettings,
                  icon: Icons.open_in_new_rounded,
                  height: 48,
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),
        ] else if (granted) ...[
          const SizedBox(height: 20),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    grantedAlways ? s.grantedAlways : s.grantedWhileInUse,
                    style: AppText.bodyText(c.textPrimary, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The mascot caption line as used on the hero page (MascotCard draws its own).
class MascotLine extends StatelessWidget {
  const MascotLine({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 16, color: c.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.bodyText(c.textPrimary, size: 16, weight: FontWeight.w600))),
      ],
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _NumberedRow extends StatelessWidget {
  const _NumberedRow({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.elevated, shape: BoxShape.circle, border: Border.all(color: c.hairline)),
            child: Text('$index', style: AppText.label(c.accent, size: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.bodyText(c.textPrimary, size: 16))),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.bodyText(c.textPrimary, size: 16))),
        ],
      ),
    );
  }
}

/// Tiny mock of the blue iOS location badge in the status bar.
class _StatusPillMock extends StatelessWidget {
  const _StatusPillMock({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.near_me_rounded, size: 14, color: Tokens.ink),
    );
  }
}
