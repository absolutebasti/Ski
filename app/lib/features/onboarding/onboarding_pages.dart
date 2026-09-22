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
import 'mascot_hero.dart';
import 'onboarding_strings.dart';
import 'route_hook.dart';

/// Shared page skeleton: mascot line + headline + body, then page content.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.mascotLine, required this.headline, required this.body, required this.child, this.leo = 'head'});
  final String mascotLine;
  final String headline;
  final String body;
  final Widget child;
  final String leo;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Leo(pose: leo, size: 108),
            const SizedBox(width: 8),
            Expanded(child: MascotLine(mascotLine)),
          ],
        ),
        const SizedBox(height: 12),
        Text(headline, style: AppText.headlineL(c.textPrimary)),
        const SizedBox(height: 10),
        Text(body, style: AppText.bodyText(c.textSecondary)),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

/// Page 1 — the hook: route draws itself, numeral follows the slider.
class HookPage extends StatefulWidget {
  const HookPage({super.key});
  @override
  State<HookPage> createState() => _HookPageState();
}

class _HookPageState extends State<HookPage> {
  double _hm = 1849;
  int _lastStep = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    return OnboardingPage(
      leo: 'hero',
      mascotLine: s.p1Mascot(_hm.round()),
      headline: s.p1Headline,
      body: s.p1Body,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RouteHook(height: 130),
            const SizedBox(height: 10),
            HeroNumber(value: Fmt.metres(_hm, locale: l.code), label: l.pick(de: 'Höhenmeter', en: 'Vertical'), unit: l.pick(de: 'hm', en: 'm'), size: 64, color: c.accent),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StateChip(text: s.p1ChipRuns, tone: ChipTone.neutral),
                StateChip(text: s.p1ChipSpeed, tone: ChipTone.ice),
                StateChip(text: s.p1ChipRank, tone: ChipTone.accent),
              ],
            ),
            const SizedBox(height: 18),
            Text(s.p1Slider, style: AppText.caption(c.textSecondary)),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: c.accent,
                inactiveTrackColor: c.hairlineStrong,
                thumbColor: c.accent,
                overlayColor: c.accentWash,
                trackHeight: 4,
              ),
              child: Slider(
                key: const ValueKey('onboarding-hm-slider'),
                value: _hm,
                min: 500,
                max: 8000,
                divisions: 30,
                onChanged: (v) {
                  final step = (v / 250).round();
                  if (step != _lastStep) {
                    _lastStep = step;
                    unawaited(HapticFeedback.selectionClick());
                  }
                  setState(() => _hm = v);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 2 — home resort + season goal.
class RevierPage extends ConsumerStatefulWidget {
  const RevierPage({super.key, required this.selectedId, required this.goalHm, required this.onResort, required this.onGoal});
  final String? selectedId;
  final int goalHm;
  final ValueChanged<Resort> onResort;
  final ValueChanged<int> onGoal;
  @override
  ConsumerState<RevierPage> createState() => _RevierPageState();
}

class _RevierPageState extends ConsumerState<RevierPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final repo = ref.watch(resortRepositoryProvider).asData?.value;
    final all = repo?.all ?? const <Resort>[];
    final q = _query.trim().toLowerCase();
    final list = (q.isEmpty ? all : all.where((r) => r.name.toLowerCase().contains(q))).toList()..sort((a, b) => a.name.compareTo(b.name));
    final selected = widget.selectedId == null ? null : repo?.byId(widget.selectedId!);
    return OnboardingPage(
      leo: 'point',
      mascotLine: s.p2Mascot(widget.goalHm),
      headline: s.p2Headline,
      body: s.p2Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    onChanged: (v) => setState(() => _query = v),
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
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Hairline(inset: 16),
                itemBuilder: (context, i) {
                  final r = list[i];
                  final on = r.id == widget.selectedId;
                  return Pressable(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      widget.onResort(r);
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
          if (selected != null) ...[
            const SizedBox(height: 12),
            AppCard(
              tone: CardTone.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.p2Teaser(selected.name), style: AppText.title(c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(s.p2TeaserBody, style: AppText.caption(c.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            child: Row(
              children: [
                Expanded(child: HeroNumber(value: Fmt.metres(widget.goalHm.toDouble(), locale: l.code), label: s.p2Goal, unit: s.p2GoalUnit, size: 34, color: c.accent)),
                _Stepper(onMinus: widget.goalHm > 5000 ? () => widget.onGoal(widget.goalHm - 5000) : null, onPlus: widget.goalHm < 150000 ? () => widget.onGoal(widget.goalHm + 5000) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({this.onMinus, this.onPlus});
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget b(String key, IconData i, VoidCallback? f) => Pressable(
          onTap: f == null ? null : () {
            unawaited(HapticFeedback.selectionClick());
            f();
          },
          child: Container(
            key: ValueKey(key),
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.glassFill, shape: BoxShape.circle, border: Border.all(color: c.glassStroke, width: c.hairlineWidth)),
            child: Icon(i, size: 20, color: f == null ? c.textQuaternary : c.textPrimary),
          ),
        );
    return Row(children: [b('goal-minus', Icons.remove_rounded, onMinus), const SizedBox(width: 8), b('goal-plus', Icons.add_rounded, onPlus)]);
  }
}

/// Hook for tests: the sign-in action the page uses.
final onboardingSignInProvider = Provider<Future<AuthUser?> Function()>((ref) => ref.read(authServiceProvider).signInWithApple);

/// Page 3 — Sign in with Apple (optional).
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key, required this.user, required this.busy, required this.failed, required this.onSignIn});
  final AuthUser? user;
  final bool busy;
  final bool failed;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    return OnboardingPage(
      leo: 'wave',
      mascotLine: s.p3Mascot,
      headline: s.p3Headline,
      body: s.p3Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user == null) ...[
            Pressable(
              onTap: busy ? null : onSignIn,
              child: Container(
                key: const ValueKey('onboarding-apple'),
                height: 56,
                decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(28)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, color: c.bg, size: 24),
                    const SizedBox(width: 8),
                    Text(s.p3SignIn, style: AppText.button(c.bg)),
                  ],
                ),
              ),
            ),
            if (failed) ...[const SizedBox(height: 12), Text(s.p3Failed, style: AppText.caption(c.danger))],
          ] else
            AppCard(
              tone: CardTone.accent,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.p3SignedIn(user!.displayName), style: AppText.title(c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(s.p3SignedInBody, style: AppText.caption(c.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Page 4 — permissions.
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key, required this.denied, required this.granted, required this.grantedAlways, required this.onOpenSettings});
  final bool denied;
  final bool granted;
  final bool grantedAlways;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    return OnboardingPage(
      leo: 'goggles-down',
      mascotLine: s.p4Mascot,
      headline: s.p4Headline,
      body: s.p4Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(icon: Icons.near_me_rounded, text: s.p4ItemA),
          const SizedBox(height: 10),
          _Row(icon: Icons.speed_rounded, text: s.p4ItemB),
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
