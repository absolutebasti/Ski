import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/settings.dart';
import '../../platform/permission_service.dart';
import '../../platform/providers.dart';
import 'onboarding_pages.dart';
import 'onboarding_strings.dart';

/// Three pages, ≤ 60 s (docs/PLAN.md §4). Step 3 asks iOS for location
/// (when-in-use → always) and motion; a refusal shows an inline settings hint
/// but never blocks finishing. On finish: `onboardingDone = true` → RootShell.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  static const int pageCount = 3;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pages = PageController();
  int _index = 0;

  /// True while an iOS permission dialog is on screen — back is locked then.
  bool _asking = false;
  bool _asked = false;
  LocationPermissionState _location = LocationPermissionState.unknown;

  bool get _denied =>
      _location == LocationPermissionState.denied || _location == LocationPermissionState.deniedForever;
  bool get _granted =>
      _location == LocationPermissionState.whileInUse || _location == LocationPermissionState.always;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= OnboardingFlow.pageCount) return;
    setState(() => _index = index);
    _pages.animateToPage(index, duration: Tokens.fast, curve: Curves.easeOut);
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() => _asking = true);
    final service = ref.read(permissionServiceProvider);
    var state = LocationPermissionState.unknown;
    try {
      state = await service.requestWhenInUse();
      if (state == LocationPermissionState.whileInUse || state == LocationPermissionState.always) {
        // iOS shows "Keep Only While Using / Change to Always Allow" now, once.
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
    // Granted: straight to Heute. Refused: stay, show the settings hint, let them finish.
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
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final last = _index == OnboardingFlow.pageCount - 1;
    final canGoBack = _index > 0 && !_asking;

    final String label;
    final VoidCallback? onPressed;
    if (!last) {
      label = s.next;
      onPressed = () => _goTo(_index + 1);
    } else if (_asked && !_granted) {
      label = s.finish;
      onPressed = _finish;
    } else {
      label = s.allow;
      onPressed = _asking ? null : _ask;
    }

    return PopScope(
      // Root route of a first launch: we own back entirely, and on step 3 the
      // back affordance is dead while an iOS dialog is up.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !canGoBack) return;
        _goTo(_index - 1);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 48 + MediaQuery.paddingOf(context).top,
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      key: const ValueKey('onboarding-back'),
                      tooltip: s.back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: c.textSecondary,
                      onPressed: canGoBack ? () => _goTo(_index - 1) : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    const WelcomePage(),
                    const HowItWorksPage(),
                    PermissionsPage(
                      denied: _denied,
                      granted: _granted,
                      grantedAlways: _location == LocationPermissionState.always,
                      onOpenSettings: _openSettings,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12),
                child: Column(
                  children: [
                    ProgressDots(count: OnboardingFlow.pageCount, index: _index),
                    const SizedBox(height: 16),
                    Semantics(
                      label: s.stepOf(_index + 1, OnboardingFlow.pageCount),
                      child: PrimaryButton(
                        key: const ValueKey('onboarding-primary'),
                        label: label,
                        height: Tokens.minTarget,
                        onPressed: onPressed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress dots — filled champagne for the current page.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.count, required this.index});

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
            duration: Tokens.fast,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? c.accent : c.hairline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
