import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/features/summary/notifications_sheet.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';
import 'package:slopetrack/features/summary/route_block.dart';
import 'package:slopetrack/features/summary/summary_skeleton.dart';
import 'package:slopetrack/features/summary/tagesbilanz_screen.dart';
import 'package:slopetrack/features/summary/time_legend.dart';
import 'package:slopetrack/platform/providers.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../achievements/ui/achievements_fixtures.dart';
import '../today/today_fixtures.dart' show TestSettings, daySummary;
import 'summary_fixture.dart';

const _noBests = PersonalBests();
const _asked = Settings(notificationsAsked: true, onboardingDone: true);
const _defaultLine = 'Sauber gefahren. Bis zum nächsten Tag.';
const _notAsked = Settings(onboardingDone: true);
const _notifyTitle = 'Soll ich mich melden?';
final _twoDays = [daySummary(), daySummary(id: 'day-0')];

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

/// A phone-sized surface — the Tagesbilanz is a full-bleed, scrolling screen.
Future<void> pumpSummary(WidgetTester tester, {List<Override> overrides = const [], Locale locale = const Locale('de')}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(tester, const TagesbilanzScreen(dayId: 'day-1'), overrides: overrides, locale: locale);
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 240, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the four numbers count up and end on the real values', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: _twoDays));
    await tester.pump(); // resolve the day

    // Mid-flight the numbers are still below their targets.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('1.804'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('1.804'), findsOneWidget); // Höhenmeter hero, 92 pt
    expect(find.text('7'), findsOneWidget); // Abfahrten
    expect(find.text('61'), findsNWidgets(2)); // Top-Speed of the day and of the best run
    expect(find.text('24,5'), findsOneWidget); // Ski-km
    expect(find.text('HÖHENMETER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the top block carries the date plate and the no-track fallback', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: _twoDays));
    await tester.pumpAndSettle();

    expect(find.byType(RouteBlock), findsOneWidget);
    expect(find.text('TAGESBILANZ'), findsOneWidget);
    expect(find.text('15. Januar 2026'), findsOneWidget);
    expect(find.text('Kitzbühel'), findsOneWidget);
    // No track on this fixture: a typeset line, never a pictogram.
    expect(find.text('OHNE TRACK'), findsOneWidget);
  });

  testWidgets('Beste Abfahrt shows the run as a column-aligned metric strip', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: _twoDays));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('BESTE ABFAHRT'));

    expect(find.textContaining('Abfahrt 3 · '), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('2,1'), findsOneWidget);
    expect(find.text('ZEIT'), findsOneWidget); // the time card header
  });

  testWidgets('a day with a track draws the route instead of the fallback', (tester) async {
    await pumpSummary(
      tester,
      overrides: summaryOverrides(detail: summaryDetail(points: trackPoints()), days: _twoDays),
    );
    await tester.pump();
    // Mid-draw and fully drawn: the painter must not throw either way.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(RouteBlock), findsOneWidget);
    expect(find.text('OHNE TRACK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a personal best gets the solid champagne record card', (tester) async {
    await pumpSummary(
      tester,
      overrides: summaryOverrides(
        bests: const PersonalBests(topSpeedMs: 17, topSpeedDayId: 'day-1'),
        days: _twoDays,
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('REKORD'));
    expect(find.text('REKORD'), findsOneWidget);
    expect(find.text('Schnellster Tag der Saison'), findsOneWidget);

    await scrollTo(tester, find.text('Neuer Rekord. Den musst du erst mal wieder schlagen.'));
    expect(find.text('Neuer Rekord. Den musst du erst mal wieder schlagen.'), findsOneWidget);
  });

  testWidgets('two records share one card', (tester) async {
    await pumpSummary(
      tester,
      overrides: summaryOverrides(
        bests: const PersonalBests(topSpeedMs: 17, topSpeedDayId: 'day-1', biggestDayDropM: 1804, biggestDayId: 'day-1'),
        days: _twoDays,
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('REKORD'));
    expect(find.text('Top-Speed · Größter Tag'), findsOneWidget);
  });

  testWidgets('the first ever day gets the first-day line', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: [daySummary()]));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Dein erster Skitag ist im Kasten. Den vergisst du nicht.'));
    expect(find.text('Dein erster Skitag ist im Kasten. Den vergisst du nicht.'), findsOneWidget);
  });

  testWidgets('the mascot block closes the screen and the dock carries both actions', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: _twoDays));
    await tester.pumpAndSettle();
    expect(find.text('Teilen'), findsOneWidget);
    expect(find.text('Fertig'), findsOneWidget);
    await scrollTo(tester, find.text(_defaultLine));
    expect(find.text(_defaultLine), findsOneWidget);
  });

  testWidgets('Fertig pops back to the shell', (tester) async {
    final key = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Navigator(
        key: key,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('shell'))),
      ),
      overrides: summaryOverrides(days: _twoDays),
    );
    await tester.pumpAndSettle();
    unawaitedPush(key);
    await tester.pumpAndSettle();
    expect(find.text('TAGESBILANZ'), findsOneWidget);

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('TAGESBILANZ'), findsNothing);
  });

  testWidgets('the notification sheet is absent during the count-up and appears on Fertig', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: [daySummary()], settings: _notAsked));
    await tester.pump(); // resolve the day
    await tester.pump(const Duration(milliseconds: 16)); // mid count-up
    expect(find.text(_notifyTitle), findsNothing);
    await tester.pumpAndSettle(); // settled — still nothing
    expect(find.text(_notifyTitle), findsNothing);
    expect(find.text('1.804'), findsOneWidget);

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text(_notifyTitle), findsOneWidget);

    await tester.tap(find.text('Erinnerungen an'));
    await tester.pumpAndSettle();
    final settings = ProviderScope.containerOf(tester.element(find.byType(TagesbilanzScreen))).read(settingsProvider);
    expect(settings.notificationsOptIn, isTrue);
    expect(settings.notificationsAsked, isTrue);
    expect(find.text(_notifyTitle), findsNothing);
  });

  testWidgets('the notification sheet can be dismissed and counts as not now', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: [daySummary()], settings: _notAsked));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text(_notifyTitle), findsOneWidget);

    await tester.tapAt(const Offset(20, 60)); // barrier, above the sheet
    await tester.pumpAndSettle();
    expect(find.text(_notifyTitle), findsNothing);
    final settings = ProviderScope.containerOf(tester.element(find.byType(TagesbilanzScreen))).read(settingsProvider);
    expect(settings.notificationsAsked, isTrue);
    expect(settings.notificationsOptIn, isFalse);
  });

  testWidgets('Fertig pops only after the sheet was answered', (tester) async {
    final key = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Navigator(
        key: key,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('shell'))),
      ),
      overrides: summaryOverrides(days: [daySummary()], settings: _notAsked),
    );
    await tester.pumpAndSettle();
    unawaitedPush(key);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text(_notifyTitle), findsOneWidget);
    expect(find.text('TAGESBILANZ'), findsOneWidget);

    await tester.tap(find.text('Nicht jetzt'));
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('TAGESBILANZ'), findsNothing);
  });

  testWidgets('a day that was asked already never sees the sheet', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: [daySummary()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsOptInSheet), findsNothing);
    expect(find.text(_notifyTitle), findsNothing);
  });

  testWidgets('the time card shows compact minutes, not a running clock', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(detail: summaryDetail(stats: timeStats()), days: _twoDays));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('ZEIT'));
    expect(find.text('38 min'), findsOneWidget);
    expect(find.text('0:38:12'), findsNothing);
    expect(_legendMinutes(tester), [20, 12, 6]);
  });

  testWidgets('legend minutes add up to the header value (37.6 min fixture)', (tester) async {
    // 37 min 36 s total: ski 20:12, lift 12:30, pause 4:54.
    final stats = timeStats(elapsedMs: 37 * 60000 + 36000, skiMs: 20 * 60000 + 12000, liftMs: 12 * 60000 + 30000, pauseMs: 4 * 60000 + 54000);
    await pumpSummary(tester, overrides: summaryOverrides(detail: summaryDetail(stats: stats), days: _twoDays));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('ZEIT'));
    expect(find.text('37 min'), findsOneWidget);
    final minutes = _legendMinutes(tester);
    expect(minutes.fold<int>(0, (a, b) => a + b), 37);
    expect(minutes, [20, 12, 5]);
  });

  test('timeLegendSegments hands the remainder to the pause segment', () {
    final seg = timeLegendSegments(timeStats(elapsedMs: 37 * 60000 + 36000, skiMs: 20 * 60000 + 12000, liftMs: 12 * 60000 + 30000, pauseMs: 4 * 60000 + 54000));
    expect(seg.skiMs, 20 * 60000);
    expect(seg.liftMs, 12 * 60000);
    expect(seg.pauseMs, 5 * 60000);
    expect(seg.signalLossMs, 0);
    // Never negative when the parts exceed the total.
    expect(timeLegendSegments(timeStats(elapsedMs: 60000, skiMs: 120000, liftMs: 0, pauseMs: 0)).pauseMs, 0);
  });

  testWidgets('a record plus new medals renders exactly one solid champagne card', (tester) async {
    await pumpSummary(
      tester,
      overrides: [
        ...summaryOverrides(bests: const PersonalBests(topSpeedMs: 17, topSpeedDayId: 'day-1'), days: _twoDays),
        ...achievementsOverrides(fixtureAchievements(newMedalIds: const ['streak-gold', 'days-bronze'])),
      ],
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('NEUE MEDAILLE').last);
    expect(find.text('REKORD'), findsOneWidget);
    expect(find.text('NEUE MEDAILLE'), findsNWidgets(2));

    final accent = AppColors.of(tester.element(find.byType(RecordCard))).accent;
    final solid = tester.widgetList<SurfaceCard>(find.byType(SurfaceCard)).where((w) => w.fill == accent);
    expect(solid.length, 1);
    // The medals sit on accent-wash cards instead.
    expect(find.byWidgetPredicate((w) => w is AppCard && w.tone == CardTone.accent), findsNWidgets(2));
  });

  testWidgets('without a record the new medals stay solid champagne', (tester) async {
    await pumpSummary(
      tester,
      overrides: [
        ...summaryOverrides(days: _twoDays),
        ...achievementsOverrides(fixtureAchievements(newMedalIds: const ['streak-gold'])),
      ],
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('NEUE MEDAILLE'));
    final accent = AppColors.of(tester.element(find.byType(NewMedalsBanner))).accent;
    expect(tester.widgetList<SurfaceCard>(find.byType(SurfaceCard)).where((w) => w.fill == accent).length, 1);
  });

  testWidgets('loading shows skeleton rows, never a spinner', (tester) async {
    await pumpSummary(
      tester,
      overrides: [
        dayDetailProvider.overrideWith((ref, id) => Completer<DayDetail>().future),
        personalBestsProvider.overrideWith((ref) => Stream.value(_noBests)),
        daysListProvider.overrideWith((ref) => Stream.value(_twoDays)),
        settingsProvider.overrideWith(() => TestSettings(_asked)),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
      ],
    );
    await tester.pump();
    expect(find.byType(SummarySkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await pumpSummary(tester, overrides: summaryOverrides(days: _twoDays), locale: const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text('DAY SUMMARY'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('1,804'), findsOneWidget);
  });
}

/// Whole minutes of every legend entry under the stacked time bar, in order.
List<int> _legendMinutes(WidgetTester tester) {
  final texts = tester.widgetList<RichText>(find.descendant(of: find.byType(StackedTimeBar), matching: find.byType(RichText)));
  return [
    for (final t in texts)
      if (RegExp(r'^(\d+) min').firstMatch(t.text.toPlainText()) case final m?) int.parse(m.group(1)!),
  ];
}

void unawaitedPush(GlobalKey<NavigatorState> key) {
  key.currentState!.push<void>(
    MaterialPageRoute<void>(builder: (_) => const TagesbilanzScreen(dayId: 'day-1')),
  );
}
