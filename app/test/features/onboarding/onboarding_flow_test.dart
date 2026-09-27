import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/shell.dart';
import 'package:slopetrack/app/widgets/rider.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/onboarding/onboarding.dart';
import 'package:slopetrack/platform/permission_service.dart';

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

const de = OnboardingStrings(AppLocale(Locale('de')));

Future<void> _pump(
  WidgetTester tester,
  RecordingPermissions perms, {
  Future<AuthUser?> Function()? signIn,
  Locale locale = const Locale('de'),
  String? deviceCountry,
  Settings settings = const Settings(),
}) =>
    pumpApp(
      tester,
      OnboardingFlow(deviceCountry: deviceCountry),
      overrides: [
        ...screenOverrides(settings: settings, permissions: perms, resorts: _resorts),
        onboardingSignInProvider.overrideWithValue(signIn ?? () async => null),
      ],
      locale: locale,
    );

Future<void> _primary(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
  await tester.pumpAndSettle();
}

Future<void> _skip(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await tester.pumpAndSettle();
}

Settings _settings(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(OnboardingFlow))).read(settingsProvider);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter.io/videoPlayer'), (call) async => null);
  });

  testWidgets('three pages in order, no permission call before the last page', (tester) async {
    final perms = RecordingPermissions();
    await _pump(tester, perms);
    expect(find.text(de.p1Headline), findsOneWidget);
    expect(find.byType(RouteHook), findsOneWidget);
    expect(find.byType(Rider), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text(de.next), findsOneWidget);
    await _primary(tester);
    expect(find.text(de.p2Headline), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-country-AT')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-country-other')), findsOneWidget);
    await _primary(tester);
    expect(find.text(de.p3Headline), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
    expect(perms.calls, isEmpty);
    expect(find.byType(LinePager), findsOneWidget);
  });

  testWidgets('hook numerals count up once to their targets', (tester) async {
    await _pump(tester, RecordingPermissions());
    expect(find.text('4.120'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4.120'), findsOneWidget);
    expect(find.text('68'), findsOneWidget);
    expect(find.text(de.p1Runs.toUpperCase()), findsOneWidget);
  });

  testWidgets('back button returns to the previous page', (tester) async {
    await _pump(tester, RecordingPermissions());
    await _primary(tester);
    expect(find.text(de.p2Headline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text(de.p1Headline), findsOneWidget);
  });

  testWidgets('country tile persists settings.countryCode', (tester) async {
    await _pump(tester, RecordingPermissions());
    await _primary(tester);
    expect(_settings(tester).countryCode, isNull);
    await tester.tap(find.byKey(const ValueKey('onboarding-country-CH')));
    await tester.pumpAndSettle();
    expect(_settings(tester).countryCode, 'CH');
    await tester.tap(find.byKey(const ValueKey('onboarding-country-AT')));
    await tester.pumpAndSettle();
    expect(_settings(tester).countryCode, 'AT');
    await _primary(tester);
    expect(_settings(tester).countryCode, 'AT');
  });

  testWidgets('device locale country is preselected when it is on the grid', (tester) async {
    await _pump(tester, RecordingPermissions(), deviceCountry: 'de');
    await _primary(tester);
    expect(_settings(tester).countryCode, isNull);
    await _primary(tester); // leaving the page persists the preselection
    expect(_settings(tester).countryCode, 'DE');
  });

  testWidgets('device locale country outside the grid is not preselected', (tester) async {
    await _pump(tester, RecordingPermissions(), deviceCountry: 'US');
    await _primary(tester);
    await _primary(tester);
    expect(_settings(tester).countryCode, isNull);
  });

  testWidgets('an existing countryCode wins over the device locale', (tester) async {
    await _pump(tester, RecordingPermissions(), deviceCountry: 'DE', settings: const Settings(countryCode: 'IT'));
    await _primary(tester);
    await _primary(tester);
    expect(_settings(tester).countryCode, 'IT');
  });

  testWidgets('Anderes opens a sheet and picking NO persists and fills the tile', (tester) async {
    await _pump(tester, RecordingPermissions());
    await _primary(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-country-other')));
    await tester.pumpAndSettle();
    expect(find.text(de.p2OtherTitle), findsOneWidget);
    final no = find.byKey(const ValueKey('onboarding-country-NO'));
    await tester.dragUntilVisible(no, find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(no);
    await tester.pumpAndSettle();
    expect(find.text(de.p2OtherTitle), findsNothing);
    expect(_settings(tester).countryCode, 'NO');
    expect(find.text('Norwegen'), findsOneWidget);
    expect(find.text(de.p2Other), findsNothing);
  });

  testWidgets('optional home resort: collapsed row, search, pick persists lastResortId', (tester) async {
    await _pump(tester, RecordingPermissions());
    await _primary(tester);
    expect(find.byKey(const ValueKey('onboarding-resort-search')), findsNothing);
    expect(find.text(de.p2Resort), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-resort-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-resort-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-resort-search')), findsOneWidget);
    expect(find.text('Kitzbühel'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onboarding-resort-search')), 'isch');
    await tester.pumpAndSettle();
    expect(find.text('Kitzbühel'), findsNothing);
    await tester.ensureVisible(find.text('Ischgl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ischgl'));
    await tester.pumpAndSettle();
    expect(_settings(tester).lastResortId, 'ischgl');
    await _primary(tester);
    expect(_settings(tester).lastResortId, 'ischgl');
    expect(_settings(tester).seasonGoalHm, 20000);
  });

  testWidgets('sign in with Apple shows the signed-in card and switches the primary to Los geht’s', (tester) async {
    await _pump(tester, RecordingPermissions(), signIn: () async => const AuthUser(id: 'u1', displayName: 'Sebastian'));
    await _primary(tester);
    await _primary(tester);
    expect(find.text(de.p3SignIn), findsWidgets);
    await _primary(tester); // primary = Apple capsule
    expect(find.text(de.p3SignedIn('Sebastian')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-apple')), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsNothing);
    expect(find.text(de.finish), findsOneWidget);
  });

  testWidgets('failed sign-in shows the hint and keeps the Apple button', (tester) async {
    await _pump(tester, RecordingPermissions(), signIn: () async => throw StateError('cancelled'));
    await _primary(tester);
    await _primary(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-apple')));
    await tester.pumpAndSettle();
    expect(find.text(de.p3Failed), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
  });

  testWidgets('Später continues without account and no permission call yet', (tester) async {
    final perms = RecordingPermissions();
    await _pump(tester, perms);
    await _primary(tester);
    await _primary(tester);
    await _skip(tester);
    expect(find.text(de.p3Skipped), findsOneWidget);
    expect(find.text(de.finish), findsOneWidget);
    expect(perms.calls, isEmpty);
  });

  testWidgets('granted: whenInUse → always → motion, onboardingDone, lands on RootShell', (tester) async {
    final perms = RecordingPermissions(state: LocationPermissionState.whileInUse);
    await _pump(tester, perms);
    await _primary(tester);
    await _primary(tester);
    await _skip(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(OnboardingFlow)));
    await _primary(tester); // Los geht's
    expect(perms.calls, ['whenInUse', 'always', 'motion']);
    expect(container.read(settingsProvider).onboardingDone, isTrue);
    expect(find.byType(RootShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('denied: settings hint, motion skipped, onboarding still finishes', (tester) async {
    final perms = RecordingPermissions(state: LocationPermissionState.denied);
    await _pump(tester, perms);
    await _primary(tester);
    await _primary(tester);
    await _skip(tester);
    await _primary(tester); // Los geht's → denied
    expect(perms.calls, ['whenInUse']);
    expect(find.text(de.openSettings), findsOneWidget);
    await tester.ensureVisible(find.text(de.openSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(de.openSettings));
    await tester.pump();
    expect(perms.calls.last, 'openSettings');
    expect(find.byType(OnboardingFlow), findsOneWidget);
    await _primary(tester); // Los geht's → finish anyway
    expect(find.byType(RootShell), findsOneWidget);
  });

  testWidgets('signed in and granted lands on RootShell', (tester) async {
    final perms = RecordingPermissions(state: LocationPermissionState.whileInUse);
    await _pump(tester, perms, signIn: () async => const AuthUser(id: 'u1', displayName: 'Sebastian'));
    await _primary(tester);
    await _primary(tester);
    await _primary(tester); // sign in
    await _primary(tester); // Los geht's
    expect(perms.calls, ['whenInUse', 'always', 'motion']);
    expect(find.byType(RootShell), findsOneWidget);
  });

  testWidgets('english copy is used for the en locale', (tester) async {
    await _pump(tester, RecordingPermissions(), locale: const Locale('en'));
    const en = OnboardingStrings(AppLocale(Locale('en')));
    expect(find.text(en.p1Headline), findsOneWidget);
    expect(find.text(en.next), findsOneWidget);
    await _primary(tester);
    expect(find.text('Austria'), findsOneWidget);
  });

  test('flag emoji and country lookup', () {
    expect(flagEmoji('AT'), '🇦🇹');
    expect(flagEmoji('no'), '🇳🇴');
    expect(teamCountry('ch')?.de, 'Schweiz');
    expect(teamCountry('NO')?.en, 'Norway');
    expect(teamCountry('ZZ'), isNull);
    expect(isGridCountry('DE'), isTrue);
    expect(isGridCountry('NO'), isFalse);
    expect(kOtherCountries.map((k) => k.code).toSet().length, kOtherCountries.length);
  });
}
