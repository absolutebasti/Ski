import 'package:dropline/core/core.dart';
import 'package:dropline/core/settings.dart';
import 'package:dropline/features/social/fake_social_api.dart';
import 'package:dropline/features/social/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'social_fixtures.dart';

const _settings = Settings(onboardingDone: true, lastResortId: 'kitzbuehel');

Future<void> _pump(
  WidgetTester tester, {
  FakeSocialApi? api,
  bool signedIn = true,
  VoidCallback? onOpenAccount,
  List<DaySummary> days = const [],
}) async {
  await pumpApp(
    tester,
    SocialScreen(now: kNow, onOpenAccount: onOpenAccount),
    overrides: [
      ...screenOverrides(settings: _settings, resorts: kResorts, days: days),
      ...socialOverrides(api: api, user: signedIn ? kUser : null),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: Leo, one line, sign in with Apple', (tester) async {
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
    expect(find.text('Du · Platz 4'), findsOneWidget);
    expect(find.text('12.480'), findsNWidgets(2));
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

    await tester.ensureVisible(find.text('Top-Speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top-Speed'));
    await tester.pumpAndSettle();

    expect(api.queries.last.metric, SocialMetric.maxSpeedMs);
    expect(find.text('km/h'), findsWidgets);
  });

  testWidgets('the period tabs send the month and week key', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.wireKey, '2025/26');

    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-W03');
    expect(find.text('Diese Woche · Kitzbühel'), findsOneWidget);

    await tester.tap(find.text('Monat'));
    await tester.pumpAndSettle();
    expect(api.queries.last.wireKey, '2026-01');
  });

  testWidgets('the resort row defaults to the home resort and can drop it', (tester) async {
    final api = FakeSocialApi(userId: 'u1', entries: kEntries);
    await _pump(tester, api: api);
    expect(api.queries.last.resortId, 'kitzbuehel');
    expect(find.text('Saison 2025/26 · Kitzbühel'), findsOneWidget);

    await tester.tap(find.text('Alle Gebiete'));
    await tester.pumpAndSettle();
    expect(api.queries.last.resortId, isNull);
    expect(find.text('Saison 2025/26 · Alle Gebiete'), findsOneWidget);
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
