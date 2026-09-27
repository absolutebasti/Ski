import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import 'onboarding_countries.dart';
import 'onboarding_strings.dart';
import 'route_hook.dart';

/// Shared page skeleton: headline (34 on P1, 22 on P2/P3) + one line, then content.
/// No mascot chat line — the rider, if present, stands beside the headline.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.headline, required this.body, required this.child, this.large = false, this.trailing});
  final String headline;
  final String body;
  final Widget child;
  final bool large;
  /// Right-aligned figure beside the headline (P1: `Rider(pose: 'hero')`).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(headline, style: large ? AppText.headlineL(c.textPrimary) : AppText.headline(c.textPrimary)),
        const SizedBox(height: 10),
        Text(body, style: AppText.bodyText(c.textSecondary)),
      ],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 24),
      children: [
        if (trailing == null)
          head
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: head), const SizedBox(width: 8), trailing!],
          ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

/// Page 1 — the hook: the route draws itself over three numerals that count up once.
class HookPage extends StatelessWidget {
  const HookPage({super.key, this.animate = true});
  final bool animate;

  static const int runs = 12;
  static const double dropM = 4120;
  static const double topKmh = 68;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    return OnboardingPage(
      large: true,
      headline: s.p1Headline,
      body: s.p1Body,
      trailing: const Rider(pose: 'hero', size: 96),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteHook(height: 130, animate: animate),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: animate ? 0 : 1, end: 1),
              duration: Tokens.routeDraw,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: HeroNumber(value: '${(runs * t).round()}', label: s.p1Runs, size: 30)),
                  Expanded(child: HeroNumber(value: Fmt.metres(dropM * t, locale: l.code), label: s.p1Vertical, unit: s.unitHm, size: 30)),
                  Expanded(child: HeroNumber(value: '${(topKmh * t).round()}', label: s.p1TopSpeed, unit: s.unitKmh, size: 30)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 2 — the team: five country tiles + 'Anderes', and an optional home resort.
class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key, required this.countryCode, required this.onCountry, required this.resortId, required this.onResort});
  /// Selected ISO-3166 alpha-2 (may be a sheet country), null = nothing chosen.
  final String? countryCode;
  final ValueChanged<String> onCountry;
  final String? resortId;
  final ValueChanged<Resort> onResort;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  bool _resortOpen = false;
  String _query = '';

  Future<void> _pickOther() async {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final sorted = [...kOtherCountries]..sort((a, b) => a.name(l).compareTo(b.name(l)));
    final code = await AppSheet.show<String>(
      context,
      title: s.p2OtherTitle,
      expand: true,
      builder: (ctx) => _OtherCountrySheet(countries: sorted, selected: widget.countryCode),
    );
    if (code == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onCountry(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final other = isGridCountry(widget.countryCode) ? null : teamCountry(widget.countryCode);
    final tiles = <Widget>[
      for (final k in kTeamCountries)
        _CountryTile(
          key: ValueKey('onboarding-country-${k.code}'),
          flag: k.flag,
          name: k.name(l),
          selected: widget.countryCode == k.code,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            widget.onCountry(k.code);
          },
        ),
      _CountryTile(
        key: const ValueKey('onboarding-country-other'),
        flag: other?.flag,
        name: other?.name(l) ?? s.p2Other,
        selected: other != null,
        onTap: _pickOther,
      ),
    ];
    return OnboardingPage(
      headline: s.p2Headline,
      body: s.p2Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: tiles[row * 2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _ResortSection(
            open: _resortOpen,
            query: _query,
            selectedId: widget.resortId,
            onToggle: () => setState(() => _resortOpen = !_resortOpen),
            onQuery: (v) => setState(() => _query = v),
            onResort: widget.onResort,
          ),
        ],
      ),
    );
  }
}

