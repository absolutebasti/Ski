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
import 'onboarding_pages.dart';
import 'onboarding_strings.dart';

/// Four interactive pages, < 60 s (docs/ONBOARDING-SOCIAL.md): hook → home
/// resort + season goal → Sign in with Apple (optional) → permissions.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  static const int pageCount = 4;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pages = PageController();
  int _index = 0;

  // page 2
  Resort? _resort;
  int _goalHm = 20000;

  // page 3
  AuthUser? _user;
  bool _signingIn = false;
  bool _signInFailed = false;

  // page 4
  bool _asking = false;
  bool _asked = false;
  LocationPermissionState _location = LocationPermissionState.unknown;

  bool get _denied => _location == LocationPermissionState.denied || _location == LocationPermissionState.deniedForever;
  bool get _granted => _location == LocationPermissionState.whileInUse || _location == LocationPermissionState.always;

  @override
  void initState() {
    super.initState();
    _goalHm = ref.read(settingsProvider).seasonGoalHm;
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

  Future<void> _leavePage2() async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.setSeasonGoal(_goalHm);
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
    final last = _index == OnboardingFlow.pageCount - 1;
    final canGoBack = _index > 0 && !_asking && !_signingIn;

    final String label;
    final VoidCallback? onPressed;
    String? skipLabel;
    VoidCallback? onSkip;
    switch (_index) {
      case 0:
        label = s.next;
        onPressed = () => _goTo(1);
      case 1:
        label = s.next;
        onPressed = () async {
          await _leavePage2();
          if (mounted) _goTo(2);
        };
      case 2:
        if (_user != null) {
          label = s.next;
          onPressed = () => _goTo(3);
        } else {
          label = s.p3SignIn;
          onPressed = _signingIn ? null : _signIn;
          skipLabel = s.skip;
          onSkip = _signingIn ? null : () => _goTo(3);
        }
      default:
        if (_asked && !_granted) {
          label = s.finish;
          onPressed = _finish;
        } else {
          label = s.allow;
          onPressed = _asking ? null : _ask;
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
                              child: HeaderButton(glyph: Glyph.back, onTap: canGoBack ? () => _goTo(_index - 1) : null),
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
                      RevierPage(
                        selectedId: _resort?.id,
                        goalHm: _goalHm,
                        onResort: (r) => setState(() => _resort = r),
                        onGoal: (g) => setState(() => _goalHm = g),
                      ),
                      FriendsPage(user: _user, busy: _signingIn, failed: _signInFailed, onSignIn: _signIn),
                      PermissionsPage(
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
                      Semantics(
                        label: s.stepOf(_index + 1, OnboardingFlow.pageCount),
                        child: PrimaryButton(
                          key: const ValueKey('onboarding-primary'),
                          label: label,
                          height: 60,
                          glyph: last && !_asked ? null : (_index == 2 && _user == null ? null : Glyph.chevronRight),
                          icon: _index == 2 && _user == null ? Icons.apple : null,
                          onPressed: onPressed,
                        ),
                      ),
                      if (skipLabel != null) ...[
                        const SizedBox(height: 6),
                        TextButton(key: const ValueKey('onboarding-skip'), onPressed: onSkip, child: Text(skipLabel)),
                      ],
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
