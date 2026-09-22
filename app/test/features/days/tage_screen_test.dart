import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/app/widgets/widgets.dart';
import 'package:schwung/core/core.dart';
import 'package:schwung/data/db/providers.dart';
import 'package:schwung/features/days/day_card.dart';
import 'package:schwung/features/days/tage_screen.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';

const _bests = PersonalBests(
  topSpeedMs: 17,
  topSpeedDayId: 'a',
  biggestDayDropM: 1804,
  biggestDayId: 'a',
  longestRunDropM: 312,
  longestRunDayId: 'a',
);

const _totals = [
  SeasonTotals(seasonKey: '2025/26', dayCount: 6, runCount: 41, dropM: 18240),
  SeasonTotals(seasonKey: '2024/25', dayCount: 3, runCount: 19, dropM: 8100),
];

List<Override> overrides({
  required List<DaySummary> days,
  List<SeasonTotals> totals = _totals,
  PersonalBests bests = _bests,
  RecordingRepository? repo,
}) =>
    [
      daysListProvider.overrideWith((ref) => Stream.value(days)),
      seasonTotalsProvider.overrideWith((ref) => Stream.value(totals)),
      personalBestsProvider.overrideWith((ref) => Stream.value(bests)),
      if (repo != null) daysRepositoryProvider.overrideWithValue(repo),
    ];

/// A local navigator so `AppNav.openDay` has a route generator to talk to.
Widget hostWithRoutes(Widget child, List<String> pushed) => Navigator(
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        if (name != '/') pushed.add(name);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => name == '/' ? child : const Scaffold(body: Text('pushed')),
        );
      },
    );

void main() {
  testWidgets('season header, PB chips and the newest season cards are rendered', (tester) async {
    final days = [
      summary(id: 'a', startedAt: tsThisSeason, isTopSpeedPb: true, isBiggestDayPb: true),
      summary(id: 'b', startedAt: tsLastSeason, resortName: 'Ischgl', runCount: 4, dropM: 900, maxSpeedMs: 12),
    ];
    await pumpApp(tester, const TageScreen(), overrides: overrides(days: days));
    await tester.pump();

    expect(find.text('2025/26 · 6 Tage · 41 Abfahrten · 18.240 hm'), findsOneWidget);
    expect(find.text('Top-Speed 61 km/h'), findsOneWidget);
    expect(find.text('Größter Tag 1.804 hm'), findsOneWidget);
    expect(find.text('Längste Abfahrt 312 hm'), findsOneWidget);

    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(find.text('7 Abfahrten · 1.804 hm · 61 km/h'), findsOneWidget);
    expect(find.text('Rekord'), findsOneWidget);

    // Last season is collapsed behind its header.
    expect(find.text('2024/25 · 3 Tage · 19 Abfahrten · 8.100 hm'), findsOneWidget);
    expect(find.text('Ischgl'), findsNothing);
    expect(find.byType(DayCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an older season header expands its days', (tester) async {
    final days = [
      summary(id: 'a', startedAt: tsThisSeason),
      summary(id: 'b', startedAt: tsLastSeason, resortName: 'Ischgl'),
    ];
    await pumpApp(tester, const TageScreen(), overrides: overrides(days: days));
    await tester.pump();

    await tester.tap(find.text('2024/25 · 3 Tage · 19 Abfahrten · 8.100 hm'));
    await tester.pumpAndSettle();
    expect(find.text('Ischgl'), findsOneWidget);
    expect(find.byType(DayCard), findsNWidgets(2));
  });

  testWidgets('empty list shows the mascot empty state', (tester) async {
    await pumpApp(tester, const TageScreen(), overrides: overrides(days: const []));
    await tester.pump();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(DayCard), findsNothing);
  });

  testWidgets('tapping a card opens the day route', (tester) async {
    final pushed = <String>[];
    await pumpApp(
      tester,
      hostWithRoutes(const TageScreen(), pushed),
      overrides: overrides(days: [summary(id: 'day-1', startedAt: tsThisSeason)]),
    );
    await tester.pump();
    await tester.tap(find.byType(DayCard));
    await tester.pumpAndSettle();
    expect(pushed, ['/day/day-1']);
  });

  testWidgets('long-press → Löschen → confirm soft-deletes the day', (tester) async {
    final repo = RecordingRepository();
    addTearDown(() async => repo.db.close());
    await pumpApp(
      tester,
      const TageScreen(),
      overrides: overrides(days: [summary(id: 'day-1', startedAt: tsThisSeason)], repo: repo),
    );
    await tester.pump();

    await tester.longPress(find.byType(DayCard));
    await tester.pumpAndSettle();
    expect(find.text('Teilen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Skitag löschen?'), findsOneWidget);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['day-1']);
  });

  testWidgets('long-press → Abbrechen keeps the day', (tester) async {
    final repo = RecordingRepository();
    addTearDown(() async => repo.db.close());
    await pumpApp(
      tester,
      const TageScreen(),
      overrides: overrides(days: [summary(id: 'day-1', startedAt: tsThisSeason)], repo: repo),
    );
    await tester.pump();

    await tester.longPress(find.byType(DayCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });

  testWidgets('English locale switches the copy', (tester) async {
    await pumpApp(
      tester,
      const TageScreen(),
      overrides: overrides(days: [summary(id: 'a', startedAt: tsThisSeason)]),
      locale: const Locale('en'),
    );
    await tester.pump();
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('2025/26 · 6 days · 41 runs · 18,240 m'), findsOneWidget);
  });
}
