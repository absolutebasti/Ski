import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/app/l10n/app_locale.dart';
import 'package:schwung/app/shell.dart';
import 'package:schwung/app/widgets/widgets.dart';
import 'package:schwung/core/settings.dart';
import 'package:schwung/features/onboarding/onboarding.dart';
import 'package:schwung/platform/permission_service.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../../support/screen_overrides.dart';

/// Records the permission calls in order and can hold the first one open,
/// which is what "an iOS dialog is on screen" looks like to the widget.
class _Perms extends FakePermissionService {
  _Perms({super.state});

  final List<String> calls = [];
  int settingsOpened = 0;
  Completer<void>? gate;

  @override
  Future<LocationPermissionState> requestWhenInUse() async {
    calls.add('whenInUse');
    final g = gate;
    if (g != null) await g.future;
    return super.requestWhenInUse();
  }

  @override
  Future<LocationPermissionState> requestAlways() {
    calls.add('always');
    return super.requestAlways();
  }

  @override
  Future<bool> requestMotion() {
    calls.add('motion');
    return super.requestMotion();
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

const _de = OnboardingStrings(AppLocale(Locale('de')));

Settings _settingsOf(WidgetTester tester, Finder finder) =>
    ProviderScope.containerOf(tester.element(finder)).read(settingsProvider);

Future<void> _pumpFlow(WidgetTester tester, _Perms perms) => pumpApp(
      tester,
      const OnboardingFlow(),
      overrides: screenOverrides(settings: const Settings(), permissions: perms),
    );

Future<void> _toStepThree(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // video_player has no platform side in tests; MascotCard/MascotHero fall back
    // to the poster when initialize() fails, so a no-op handler is enough.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.io/videoPlayer'), (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter.io/videoPlayer'), null);
  });

  testWidgets('three pages in order, dots follow, no permission call before step 3', (tester) async {
    final perms = _Perms(state: LocationPermissionState.denied);
    await _pumpFlow(tester, perms);

    expect(find.text(_de.p1Headline), findsOneWidget);
    expect(find.text(_de.p1Mascot), findsOneWidget);
    expect(find.text(_de.next), findsOneWidget);
    expect(find.byType(ProgressDots), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(find.text(_de.p2Headline), findsOneWidget);
    expect(find.text(_de.p2Row2), findsOneWidget);
    expect(find.text(_de.p2Pill), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(find.text(_de.p3Headline), findsOneWidget);
    expect(find.text(_de.p3ItemB), findsOneWidget);
    expect(find.text(_de.allow), findsOneWidget);
    expect(perms.calls, isEmpty);
  });

  testWidgets('back returns to the previous page', (tester) async {
    final perms = _Perms();
    await _pumpFlow(tester, perms);

    await _toStepThree(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text(_de.p2Headline), findsOneWidget);
  });

  testWidgets('granted: whenInUse → always → motion, onboardingDone, lands on RootShell', (tester) async {
    final perms = _Perms(state: LocationPermissionState.whileInUse);
    await _pumpFlow(tester, perms);
    await _toStepThree(tester);

    await tester.tap(find.text(_de.allow));
    await tester.pumpAndSettle();

    expect(perms.calls, ['whenInUse', 'always', 'motion']);
    expect(perms.state, LocationPermissionState.always);
    expect(find.byType(RootShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(_settingsOf(tester, find.byType(RootShell)).onboardingDone, isTrue);
  });

  testWidgets('back is dead while the permission dialog is open', (tester) async {
    final perms = _Perms(state: LocationPermissionState.whileInUse)..gate = Completer<void>();
    await _pumpFlow(tester, perms);
    await _toStepThree(tester);

    await tester.tap(find.text(_de.allow));
    await tester.pump();

    final back = tester.widget<IconButton>(find.byKey(const ValueKey('onboarding-back')));
    expect(back.onPressed, isNull, reason: 'back must be locked while iOS asks');
    final primary = tester.widget<PrimaryButton>(find.byKey(const ValueKey('onboarding-primary')));
    expect(primary.onPressed, isNull, reason: 'no double request');
    expect(find.byType(RootShell), findsNothing);

    perms.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RootShell), findsOneWidget);
  });

  testWidgets('denied: inline settings hint, motion skipped, onboarding still finishes', (tester) async {
    final perms = _Perms(state: LocationPermissionState.denied);
    await _pumpFlow(tester, perms);
    await _toStepThree(tester);

    await tester.tap(find.text(_de.allow));
    await tester.pumpAndSettle();

    expect(perms.calls, ['whenInUse']);
    expect(find.text(_de.denied), findsOneWidget);
    expect(find.text(_de.openSettings), findsOneWidget);
    expect(find.byType(RootShell), findsNothing);

    await tester.ensureVisible(find.text(_de.openSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_de.openSettings));
    await tester.pumpAndSettle();
    expect(perms.settingsOpened, 1);

    await tester.tap(find.text(_de.finish));
    await tester.pumpAndSettle();
    expect(find.byType(RootShell), findsOneWidget);
    expect(_settingsOf(tester, find.byType(RootShell)).onboardingDone, isTrue);
  });

  testWidgets('english copy is used for the en locale', (tester) async {
    final perms = _Perms();
    await pumpApp(
      tester,
      const OnboardingFlow(),
      overrides: screenOverrides(settings: const Settings(), permissions: perms),
      locale: const Locale('en'),
    );
    const en = OnboardingStrings(AppLocale(Locale('en')));
    expect(find.text(en.p1Headline), findsOneWidget);
    expect(find.text(en.next), findsOneWidget);
  });
}
