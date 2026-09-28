import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/social_controls.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'duel_fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeDuelApi api, {String? ownUserId = 'u1'}) async {
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: SingleChildScrollView(child: DuelHistoryList(ownUserId: ownUserId, now: kDuelNow))),
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true), resorts: kResorts),
      ...duelOverrides(api: api, user: ownUserId == null ? null : kUser),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three past duels render with day label, place and Höhenmeter', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: pastDuels());
    await _pump(tester, api);

    // The auth stream settles after the first build: one or two fetches.
    expect(api.myDuelsCalls, greaterThanOrEqualTo(1));
    expect(find.text('VERGANGENE DUELLE'), findsOneWidget);
    expect(find.text('Gestern · Platz 2 von 3 · 1.849 hm'), findsOneWidget);
    expect(find.text('Vorgestern · Platz 2 von 2 · 1.804 hm'), findsOneWidget);
    expect(find.textContaining('10. Jan.'), findsOneWidget);
    expect(find.textContaining('· Platz 2 von 2 · 1.849 hm'), findsOneWidget);
  });

  testWidgets("today's duel is not history", (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: [duelSummary(day: DateTime(2026, 1, 15))]);
    await _pump(tester, api);
    expect(find.text('VERGANGENE DUELLE'), findsNothing);
  });

  testWidgets('signed out or empty renders nothing', (tester) async {
    await _pump(tester, FakeDuelApi(), ownUserId: null);
    expect(find.byType(Text), findsNothing);
    await _pump(tester, FakeDuelApi(userId: 'u1'));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('tapping a row opens the result sheet with the winner ringed', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duels: pastDuels());
    await _pump(tester, api);

    await tester.tap(find.text('Gestern · Platz 2 von 3 · 1.849 hm'));
    await tester.pumpAndSettle();

    expect(find.byType(DuelResultCard), findsOneWidget);
    expect(find.text('Platz 2 von 3'), findsOneWidget);
    expect(find.text('Paul Moser'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    final paul = tester.widget<AvatarCircle>(find.byWidgetPredicate((w) => w is AvatarCircle && w.name == 'Paul Moser'));
    final me = tester.widget<AvatarCircle>(find.byWidgetPredicate((w) => w is AvatarCircle && w.name == 'Sebastian Fackelmann'));
    expect(paul.ring, isTrue);
    expect(me.ring, isFalse);
  });

  test('past() keeps days before today, newest first, capped', () {
    final rows = DuelHistoryList.past([...pastDuels(), duelSummary(id: 'g-today', day: DateTime(2026, 1, 15))], kDuelNow, max: 2);
    expect(rows.map((d) => d.group.id), ['g-1', 'g-2']);
  });
}
