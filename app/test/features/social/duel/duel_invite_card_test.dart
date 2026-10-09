import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'duel_fixtures.dart';

const _accept = ValueKey('duel-invite-accept');
const _decline = ValueKey('duel-invite-decline');

Future<void> _pump(WidgetTester tester, FakeDuelApi api, {Duration? poll, String? ownUserId = 'u1', Locale locale = const Locale('de')}) async {
  await pumpApp(
    tester,
    Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(child: DuelCard(resortId: 'kitzbuehel', ownUserId: ownUserId, now: kDuelNow, showHistory: false)),
    ),
    locale: locale,
    overrides: [
      ...screenOverrides(settings: const Settings(onboardingDone: true, lastResortId: 'kitzbuehel'), resorts: kResorts),
      ...duelOverrides(api: api, user: ownUserId == null ? null : kUser, poll: poll),
    ],
  );
  await tester.pumpAndSettle();
}

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pending invite renders the card with the sender name above the start/join card', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()]);
    await _pump(tester, api);

    expect(api.myInvitesCalls, 1);
    expect(find.byType(DuelInviteCard), findsOneWidget);
    expect(find.text('Duell-Einladung von Lena'), findsOneWidget);
    expect(find.text('Hahnenkamm-Crew · 1 / 3'), findsOneWidget, reason: 'duel name and members over capacity; no day label for today');
    expect(find.text('Annehmen'), findsOneWidget);
    expect(find.text('Ablehnen'), findsOneWidget);
    expect(find.byKey(const ValueKey('duel-invite-hint')), findsNothing);
    expect(find.byKey(const ValueKey('duel-invite-more')), findsNothing);

    // The start/join card stays, but 'Annehmen' is the only champagne CTA.
    expect(find.text('Duell starten'), findsOneWidget);
    expect(find.text('Code eingeben'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).label, 'Annehmen');
    expect(tester.widget<AppCard>(find.byKey(const ValueKey('duel-invite-inv-1'))).tone, CardTone.accent);
  });

  testWidgets('Annehmen calls respond, refreshes myDuel and the card becomes the duel board', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()]);
    await _pump(tester, api);
    expect(api.myDuelCalls, 1);

    await tester.tap(find.byKey(_accept));
    await tester.pumpAndSettle();

    expect(api.responses, [('inv-1', true)]);
    expect(api.myDuelCalls, 2, reason: 'myDuelProvider is refetched after the accept');
    expect(api.boardCalls, ['g-lena']);
    expect(find.byType(DuelInviteCard), findsNothing);
    expect(find.text('HAHNENKAMM-CREW'), findsOneWidget);
    expect(find.text('PQRS23'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Lena'), findsOneWidget);
    expect(find.text('Du'), findsOneWidget);
    expect(find.text('Du bist dabei'), findsOneWidget);
    expect(find.text('Duell starten'), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('Ablehnen calls respond and removes the card; the start button is the CTA again', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()]);
    await _pump(tester, api);

    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();

    expect(api.responses, [('inv-1', false)]);
    expect(find.byType(DuelInviteCard), findsNothing);
    expect(find.text('Duell-Einladung von Lena'), findsNothing);
    expect(find.text('Einladung abgelehnt'), findsOneWidget);
    expect(api.duel, isNull);
    expect(find.text('Duell starten'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).label, 'Duell starten');
    await _settleToast(tester);
  });

  testWidgets('a full duel switches Annehmen off and says why; Ablehnen still works', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite(memberCount: 3)]);
    await _pump(tester, api);

    expect(find.text('Hahnenkamm-Crew · 3 / 3'), findsOneWidget);
    expect(find.text('Das Duell ist inzwischen voll.'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byKey(_accept)).onPressed, isNull);

    await tester.tap(find.byKey(_accept), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(api.responses, isEmpty);

    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(api.responses, [('inv-1', false)]);
    expect(find.byType(DuelInviteCard), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('duel_full from the server on accept: toast, no membership, the invite is refetched', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()], respondError: const SocialError(SocialErrorKind.duelFull));
    await _pump(tester, api);

    // The duel filled up since the last poll; the refetch delivers 3 / 3.
    api.invites = [duelInvite(memberCount: 3)];
    await tester.tap(find.byKey(_accept));
    await tester.pumpAndSettle();

    expect(api.responses, [('inv-1', true)]);
    expect(api.duel, isNull);
    expect(find.text('Das Duell ist voll'), findsOneWidget, reason: 'toast from the shared error copy');
    expect(api.myInvitesCalls, 2);
    expect(find.text('Hahnenkamm-Crew · 3 / 3'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byKey(_accept)).onPressed, isNull);
    await _settleToast(tester);
  });

  testWidgets('an invite answered elsewhere: invite_not_found has its own line and the card goes away', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()]);
    await _pump(tester, api);

    api.invites = [];
    await tester.tap(find.byKey(_accept));
    await tester.pumpAndSettle();

    expect(find.text('Diese Einladung gibt es nicht mehr'), findsOneWidget);
    expect(find.text('Diesen Fahrer gibt es nicht mehr'), findsNothing);
    expect(find.byType(DuelInviteCard), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('already in a duel that day: the invite is plain, Annehmen is off with the reason', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard, invites: [duelInvite()]);
    await _pump(tester, api);

    expect(find.text('Duell-Einladung von Lena'), findsOneWidget);
    expect(find.text('Du bist an diesem Tag schon in einem Duell. Verlasse es, um anzunehmen.'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byKey(_accept)).onPressed, isNull);
    expect(tester.widget<AppCard>(find.byKey(const ValueKey('duel-invite-inv-1'))).tone, CardTone.plain, reason: 'the running duel carries the accent');
    expect(find.text('KMJ4F2'), findsOneWidget, reason: 'the own duel stays on screen');

    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(api.responses, [('inv-1', false)]);
    expect(find.byType(DuelInviteCard), findsNothing);
    expect(find.text('KMJ4F2'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('an invite into another day can be accepted next to today\'s duel and carries the day label', (tester) async {
    final api = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kLiveBoard, invites: [duelInvite(day: DateTime(2026, 1, 14))]);
    await _pump(tester, api);

    expect(find.text('Hahnenkamm-Crew · Gestern · 1 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('duel-invite-hint')), findsNothing);
    expect(tester.widget<PrimaryButton>(find.byKey(_accept)).onPressed, isNotNull);
  });

  testWidgets('several invites: the newest is shown with a count, the next follows after the answer', (tester) async {
    final api = FakeDuelApi(
      userId: 'u1',
      invites: [duelInvite(), duelInvite(id: 'inv-2', fromUserId: 'u8', fromName: 'Paul', groupId: 'g-paul', code: 'ABCD23', name: 'Tagesduell')],
    );
    await _pump(tester, api);

    expect(find.text('Duell-Einladung von Lena'), findsOneWidget);
    expect(find.text('Duell-Einladung von Paul'), findsNothing);
    expect(find.text('+ 1 weitere Einladung'), findsOneWidget);

    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();

    expect(find.text('Duell-Einladung von Paul'), findsOneWidget);
    expect(find.text('Tagesduell · 1 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('duel-invite-more')), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('the 60 s poll brings a new invite onto the card', (tester) async {
    final api = FakeDuelApi(userId: 'u1');
    await _pump(tester, api, poll: const Duration(milliseconds: 100));
    expect(find.byType(DuelInviteCard), findsNothing);
    final before = api.myInvitesCalls;

    api.invites = [duelInvite()];
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle();

    expect(api.myInvitesCalls, greaterThan(before));
    expect(find.text('Duell-Einladung von Lena'), findsOneWidget);

    // The timer dies with the card — no pending timer survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('without polling the invites are fetched once', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()]);
    await _pump(tester, api);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.myInvitesCalls, 1);
  });

  testWidgets('signed out there is no invite call and no card', (tester) async {
    final api = FakeDuelApi(invites: [duelInvite()]);
    await _pump(tester, api, ownUserId: null);
    expect(api.myInvitesCalls, 0);
    expect(find.byType(DuelInviteCard), findsNothing);
    expect(find.text('Duell starten'), findsOneWidget);
  });

  testWidgets('a failing invite call keeps the card away and the rest of the duel card intact', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite()], failWith: const SocialError(SocialErrorKind.offline));
    await _pump(tester, api);
    expect(find.byType(DuelInviteCard), findsNothing);
    // The same failure hides today's duel too: the card says so and offers a retry.
    expect(find.text('Keine Verbindung.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('English copy; a sender without a name gets the bare title', (tester) async {
    final api = FakeDuelApi(userId: 'u1', invites: [duelInvite(fromName: ''), duelInvite(id: 'inv-2'), duelInvite(id: 'inv-3')]);
    await _pump(tester, api, locale: const Locale('en'));
    expect(find.text('Duel invite'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('+ 2 more invites'), findsOneWidget);

    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(find.text('Duel invite from Lena'), findsOneWidget);
    expect(find.text('Invite declined'), findsOneWidget);
    await _settleToast(tester);
  });
}