/// Large country tile: flag + name, champagne ring when selected.
class _CountryTile extends StatelessWidget {
  const _CountryTile({super.key, required this.flag, required this.name, required this.selected, required this.onTap});
  final String? flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      label: name,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            color: selected ? Color.alphaBlend(c.accentWash, c.surface) : c.surface,
            shape: Squircle.border(Tokens.r20, side: selected ? c.accent : c.hairline, width: selected ? 2 : c.hairlineWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (flag != null)
                Text(flag!, style: const TextStyle(fontSize: 30, height: 1.1))
              else
                Icon(Icons.more_horiz_rounded, size: 30, color: c.textSecondary),
              const SizedBox(height: 6),
              Text(name, style: AppText.bodyStrong(c.textPrimary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 'Anderes' list: one row per country, tap returns the code.
class _OtherCountrySheet extends StatelessWidget {
  const _OtherCountrySheet({required this.countries, required this.selected});
  final List<TeamCountry> countries;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, Tokens.pad),
      itemCount: countries.length,
      separatorBuilder: (_, _) => const Hairline(),
      itemBuilder: (context, i) {
        final k = countries[i];
        final on = k.code == selected;
        return Pressable(
          key: ValueKey('onboarding-country-${k.code}'),
          onTap: () => Navigator.of(context).pop(k.code),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Text(k.flag, style: const TextStyle(fontSize: 24, height: 1.1)),
                const SizedBox(width: 14),
                Expanded(child: Text(k.name(l), style: AppText.bodyText(on ? c.accent : c.textPrimary, size: 16, weight: on ? FontWeight.w600 : FontWeight.w400))),
                Text(k.code, style: AppText.label(c.textTertiary)),
                if (on) ...[const SizedBox(width: 10), Icon(Icons.check_rounded, size: 18, color: c.accent)],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Collapsed row 'Heimatgebiet wählen (optional)' → resort search + list.
class _ResortSection extends ConsumerWidget {
  const _ResortSection({
    required this.open,
    required this.query,
    required this.selectedId,
    required this.onToggle,
    required this.onQuery,
    required this.onResort,
  });
  final bool open;
  final String query;
  final String? selectedId;
  final VoidCallback onToggle;
  final ValueChanged<String> onQuery;
  final ValueChanged<Resort> onResort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final repo = ref.watch(resortRepositoryProvider).asData?.value;
    final all = repo?.all ?? const <Resort>[];
    final q = query.trim().toLowerCase();
    final list = (q.isEmpty ? all : all.where((r) => r.name.toLowerCase().contains(q))).toList()..sort((a, b) => a.name.compareTo(b.name));
    final selected = selectedId == null ? null : repo?.byId(selectedId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: onToggle,
          child: Container(
            key: const ValueKey('onboarding-resort-toggle'),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(color: c.glassFill, shape: Squircle.border(Tokens.r14, side: c.glassStroke, width: c.hairlineWidth)),
            child: Row(
              children: [
                GlyphIcon(Glyph.map, size: 20, color: selected == null ? c.textTertiary : c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: selected == null
                      ? Text(s.p2Resort, style: AppText.bodyText(c.textSecondary, size: 15, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.p2ResortLabel.overline, style: AppText.label(c.textTertiary)),
                            const SizedBox(height: 2),
                            Text(selected.name, style: AppText.bodyStrong(c.textPrimary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                ),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: Tokens.medium,
                  child: GlyphIcon(Glyph.chevronRight, size: 18, color: c.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 10),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(color: c.surface, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('onboarding-resort-search'),
                    autofocus: true,
                    onChanged: onQuery,
                    style: AppText.bodyText(c.textPrimary, size: 16),
                    cursorColor: c.accent,
                    decoration: InputDecoration.collapsed(hintText: s.p2Search, hintStyle: AppText.bodyText(c.textTertiary, size: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 200,
              child: list.isEmpty
                  ? Center(child: Text(s.p2NoMatch, style: AppText.caption(c.textTertiary)))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Hairline(inset: 16),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        final on = r.id == selectedId;
                        return Pressable(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            onResort(r);
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: on ? c.accentWash : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(child: Text(r.name, style: AppText.bodyText(on ? c.accent : c.textPrimary, size: 16, weight: on ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text(r.country, style: AppText.label(c.textTertiary)),
                                if (on) ...[const SizedBox(width: 10), Icon(Icons.check_rounded, size: 18, color: c.accent)],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hook for tests: the sign-in action the flow uses.
final onboardingSignInProvider = Provider<Future<AuthUser?> Function()>((ref) => ref.read(authServiceProvider).signInWithApple);

/// Black capsule with the Apple logo — the only control that is not champagne.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.label, this.onPressed, this.height = 60});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    final fg = enabled ? c.textPrimary : c.textQuaternary;
    return Pressable(
      onTap: onPressed,
      child: Container(
        key: const ValueKey('onboarding-apple'),
        height: height,
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: c.hairlineStrong, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, color: fg, size: 24),
            const SizedBox(width: 10),
            Text(label, style: AppText.button(fg)),
          ],
        ),
      ),
    );
  }
}

/// Page 3 — ready: account state, then what iOS will ask.
class ReadyPage extends StatelessWidget {
  const ReadyPage({
    super.key,
    required this.user,
    required this.skipped,
    required this.failed,
    required this.denied,
    required this.granted,
    required this.grantedAlways,
    required this.onOpenSettings,
  });
  final AuthUser? user;
  final bool skipped;
  final bool failed;
  final bool denied;
  final bool granted;
  final bool grantedAlways;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final Widget account;
    if (user != null) {
      account = AppCard(
        tone: CardTone.accent,
        header: s.p3Account,
        child: _IconLine(icon: Icons.check_circle_rounded, color: c.accent, title: s.p3SignedIn(user!.displayName), caption: s.p3Benefit),
      );
    } else if (skipped) {
      account = AppCard(
        header: s.p3Account,
        child: _IconLine(icon: Icons.person_outline_rounded, color: c.textTertiary, title: s.p3Skipped, caption: s.p3SkippedBody),
      );
    } else {
      account = AppCard(
        header: s.p3Account,
        child: _IconLine(icon: Icons.apple, color: c.textPrimary, title: s.p3SignIn, caption: s.p3Benefit, danger: failed ? s.p3Failed : null),
      );
    }
    return OnboardingPage(
      headline: s.p3Headline,
      body: s.p3Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          account,
          SectionLabel(s.p3Asks, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
          _Row(icon: Icons.near_me_rounded, text: s.p3ItemA),
          const SizedBox(height: 10),
          _Row(icon: Icons.speed_rounded, text: s.p3ItemB),
          if (denied) ...[
            const SizedBox(height: 16),
            AppCard(
              tone: CardTone.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.location_off_rounded, size: 20, color: c.danger), const SizedBox(width: 8), Expanded(child: Text(s.denied, style: AppText.bodyText(c.textPrimary, size: 15)))]),
                  const SizedBox(height: 12),
                  SecondaryButton(label: s.openSettings, onPressed: onOpenSettings, height: 48),
                ],
              ),
            ),
          ] else if (granted) ...[
            const SizedBox(height: 16),
            AppCard(
              tone: CardTone.accent,
              child: Row(children: [Icon(Icons.check_circle_rounded, size: 20, color: c.accent), const SizedBox(width: 8), Expanded(child: Text(grantedAlways ? s.grantedAlways : s.grantedWhileInUse, style: AppText.bodyText(c.textPrimary, size: 15)))]),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.color, required this.title, required this.caption, this.danger});
  final IconData icon;
  final Color color;
  final String title;
  final String caption;
  final String? danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.title(c.textPrimary)),
              const SizedBox(height: 2),
              Text(caption, style: AppText.caption(c.textSecondary)),
              if (danger != null) ...[const SizedBox(height: 8), Text(danger!, style: AppText.caption(c.danger))],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: c.textTertiary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.bodyText(c.textPrimary, size: 15))),
        ],
      ),
    );
  }
}

/// Line pager: 24×2 bars, active champagne.
class LinePager extends StatelessWidget {
  const LinePager({super.key, required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Tokens.medium,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 28 : 16,
            height: 3,
            decoration: BoxDecoration(color: i == index ? c.accent : c.hairlineStrong, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }
}
