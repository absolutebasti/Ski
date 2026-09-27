import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'social_fixtures.dart';

const _settings = Settings(onboardingDone: true, lastResortId: 'kitzbuehel', countryCode: 'AT');


/// The metric chips scroll horizontally; drag their list until [label] is on screen.
Future<void> _revealChip(WidgetTester tester, String label) async {
  final chips = find.ancestor(of: find.text('Höhenmeter'), matching: find.byType(ListView)).first;
  await tester.dragUntilVisible(find.text(label), chips, const Offset(-160, 0));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  FakeSocialApi? api,
  bool signedIn = true,
  VoidCallback? onOpenAccount,
  List<DaySummary> days = const [],
  Settings settings = _settings,
}) async {
  // Tall phone surface: the achievements header sits above the board, so the
  // tabs and chips must stay on screen without scrolling.
  tester.view.physicalSize = const Size(1179, 5400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    SocialScreen(now: kNow, onOpenAccount: onOpenAccount),
    overrides: [
      ...screenOverrides(settings: settings, resorts: kResorts, days: days),
      ...socialOverrides(api: api, user: signedIn ? kUser : null),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: the Rider, one line, sign in with Apple', (tester) async {
    var opened = 0;
    await _pump(tester, api: FakeSocialApi(), signedIn: false, onOpenAccount: () => opened++);

    expect(find.text('Rangliste'), findsOneWidget);
    expect(find.text('Hol dir Platz 1.'), findsOneWidget);
    expect(find.text('Melde dich an und hol dir Platz 1 in Kitzbühel.'), findsOneWidget);
    expect(find.byType(LeaderboardPodium), findsNothing);

    await tester.ensureVisible(find.text('Mit Apple anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mit Apple anmelden'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('without a backend the tab is offline, not broken', (tester) async {
    await _pump(tester, api: null);
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in but not opted in: explainer instead of the board', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', optedIn: false, entries: kEntries),
      onOpenAccount: () => opened++,
    );

    expect(find.text('Deine Zahlen sind noch privat.'), findsOneWidget);
    expect(find.byType(LeaderboardPodium), findsNothing);
    expect(find.text('TAGESDUELL'), findsOneWidget, reason: 'the duel does not need the opt-in');

    await tester.ensureVisible(find.text('Rangliste freischalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rangliste freischalten'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('podium, rows and the own row pinned at the bottom', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: kEntries));

    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('24.100'), findsOneWidget);
    expect(find.text('Paul Moser'), findsOneWidget);
    // Rank 4 and 5 are rows, not podium columns.
    expect(find.byType(LeaderboardRow), findsNWidgets(2));
    expect(find.text('Tom Huber'), findsOneWidget);
    // 12.480 shows in the own row and once more in the pinned strip.
    expect(find.byType(OwnRankStrip), findsOneWidget);
    expect(find.text('Du · Platz 4 von 5'), findsOneWidget, reason: 'no server total → the slice size');
    expect(find.text('12.480'), findsNWidgets(2));
  });

  testWidgets('the own row strip shows the server participant count', (tester) async {
    final entries = [for (final e in kEntries) LeaderboardEntry(rank: e.rank, userId: e.userId, displayName: e.displayName, value: e.value, total: 250)];
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: entries));
    expect(find.text('Du · Platz 4 von 250'), findsOneWidget);
  });

  testWidgets('no own row when the user is not in the slice', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', entries: kEntries.take(3).toList()));
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.byType(OwnRankStrip), findsNothing);
  });

  testWidgets('empty board invites friends', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1'));
    expect(find.text('Sei der Erste in Kitzbühel.'), findsOneWidget);
    expect(find.text('Freunde einladen'), findsOneWidget);
    expect(find.byType(OwnRankStrip), findsNothing);
  });

  testWidgets('a failing call falls back to the offline state', (tester) async {
    await _pump(
      tester,
      api: FakeSocialApi(userId: 'u1', entries: kEntries, failWith: const SocialError(SocialErrorKind.offline)),
    );
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Deine Zahlen sind noch privat.'), findsNothing);
  });

  testWidgets('the metric chips re-query and re-unit the board', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.metric, SocialMetric.dropM);

    await _revealChip(tester, 'Top-Speed');
    await tester.tap(find.text('Top-Speed'));
    await tester.pumpAndSettle();

    expect(api.queries.last.metric, SocialMetric.maxSpeedMs);
    expect(find.text('km/h'), findsWidgets);
  });

  testWidgets('the period tabs send the month and week key', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.wireKey, '2025/26');
    await tester.ensureVisible(find.text('Woche'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-W03');
    expect(find.text('Diese Woche · Kitzbühel'), findsOneWidget);

    await tester.ensureVisible(find.text('Monat'));
    await tester.tap(find.text('Monat'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-01');
  });

  testWidgets('the scope row defaults to the home resort and switches the query', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.resortId, 'kitzbuehel');
    expect(api.queries.last.countryCode, isNull);
    expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);
    expect(find.text('Gebiet'), findsOneWidget);
    expect(find.text('Ischgl'), findsOneWidget, reason: 'the resort selector is visible under Gebiet');

    await tester.ensureVisible(find.text('Alle'));
    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();
    expect(api.queries.last.resortId, isNull);
    expect(api.queries.last.countryCode, isNull);
    expect(find.text('Saison 2025/26 · Alle Gebiete'), findsOneWidget);
    expect(find.text('Ischgl'), findsNothing, reason: 'the resort selector hides outside Gebiet');

    await tester.tap(find.text('Mein Land 🇦🇹'));
    await tester.pumpAndSettle();
    expect(api.queries.last.countryCode, 'AT');
    expect(api.queries.last.resortId, isNull);
    expect(api.queries.last.scope, LeaderboardScope.country);
    expect(find.text('Saison 2025/26 · Österreich'), findsOneWidget);

    await tester.tap(find.text('Gebiet'));
    await tester.pumpAndSettle();
    // The Kitzbühel query is cached by the family — no second fetch, but the
    // caption and the resort selector are back.
    expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);
    await tester.tap(find.text('Ischgl'));
    await tester.pumpAndSettle();
    expect(api.queries.last.resortId, 'ischgl');
  });

  testWidgets('without a team country the Mein Land chip is hidden', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api, settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'));
    expect(find.textContaining('Mein Land'), findsNothing);
    expect(find.text('Gebiet'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
  });

  testWidgets('the Punkte chip wires the points metric', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);

    await _revealChip(tester, 'Punkte');
    await tester.tap(find.text('Punkte'));
    await tester.pumpAndSettle();

    expect(api.queries.last.metric, SocialMetric.points);
    expect(api.queries.last.metric.wire, 'points');
    expect(find.text('Pkt.'), findsWidgets);
  });

  testWidgets('the Länder card asks country_board for the period key and rings the own team', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries, countries: kCountries);
    await _pump(tester, api: api);
    expect(api.countryBoardCalls.last, '2025/26');

    await tester.ensureVisible(find.byType(CountryBoardCard));
    await tester.pumpAndSettle();
    expect(find.text('LÄNDER'), findsOneWidget);
    expect(find.text('Team-Wertung · Saison'), findsOneWidget);
    expect(find.text('Schweiz'), findsOneWidget);
    expect(find.text('Österreich'), findsOneWidget);
    expect(find.text('250 Fahrer'), findsOneWidget);
    expect(find.text('91.234'), findsOneWidget);
    final flags = tester.widgetList<CountryFlag>(find.byType(CountryFlag)).toList();
    expect(flags.where((f) => f.ring).map((f) => f.countryCode), ['AT']);

    await tester.ensureVisible(find.text('Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(api.countryBoardCalls.last, '2026-W03');
  });

  testWidgets('duel and challenge sit above the board', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries, duel: duelGroup(), board: kBoard, challenges: [weeklyChallenge()]);
    await _pump(
      tester,
      api: api,
      days: [daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 13, 10).millisecondsSinceEpoch, dropM: 4000)],
    );

    expect(find.byType(DuelCard), findsOneWidget);
    expect(find.text('KMJ4F2'), findsOneWidget);
    expect(find.byType(ChallengeCard), findsOneWidget);
    expect(find.text('10.000 hm in einer Woche'), findsOneWidget);
    expect(find.text('4.000'), findsOneWidget);
    expect(find.byType(LeaderboardPodium), findsOneWidget);
  });
}
