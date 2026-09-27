import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/sync/auth_service.dart';
import '../../platform/permission_service.dart';
import '../../platform/providers.dart';
import 'onboarding_countries.dart';
import 'onboarding_pages.dart';
import 'onboarding_strings.dart';

/// Onboarding v3: three pages, one decision each.
/// P1 hook → P2 team (country, optional home resort) → P3 ready (Sign in with
/// Apple or 'Später', then the iOS permission flow, then RootShell).
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.deviceCountry});

  static const int pageCount = 3;

  /// ISO-3166 alpha-2 used to preselect the team tile; null = read the device
  /// locale (`WidgetsBinding.instance.platformDispatcher.locale.countryCode`).
  final String? deviceCountry;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pages = PageController();
  int _index = 0;

  // page 2
  String? _country;
  Resort? _resort;

  // page 3
  AuthUser? _user;
  bool _skipped = false;
  bool _signingIn = false;
  bool _signInFailed = false;
  bool _asking = false;
  bool _asked = false;
  LocationPermissionState _location = LocationPermissionState.unknown;

  bool get _denied => _location == LocationPermissionState.denied || _location == LocationPermissionState.deniedForever;
  bool get _granted => _location == LocationPermissionState.whileInUse || _location == LocationPermissionState.always;
  bool get _accountDecided => _user != null || _skipped;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final device = (widget.deviceCountry ?? WidgetsBinding.instance.platformDispatcher.locale.countryCode)?.toUpperCase();
    _country = settings.countryCode ?? (isGridCountry(device) ? device : null);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= OnboardingFlow.pageCount) return;
    setState(() => _index = index);
    _pages.animateToPage(index, duration: Tokens.sheetUp, curve: Curves.easeOutCubic);
  }

  Future<void> _setCountry(String code) async {
    setState(() => _country = code);
    await ref.read(settingsProvider.notifier).setCountry(code);
  }

  Future<void> _setResort(Resort r) async {
    setState(() => _resort = r);
    await ref.read(settingsProvider.notifier).setLastResort(r.id);
  }

  Future<void> _leaveTeamPage() async {
    final settings = ref.read(settingsProvider.notifier);
    if (_country != null) await settings.setCountry(_country);
    if (_resort != null) await settings.setLastResort(_resort!.id);
  }

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _signInFailed = false;
    });
    AuthUser? user;
    try {
      user = await ref.read(onboardingSignInProvider)();
    } catch (_) {
      user = null;
    }
    if (!mounted) return;
    setState(() {
      _signingIn = false;
      _user = user;
      _signInFailed = user == null;
    });
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() => _asking = true);
    final service = ref.read(permissionServiceProvider);
    var state = LocationPermissionState.unknown;
    try {
      state = await service.requestWhenInUse();
      if (state == LocationPermissionState.whileInUse || state == LocationPermissionState.always) {
        state = await service.requestAlways();
        await service.requestMotion();
      }
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _asked = true;
          _location = state;
        });
      }
    }
    if (!mounted) return;
    if (_granted) await _finish();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboardingDone();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const RootShell()),
      (route) => false,
    );
  }

  Future<void> _openSettings() => ref.read(permissionServiceProvider).openSettings();

  @override
  Widget build(BuildContext context) {
    final s = OnboardingStrings.of(context);
    final busy = _asking || _signingIn;
    final canGoBack = _index > 0 && !busy;

    // Dock: one primary action per page; P3 shows the Apple capsule until the
    // account decision is made, then the champagne 'Los geht's'.
    final Widget primary;
    Widget? skip;
    switch (_index) {
      case 0:
        primary = PrimaryButton(key: const ValueKey('onboarding-primary'), label: s.next, height: 60, glyph: Glyph.chevronRight, onPressed: () => _goTo(1));
      case 1:
        primary = PrimaryButton(
          key: const ValueKey('onboarding-primary'),
          label: s.next,
          height: 60,
          glyph: Glyph.chevronRight,
          onPressed: () async {
            await _leaveTeamPage();
            if (mounted) _goTo(2);
          },
        );
      default:
        if (!_accountDecided) {
          primary = KeyedSubtree(
            key: const ValueKey('onboarding-primary'),
            child: AppleSignInButton(label: s.p3SignIn, onPressed: busy ? null : _signIn),
          );
          skip = TextButton(key: const ValueKey('onboarding-skip'), onPressed: busy ? null : () => setState(() => _skipped = true), child: Text(s.skip));
        } else {
          primary = PrimaryButton(
            key: const ValueKey('onboarding-primary'),
            label: s.finish,
            height: 60,
            onPressed: busy ? null : (_asked && !_granted ? _finish : _ask),
          );
        }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !canGoBack) return;
        _goTo(_index - 1);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PageBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          opacity: canGoBack ? 1 : 0,
                          duration: Tokens.fast,
                          child: IgnorePointer(
                            ignoring: !canGoBack,
                            child: Semantics(
                              key: const ValueKey('onboarding-back'),
                              button: true,
                              label: s.back,
                              child: HeaderButton(glyph: Glyph.back, tooltip: s.back, onTap: canGoBack ? () => _goTo(_index - 1) : null),
                            ),
                          ),
                        ),
                        const Spacer(),
                        LinePager(count: OnboardingFlow.pageCount, index: _index),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const HookPage(),
                      TeamPage(countryCode: _country, onCountry: _setCountry, resortId: _resort?.id, onResort: _setResort),
                      ReadyPage(
                        user: _user,
                        skipped: _skipped,
                        failed: _signInFailed,
                        denied: _denied,
                        granted: _granted,
                        grantedAlways: _location == LocationPermissionState.always,
                        onOpenSettings: _openSettings,
                      ),
                    ],
                  ),
                ),
                BottomDock(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(label: s.stepOf(_index + 1, OnboardingFlow.pageCount), child: primary),
                      if (skip != null) ...[const SizedBox(height: 6), skip],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
