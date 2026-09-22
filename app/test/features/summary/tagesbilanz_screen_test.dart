import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/app/widgets/widgets.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/data/db/providers.dart';
import 'package:dropline/features/summary/tagesbilanz_screen.dart';
import 'package:dropline/platform/providers.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../today/today_fixtures.dart' show TestSettings, daySummary;
import 'summary_fixture.dart';

const _noBests = PersonalBests();
const _asked = Settings(notificationsAsked: true, onboardingDone: true);

List<Override> summaryOverrides({
  DayDetail? detail,
  PersonalBests bests = _noBests,
  List<DaySummary> days = const [],
  Settings settings = _asked,
  FakePermissionService? permissions,
}) =>
    [
      dayDetailProvider.overrideWith((ref, id) => detail ?? summaryDetail()),
      personalBestsProvider.overrideWith((ref) => Stream.value(bests)),
      daysListProvider.overrideWith((ref) => Stream.value(days)),
      settingsProvider.overrideWith(() => TestSettings(settings)),
      permissionServiceProvider.overrideWithValue(permissions ?? FakePermissionService()),
    ];

void main() {
  testWidgets('the four numbers count up and end on the real values', (tester) async {
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: summaryOverrides(days: [daySummary(), daySummary(id: 'day-0')]),
    );
    await tester.pump(); // resolve the day

    // Mid-flight the numbers are still below their targets.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('1.804'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('1.804'), findsOneWidget); // Höhenmeter
    expect(find.text('7'), findsOneWidget); // Abfahrten
    expect(find.text('61'), findsOneWidget); // Top-Speed
    expect(find.text('24,5'), findsOneWidget); // Ski-km
    expect(find.textContaining('Abfahrt 3 · '), findsOneWidget);
    expect(find.textContaining('312 hm · 2,1 km · 61 km/h'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget); // mascot + one line
    expect(tester.takeException(), isNull);
  });

  testWidgets('a personal best shows a champagne chip', (tester) async {
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: summaryOverrides(
        bests: const PersonalBests(topSpeedMs: 17, topSpeedDayId: 'day-1'),
        days: [daySummary(), daySummary(id: 'day-0')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rekord · Top-Speed'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(EmptyState), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Neuer Rekord. Den musst du erst mal wieder schlagen.'), findsOneWidget);
  });

  testWidgets('the first ever day gets the first-day line', (tester) async {
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: summaryOverrides(days: [daySummary()]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dein erster Skitag ist im Kasten. Den vergisst du nicht.'), findsOneWidget);
  });

  testWidgets('Fertig pops back to the shell', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await pumpApp(
      tester,
      Navigator(
        key: key,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('shell'))),
      ),
      overrides: summaryOverrides(days: [daySummary(), daySummary(id: 'day-0')]),
    );
    await tester.pumpAndSettle();
    unawaitedPush(key);
    await tester.pumpAndSettle();
    expect(find.text('Tagesbilanz'), findsOneWidget);

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('Tagesbilanz'), findsNothing);
  });

  testWidgets('the first saved day asks for notifications once', (tester) async {
    final perms = FakePermissionService();
    final notifier = TestSettings(const Settings(onboardingDone: true));
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: [
        dayDetailProvider.overrideWith((ref, id) => summaryDetail()),
        personalBestsProvider.overrideWith((ref) => Stream.value(_noBests)),
        daysListProvider.overrideWith((ref) => Stream.value([daySummary()])),
        settingsProvider.overrideWith(() => notifier),
        permissionServiceProvider.overrideWithValue(perms),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Soll ich mich melden?'), findsOneWidget);
    await tester.tap(find.text('Erinnerungen an'));
    await tester.pumpAndSettle();

    final settings = ProviderScope.containerOf(tester.element(find.byType(TagesbilanzScreen))).read(settingsProvider);
    expect(settings.notificationsOptIn, isTrue);
    expect(settings.notificationsAsked, isTrue);
    expect(find.text('Soll ich mich melden?'), findsNothing);
  });

  testWidgets('a day that was asked already never sees the sheet', (tester) async {
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: summaryOverrides(days: [daySummary()]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soll ich mich melden?'), findsNothing);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await pumpApp(
      tester,
      const TagesbilanzScreen(dayId: 'day-1'),
      overrides: summaryOverrides(days: [daySummary(), daySummary(id: 'day-0')]),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Day summary'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('1,804'), findsOneWidget);
  });
}

void unawaitedPush(GlobalKey<NavigatorState> key) {
  key.currentState!.push<void>(
    MaterialPageRoute<void>(builder: (_) => const TagesbilanzScreen(dayId: 'day-1')),
  );
}
