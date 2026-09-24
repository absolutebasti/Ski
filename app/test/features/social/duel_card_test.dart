import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'social_fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeSocialApi api, {Duration? poll, String? ownUserId = 'u1'}) async {
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: SingleChildScrollView(child: DuelCard(resortId: 'kitzbuehel', ownUserId: ownUserId))),
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'), resorts: kResorts),
      ...socialOverrides(api: api, user: kUser, poll: poll),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a duel: start and join', (tester) async {
    final api = FakeSocialApi(userId: 'u1');
    await _pump(tester, api);

    expect(find.text('TAGESDUELL'), findsOneWidget);
    expect(find.text('Duell starten'), findsOneWidget);
    expect(find.text('Code eingeben'), findsOneWidget);

    await tester.tap(find.text('Duell starten'));
    await tester.pumpAndSettle();

    expect(api.created, ['Tagesduell']);
    expect(find.text('KMJ4F2'), findsOneWidget, reason: 'the six-character code is on the card');
    expect(find.text('Duell teilen'), findsOneWidget);
    expect(find.text('Verlassen'), findsOneWidget);
  });

  testWidgets('a running duel lists members, the leader in champagne', (tester) async {
    final api = FakeSocialApi(userId: 'u1', duel: duelGroup(), board: kBoard);
    await _pump(tester, api);

    expect(api.boardCalls, ['g1']);
    expect(find.text('Paul Moser'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('2.410'), findsOneWidget);
    expect(find.text('1.804'), findsOneWidget);

    final leader = tester.widget<Text>(find.text('2.410'));
    final second = tester.widget<Text>(find.text('1.804'));
    expect(leader.style?.color, AppColors.dark.accent);
    expect(second.style?.color, AppColors.dark.textPrimary);
  });

  testWidgets('leaving drops back to the start/join card', (tester) async {
    final api = FakeSocialApi(userId: 'u1', duel: duelGroup(), board: kBoard);
    await _pump(tester, api);

    await tester.tap(find.text('Verlassen'));
    await tester.pumpAndSettle();

    expect(api.left, ['g1']);
    expect(find.text('Duell starten'), findsOneWidget);
  });

  testWidgets('joining normalises the typed code', (tester) async {
    final api = FakeSocialApi(userId: 'u1');
    await _pump(tester, api);

    await tester.tap(find.text('Code eingeben'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('duel-code-field')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('duel-code-field')), ' kmj-4f2 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(api.joined, ['KMJ4F2']);
    expect(find.text('KMJ4F2'), findsOneWidget);
  });

  testWidgets('a wrong code stays on the card and says so', (tester) async {
    final api = FakeSocialApi(userId: 'u1');
    await _pump(tester, api);

    await tester.tap(find.text('Code eingeben'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('duel-code-field')), 'AB0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(api.joined, isEmpty);
    expect(find.text('Diesen Code gibt es nicht'), findsOneWidget);
    expect(find.text('Duell starten'), findsOneWidget);
  });

  testWidgets('the board is polled while the card is visible', (tester) async {
    final api = FakeSocialApi(userId: 'u1', duel: duelGroup(), board: kBoard);
    await _pump(tester, api, poll: const Duration(milliseconds: 100));
    final before = api.boardCalls.length;

    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle();
    expect(api.boardCalls.length, greaterThan(before));

    // The timer dies with the card — no pending timer survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('polling is off when the interval provider is null', (tester) async {
    final api = FakeSocialApi(userId: 'u1', duel: duelGroup(), board: kBoard);
    await _pump(tester, api);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.boardCalls.length, 1);
  });

  testWidgets('signed out the card asks for a Konto instead of creating', (tester) async {
    final api = FakeSocialApi();
    await _pump(tester, api, ownUserId: null);

    await tester.tap(find.text('Duell starten'));
    await tester.pumpAndSettle();

    expect(api.created, isEmpty);
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
  });
}
