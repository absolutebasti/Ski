import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../rider/rider_fixtures.dart';
import '../social_fixtures.dart';
import 'duel_fixtures.dart';

/// RiderSheet 'Herausfordern' with a DuelApi that knows invites (0017):
/// create_duel (or today's duel) + invite_to_duel, then 'Code teilen'.
/// The share-only fallback of the SocialApi adapter is covered by
/// test/features/social/rider/rider_sheet_test.dart.

const kLenaShort = RiderProfile(userId: 'u9', displayName: 'Lena', countryCode: 'AT', seasonKey: '2025/26');

const _caption = ValueKey('rider-challenge-caption');
const _shareCode = ValueKey('rider-share-code');

Future<void> _pump(
  WidgetTester tester, {
  required FakeDuelApi duel,
  ShareRecorder? share,
  bool signedIn = true,
  Locale locale = const Locale('de'),
}) async {
  // Tall viewport: caption, 'Code teilen' and the action buttons stay tappable.
  tester.view.physicalSize = const Size(1179, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: EdgeInsets.all(20), child: RiderSheetBody(userId: 'u9'))),
    locale: locale,
    overrides: [
      ...screenOverrides(resorts: kResorts),
      ...duelOverrides(api: duel, social: FakeSocialApi(userId: signedIn ? 'u1' : null), user: signedIn ? kUser : null),
      ...riderOverrides(api: FakeRiderApi(profiles: {'u9': kLenaShort}), share: share),
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
  testWidgets('Herausfordern calls create_duel + invite_to_duel and toasts "Einladung an Lena gesendet"', (tester) async {
    final duel = FakeDuelApi(userId: 'u1');
    final share = ShareRecorder();
    await _pump(tester, duel: duel, share: share);

    expect(tester.widget<Text>(find.byKey(_caption)).data, 'Lädt in dein Tagesduell ein. Die Einladung erscheint in der Rangliste.');
    expect(find.byKey(_shareCode), findsNothing);

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(duel.created, ['Tagesduell']);
    expect(duel.createdTz.single, contains('/'));
    expect(duel.invited, [('u9', 'group-1')]);
    expect(find.text('Einladung an Lena gesendet'), findsOneWidget);
    expect(share.shared, isEmpty, reason: 'the invite travels in-app; the share sheet only opens on Code teilen');
    expect(tester.widget<Text>(find.byKey(_caption)).data, 'Einladung ist raus. Der Code geht auch per Nachricht.');
    await _settleToast(tester);
  });

  testWidgets('after the invite the sheet still offers Code teilen with the one duel share text', (tester) async {
    final duel = FakeDuelApi(userId: 'u1');
    final share = ShareRecorder();
    await _pump(tester, duel: duel, share: share);

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();
    expect(find.text('Code teilen'), findsOneWidget);

    await tester.tap(find.byKey(_shareCode));
    await tester.pumpAndSettle();

    expect(share.shared, hasLength(1));
    expect(share.shared.single.$1, const InviteStrings(AppLocale(Locale('de'))).duelShareText('KMJ4F2'));
    expect(share.shared.single.$1, isNot(contains('id0000000000')));
    expect(share.shared.single.$2, 'Tagesduell');
    await _settleToast(tester);
  });

  testWidgets('today\'s duel is reused instead of creating a second one', (tester) async {
    final duel = FakeDuelApi(userId: 'u1', duel: duelGroup(code: 'PQRS23'), board: const [DuelMember(userId: 'u1', displayName: 'Du')]);
    await _pump(tester, duel: duel, share: ShareRecorder());

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(duel.created, isEmpty);
    expect(duel.invited, [('u9', 'g1')]);
    expect(find.text('Einladung an Lena gesendet'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('a rider who is already in the duel gets their own line and no Code teilen', (tester) async {
    final duel = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: const [DuelMember(userId: 'u1', displayName: 'Du'), DuelMember(userId: 'u9', displayName: 'Lena')]);
    await _pump(tester, duel: duel, share: ShareRecorder());

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(duel.invited, [('u9', 'g1')]);
    expect(find.text('Lena ist schon in deinem Duell'), findsOneWidget);
    expect(find.text('Du bist dabei'), findsNothing);
    expect(find.byKey(_shareCode), findsNothing);
    await _settleToast(tester);
  });

  testWidgets('a full duel and a rate limit become readable toasts', (tester) async {
    final duel = FakeDuelApi(userId: 'u1', duel: duelGroup(), board: kFinalBoard.where((m) => m.userId != 'u9').toList());
    await _pump(tester, duel: duel, share: ShareRecorder());
    expect(duel.board, hasLength(3));

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();
    expect(find.text('Das Duell ist voll'), findsOneWidget);
    expect(find.byKey(_shareCode), findsNothing);
    await _settleToast(tester);

    duel.inviteError = const SocialError(SocialErrorKind.rateLimited);
    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();
    expect(find.text('Zu viele Anfragen. Versuch es gleich noch einmal.'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('English: caption, toast and Share code', (tester) async {
    final duel = FakeDuelApi(userId: 'u1');
    await _pump(tester, duel: duel, share: ShareRecorder(), locale: const Locale('en'));
    expect(tester.widget<Text>(find.byKey(_caption)).data, 'Invites them to your day duel. The invite shows up on their leaderboard tab.');

    await tester.tap(find.text('Challenge'));
    await tester.pumpAndSettle();

    expect(find.text('Invite sent to Lena'), findsOneWidget);
    expect(find.text('Share code'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('signed out, Herausfordern asks for an account and calls nothing', (tester) async {
    final duel = FakeDuelApi();
    final share = ShareRecorder();
    await _pump(tester, duel: duel, share: share, signedIn: false);

    await tester.tap(find.text('Herausfordern'));
    await tester.pumpAndSettle();

    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
    expect(duel.created, isEmpty);
    expect(duel.invited, isEmpty);
    expect(share.shared, isEmpty);
    await _settleToast(tester);
  });

  test('no share text of the duel module or the rider sheet carries the placeholder store id', () {
    for (final locale in const [Locale('de'), Locale('en')]) {
      final l = AppLocale(locale);
      for (final t in [
        DuelCardShare.text(SocialStrings(l), 'KMJ4F2'),
        RiderStrings(l).challengeText('Lena', 'KMJ4F2'),
        InviteStrings(l).duelShareText('KMJ4F2'),
      ]) {
        expect(t, contains('KMJ4F2'));
        expect(t, isNot(contains('id0000000000')));
      }
    }
    final files = [
      ...Directory('lib/features/social/duel').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
      File('lib/features/social/rider/rider_sheet.dart'),
    ];
    expect(files.length, greaterThan(5), reason: 'test runs from the app directory');
    for (final f in files) {
      expect(f.readAsStringSync(), isNot(contains('id0000000000')), reason: f.path);
    }
  });
}
