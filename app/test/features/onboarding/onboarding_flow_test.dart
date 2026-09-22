import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/l10n/app_locale.dart';
import 'package:dropline/app/shell.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/data/sync/auth_service.dart';
import 'package:dropline/features/onboarding/onboarding.dart';
import 'package:dropline/platform/permission_service.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../../support/screen_overrides.dart';

/// Records the order of permission calls and lets a test hold a dialog open.
class RecordingPermissions extends FakePermissionService {
  RecordingPermissions({super.state, this.gate});
  final List<String> calls = [];
  Future<void>? gate;

  @override
  Future<LocationPermissionState> requestWhenInUse() async {
    calls.add('whenInUse');
    if (gate != null) await gate;
    return super.requestWhenInUse();
  }

  @override
  Future<LocationPermissionState> requestAlways() async {
    calls.add('always');
    return super.requestAlways();
  }

  @override
  Future<bool> requestMotion() async {
    calls.add('motion');
    return true;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}

const _resorts = [
  Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 12),
  Resort(id: 'ischgl', name: 'Ischgl', country: 'AT', lat: 47.01, lon: 10.29, radiusKm: 10),
];

Future<void> _pump(WidgetTester tester, RecordingPermissions perms, {Future<AuthUser?> Function()? signIn, Locale locale = const Locale('de')}) => pumpApp(
      tester,
      const OnboardingFlow(),
      overrides: [
        ...screenOverrides(settings: const Settings(), permissions: perms, resorts: _resorts),
        onboardingSignInProvider.overrideWithValue(signIn ?? () async => null),
      ],
      locale: locale,
    );

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter.io/videoPlayer'), (call) async => null);
  });

  testWidgets('four pages in order, no permission call before the last page', (tester) async {
    final perms = RecordingPermissions();
    await _pump(tester, perms);
    const de = OnboardingStrings(AppLocale(Locale('de')));
    expect(find.text(de.p1Headline), findsOneWidget);
    expect(find.byType(RouteHook), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-hm-slider')), findsOneWidget);
    await _next(tester);
    expect(find.text(de.p2Headline), findsOneWidget);
    expect(find.text('Kitzbühel'), findsOneWidget);
    await _next(tester);
    expect(find.text(de.p3Headline), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.text(de.p4Headline), findsOneWidget);
    expect(perms.calls, isEmpty);
  });

  testWidgets('slider moves the hero numeral and the mascot line', (tester) async {
    await _pump(tester, RecordingPermissions());
    expect(find.text('1.849'), findsOneWidget);
    tester.widget<Slider>(find.byKey(const ValueKey('onboarding-hm-slider'))).onChanged!(6500);
    await tester.pumpAndSettle();
    expect(find.text('1.849'), findsNothing);
    expect(find.text('6.500'), findsOneWidget);
    expect(find.text('Respekt. Das will ich sehen.'), findsOneWidget);
  });

  testWidgets('picking a resort and a goal persists to settings', (tester) async {
    await _pump(tester, RecordingPermissions());
    await _next(tester);
    await tester.tap(find.text('Ischgl'));
    await tester.pumpAndSettle();
    expect(find.text('Sei der Erste in Ischgl.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('goal-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-plus')));
    await tester.pumpAndSettle();
    expect(find.text('25.000'), findsOneWidget);
    await _next(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(OnboardingFlow)));
    expect(container.read(settingsProvider).lastResortId, 'ischgl');
    expect(container.read(settingsProvider).seasonGoalHm, 25000);
  });

  testWidgets('sign in with Apple shows the signed-in card and continues', (tester) async {
    await _pump(tester, RecordingPermissions(), signIn: () async => const AuthUser(id: 'u1', displayName: 'Sebastian'));
    await _next(tester);
    await _next(tester);
    await _next(tester); // primary = sign in
    expect(find.text('Angemeldet als Sebastian'), findsOneWidget);
    await _next(tester);
    const de = OnboardingStrings(AppLocale(Locale('de')));
    expect(find.text(de.p4Headline), findsOneWidget);
  });

  testWidgets('granted: whenInUse → always → motion, onboardingDone, lands on RootShell', (tester) async {
    final perms = RecordingPermissions(state: LocationPermissionState.whileInUse);
    await _pump(tester, perms);
    for (var i = 0; i < 2; i++) {
      await _next(tester);
    }
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(OnboardingFlow)));
    await _next(tester); // Erlauben
    expect(perms.calls, ['whenInUse', 'always', 'motion']);
    expect(container.read(settingsProvider).onboardingDone, isTrue);
    expect(find.byType(RootShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('denied: settings hint, motion skipped, onboarding still finishes', (tester) async {
    final perms = RecordingPermissions(state: LocationPermissionState.denied);
    await _pump(tester, perms);
    await _next(tester);
    await _next(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    await _next(tester); // Erlauben → denied
    expect(perms.calls, ['whenInUse']);
    const de = OnboardingStrings(AppLocale(Locale('de')));
    expect(find.text(de.openSettings), findsOneWidget);
    await tester.ensureVisible(find.text(de.openSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(de.openSettings));
    await tester.pump();
    expect(perms.calls.last, 'openSettings');
    await _next(tester); // Los geht's
    expect(find.byType(RootShell), findsOneWidget);
  });

  testWidgets('english copy is used for the en locale', (tester) async {
    await _pump(tester, RecordingPermissions(), locale: const Locale('en'));
    const en = OnboardingStrings(AppLocale(Locale('en')));
    expect(find.text(en.p1Headline), findsOneWidget);
    expect(find.text(en.next), findsOneWidget);
  });
}
