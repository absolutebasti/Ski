import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'duel_fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeDuelApi api, {Duration? poll, String? ownUserId = 'u1', bool history = false}) async {
  await pumpApp(
    tester,
    Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(child: DuelCard(resortId: 'kitzbuehel', ownUserId: ownUserId, now: kDuelNow, showHistory: history)),
    ),
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'), resorts: kResorts),
      ...duelOverrides(api: api, user: ownUserId == null ? null : kUser, poll: poll),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _createWithName(WidgetTester tester, String name) async {
  await tester.tap(find.text('Duell starten'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('duel-name-field')), findsOneWidget);
  if (name.isNotEmpty) await tester.enterText(find.byKey(const ValueKey('duel-name-field')), name);
  await tester.tap(find.byKey(const ValueKey('duel-create-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without a duel: start (with the optional name sheet) and join', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    await _pump(tester, api);

    expect(find.text('TAGESDUELL'), findsOneWidget);
    expect(find.text('Duell starten'), findsOneWidget);
    expect(find.text('Code eingeben'), findsOneWidget);

    await _createWithName(tester, '');

    expect(api.created, ['Tagesduell'], reason: 'an empty name falls back to the default');
    expect(api.createdTz, hasLength(1));
    expect(api.createdTz.single, contains('/'), reason: 'an IANA zone goes to groups.tz');
    expect(find.text('KMJ4F2'), findsOneWidget, reason: 'the six-character code is on the card');
    expect(find.text('1 / 3'), findsOneWidget, reason: 'members over capacity in the header');
    expect(find.text('Duell teilen'), findsOneWidget);
    expect(find.text('Verlassen'), findsOneWidget);
  });

  testWidgets('a typed name becomes the duel name and the card header', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    await _pump(tester, api);
    await _createWithName(tester, 'Hahnenkamm-Crew');
    expect(api.created, ['Hahnenkamm-Crew']);
    expect(find.text('HAHNENKAMM-CREW'), findsOneWidget);
  });

  testWidgets('a running duel shows 2 / 3, the leader in champagne and the live row with its age', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard);
    await _pump(tester, api);

    expect(api.boardCalls, ['g1']);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Paul Moser'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('2.410'), findsOneWidget);
    expect(find.text('1.804'), findsOneWidget);
    expect(find.text('live · vor 2 min'), findsOneWidget);
    expect(find.byType(LiveDot), findsOneWidget, reason: 'only the live member gets the ice dot');

    final leader = tester.widget<Text>(find.text('2.410'));
    final second = tester.widget<Text>(find.text('1.804'));
    expect(leader.style?.color, AppColors.dark.accent);
    expect(second.style?.color, AppColors.dark.textPrimary);
    final live = tester.widget<Text>(find.text('live · vor 2 min'));
    expect(live.style?.color, AppColors.dark.ice);
  });

  testWidgets('a finished member has no live marker', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kFinalBoard);
    await _pump(tester, api);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byType(LiveDot), findsNothing);
    expect(find.textContaining('live'), findsNothing);
  });

  testWidgets('leaving drops back to the start/join card', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard);
    await _pump(tester, api);

    await tester.tap(find.text('Verlassen'));
    await tester.pumpAndSettle();

    expect(api.left, ['g1']);
    expect(find.text('Duell starten'), findsOneWidget);
  });

  testWidgets('joining normalises the typed code', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
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
    final api = FakeDuelApi(userId: 'u1');
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

  testWidgets('duel_expired from the server becomes a readable toast', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    await _pump(tester, api);
    api.failWith = const SocialError(SocialErrorKind.duelExpired);

    await tester.tap(find.text('Code eingeben'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('duel-code-field')), 'KMJ4F2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Dieses Duell ist vorbei.'), findsOneWidget);
    expect(find.text('Duell starten'), findsOneWidget);
  });

  testWidgets('the board is polled while the card is visible', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard);
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
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard);
    await _pump(tester, api);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.boardCalls.length, 1);
  });

  testWidgets('signed out the card asks for a Konto instead of opening the sheet', (tester) async {
    final api = FakeDuelApi();
    await _pump(tester, api, ownUserId: null);

    await tester.tap(find.text('Duell starten'));
    await tester.pumpAndSettle();

    expect(api.created, isEmpty);
    expect(find.byKey(const ValueKey('duel-name-field')), findsNothing);
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
  });

  testWidgets('the history list renders under the card', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard, duels: pastDuels());
    await _pump(tester, api, history: true);
    expect(find.text('VERGANGENE DUELLE'), findsOneWidget);
    expect(find.textContaining('Gestern · Platz 2 von 3 · 1.849 hm'), findsOneWidget);
  });

  testWidgets('a FakeSocialApi alone still drives the card (adapter path)', (tester) async {
    final social = FakeSocialApi(userId: 'u1', duel: duelGroup(), board: kBoard);
    await pumpApp(
      tester,
      Scaffold(backgroundColor: Colors.transparent, body: SingleChildScrollView(child: DuelCard(ownUserId: 'u1', now: kDuelNow))),
      overrides: [
        ...screenOverrides(settings: const Settings(onboardingDone: true), resorts: kResorts),
        ...socialOverrides(api: social, user: kUser),
      ],
    );
    await tester.pumpAndSettle();
    expect(social.boardCalls, ['g1']);
    expect(find.text('Paul Moser'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(LiveDot), findsNothing);
  });

  test('the share text carries the code and the invite link', () {
    final text = DuelCardShare.text(const SocialStrings(AppLocale(Locale('de'))), 'KMJ4F2');
    expect(text, contains('KMJ4F2'));
    expect(text, contains(InviteLinks.share(InviteKind.duel, 'KMJ4F2')));
  });
}
