import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../rider/rider_fixtures.dart';
import '../social_fixtures.dart';
import 'challenge_fixtures.dart';

FakeChallengeApi _api({String? userId = 'u1', Set<String>? joined, Map<String, List<ChallengeBoardEntry>>? boards, SocialError? failWith, Completer<void>? gate}) =>
    FakeChallengeApi(userId: userId, challenges: [weekly()], joined: joined, boards: boards ?? {'c1': kChallengeBoard}, failWith: failWith, gate: gate);

Future<void> _pump(WidgetTester tester, {required FakeChallengeApi? api, Challenge? challenge, bool signedIn = true, Locale locale = const Locale('de')}) async {
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: ChallengeBoardSheetBody(challenge: challenge ?? weekly(), now: kNow)),
    locale: locale,
    overrides: [
      ...screenOverrides(resorts: kResorts),
      ...socialOverrides(api: FakeSocialApi(userId: signedIn ? 'u1' : null), user: signedIn ? kUser : null),
      ...challengeOverrides(api),
      ...riderOverrides(api: FakeRiderApi(profiles: {'u9': kLena})),
    ],
  );
  await tester.pump();
}

void main() {
  testWidgets('head, counts and three ranked rows with the own row marked', (tester) async {
    final api = _api(joined: {'c1'});
    await _pump(tester, api: api);
    await tester.pumpAndSettle();

    expect(api.boardCalls, everyElement('c1'));
    expect(find.text('Wochen-Challenge: 5.000 Höhenmeter'), findsOneWidget);
    expect(find.text('ZIEL '), findsOneWidget);
    expect(find.text('5.000'), findsOneWidget);
    expect(find.text('Noch 3 Tage'), findsOneWidget);
    expect(find.text('3 dabei · 1 geschafft'), findsOneWidget);

    expect(find.byType(ChallengeBoardRow), findsNWidgets(3));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('6.200'), findsOneWidget);
    expect(find.text('Sebastian Fackelmann'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget, reason: 'own row carries the Du caption');
    expect(find.text('4.000'), findsOneWidget);
    expect(find.text('Tom Huber'), findsOneWidget);
    expect(find.byKey(const ValueKey('challenge-done-u9')), findsOneWidget, reason: 'Lena reached the target');
    expect(find.byKey(const ValueKey('challenge-done-u1')), findsNothing);
    expect(find.byKey(const ValueKey('challenge-done-u6')), findsNothing);
    expect(find.bySemanticsLabel('1. Lena Bergmann · 6.200 hm'), findsOneWidget);
    expect(find.byKey(const ValueKey('challenge-leave')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('English head and counts', (tester) async {
    await _pump(tester, api: _api(), locale: const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly challenge: 5,000 m vertical'), findsOneWidget);
    expect(find.text('3 in · 1 done'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('a row opens the rider profile', (tester) async {
    await _pump(tester, api: _api());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('challenge-row-u9')));
    await tester.pumpAndSettle();

    expect(find.byType(RiderSheetBody), findsOneWidget);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
  });

  testWidgets('leave deletes the own row and hides the button', (tester) async {
    final api = _api(joined: {'c1'});
    await _pump(tester, api: api);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('challenge-leave')));
    await tester.pumpAndSettle();

    expect(api.leaves, ['c1']);
    expect(api.joined, isEmpty);
    expect(find.text('Challenge verlassen'), findsOneWidget, reason: 'the toast; the button is gone');
    expect(find.byKey(const ValueKey('challenge-leave')), findsNothing);
  });

  testWidgets('not joined: no leave button', (tester) async {
    await _pump(tester, api: _api());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('challenge-leave')), findsNothing);
  });

  testWidgets('an ended challenge shows the window and no leave button even when joined', (tester) async {
    final ended = endedWeekly();
    await _pump(tester, api: _api(joined: {'c0'}, boards: {'c0': kChallengeBoard}), challenge: ended);
    await tester.pumpAndSettle();

    expect(find.text('Wochen-Challenge: 20 Abfahrten'), findsOneWidget);
    expect(find.textContaining('–'), findsOneWidget, reason: 'Mo, 5. Jan – So, 11. Jan');
    expect(find.text('Noch 3 Tage'), findsNothing);
    expect(find.byKey(const ValueKey('challenge-leave')), findsNothing);
    expect(find.byType(ChallengeBoardRow), findsNWidgets(3));
  });

  testWidgets('loading shows the skeleton until the board arrives', (tester) async {
    final api = _api(gate: Completer<void>());
    await _pump(tester, api: api);

    expect(find.byKey(const ValueKey('challenge-board-skeleton')), findsOneWidget);
    expect(find.byType(ChallengeBoardRow), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('challenge-board-skeleton')), findsNothing);
    expect(find.byType(ChallengeBoardRow), findsNWidgets(3));
  });

  testWidgets('empty board', (tester) async {
    await _pump(tester, api: _api(boards: {}));
    await tester.pumpAndSettle();
    expect(find.text('Noch niemand dabei.'), findsOneWidget);
    expect(find.text('Mach mit, dann steht dein Name hier als Erster.'), findsOneWidget);
    expect(find.byType(ChallengeBoardRow), findsNothing);
  });

  testWidgets('offline: state block with retry that refetches', (tester) async {
    final api = _api(failWith: const SocialError(SocialErrorKind.offline));
    await _pump(tester, api: api);
    await tester.pumpAndSettle();

    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Die Challenge braucht Netz. Deine Skitage sind trotzdem sicher.'), findsOneWidget);
    expect(find.byType(ChallengeBoardRow), findsNothing);

    api.failWith = null;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.byType(ChallengeBoardRow), findsNWidgets(3));
  });

  testWidgets('no backend at all reads as offline', (tester) async {
    await _pump(tester, api: null);
    await tester.pumpAndSettle();
    expect(find.text('Keine Verbindung.'), findsOneWidget);
  });

  testWidgets('a server failure shows the generic line', (tester) async {
    await _pump(tester, api: _api(failWith: const SocialError(SocialErrorKind.failed, 'challenge_not_found')));
    await tester.pumpAndSettle();
    expect(find.text('Die Rangliste ließ sich nicht laden.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('signed out asks for a Konto', (tester) async {
    await _pump(tester, api: _api(userId: null), signedIn: false);
    await tester.pumpAndSettle();
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
    expect(find.byKey(const ValueKey('challenge-leave')), findsNothing);
  });
}
