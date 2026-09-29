import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';
import 'package:slopetrack/features/social/rider/rider.dart';
import 'package:slopetrack/features/social/social_api.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'rider_fixtures.dart';

/// RiderSheet with the DEFAULT `riderActionsProvider` (SOC-LOOP): the
/// 'Freund hinzufügen' slot is filled with `addFriendFromRider`, which goes
/// through `SocialApi.addFriendById` (RPC add_friend_by_id, 0013) and then
/// refetches the friends providers.
Future<void> _pump(
  WidgetTester tester, {
  required FakeSocialApi social,
  FakeRiderApi? rider,
  FakeFriendsApi? friends,
  FakeModerationApi? mod,
  String userId = 'u9',
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1179, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final overrides = <Override>[
    ...screenOverrides(resorts: kResorts),
    ...socialOverrides(api: social, user: social.userId == null ? null : kUser),
    riderApiProvider.overrideWithValue(rider ?? FakeRiderApi(profiles: {'u9': kLena})),
    moderationApiProvider.overrideWithValue(mod ?? FakeModerationApi(userId: social.userId)),
    friendsApiProvider.overrideWithValue(friends ?? FakeFriendsApi(userId: social.userId)),
  ];
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: const EdgeInsets.all(20), child: RiderSheetBody(userId: userId))),
    overrides: overrides,
    locale: locale,
  );
  await tester.pumpAndSettle();
}

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a stranger shows Freund hinzufügen; tapping sends the request for the user id and toasts', (tester) async {
    final social = FakeSocialApi(userId: 'u1');
    final friends = FakeFriendsApi(userId: 'u1');
    await _pump(tester, social: social, friends: friends);

    expect(find.text('Freund hinzufügen'), findsOneWidget);
    expect(find.text('Herausfordern'), findsOneWidget);
    expect(find.text('Melden'), findsOneWidget);
    expect(find.text('Blockieren'), findsOneWidget);

    await tester.tap(find.text('Freund hinzufügen'));
    await tester.pumpAndSettle();

    expect(social.friendRequests, ['u9'], reason: 'add_friend_by_id with the rider id');
    expect(find.text('Anfrage gesendet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settleToast(tester);
  });

  testWidgets('when the other side had asked first the toast says Ihr seid jetzt Freunde', (tester) async {
    final social = FakeSocialApi(userId: 'u1', friendsToAccept: {'u9'});
    await _pump(tester, social: social);

    await tester.tap(find.text('Freund hinzufügen'));
    await tester.pumpAndSettle();
    expect(social.friendRequests, ['u9']);
    expect(find.text('Ihr seid jetzt Freunde'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('English toast', (tester) async {
    final social = FakeSocialApi(userId: 'u1');
    await _pump(tester, social: social, locale: const Locale('en'));
    expect(find.text('Add friend'), findsOneWidget);
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('the own profile has no Freund hinzufügen (nor challenge, report, block)', (tester) async {
    const me = RiderProfile(userId: 'u1', displayName: 'Sebastian Fackelmann', seasonKey: '2025/26');
    await _pump(tester, social: FakeSocialApi(userId: 'u1'), rider: FakeRiderApi(profiles: {'u1': me}), userId: 'u1');

    expect(find.text('Sebastian Fackelmann'), findsOneWidget);
    expect(find.text('Freund hinzufügen'), findsNothing);
    expect(find.text('Herausfordern'), findsNothing);
    expect(find.text('Melden'), findsNothing);
    expect(find.text('Blockieren'), findsNothing);
  });

  testWidgets('a blocked rider has no Freund hinzufügen', (tester) async {
    await _pump(tester, social: FakeSocialApi(userId: 'u1'), mod: FakeModerationApi(userId: 'u1', blocked: const {'u9'}));

    expect(find.byKey(const ValueKey('rider-blocked')), findsOneWidget);
    expect(find.text('Freund hinzufügen'), findsNothing);
    expect(find.text('Herausfordern'), findsNothing);
    expect(find.text('Blockierung aufheben'), findsOneWidget);
  });

  testWidgets('signed out, the button asks for an account and sends nothing', (tester) async {
    final social = FakeSocialApi();
    await _pump(tester, social: social);

    await tester.tap(find.text('Freund hinzufügen'));
    await tester.pumpAndSettle();
    expect(social.friendRequests, isEmpty);
    expect(find.text('Dafür brauchst du ein Konto'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('a failed request is answered with a toast, not an exception', (tester) async {
    final social = FakeSocialApi(userId: 'u1');
    await _pump(tester, social: social);

    social.failWith = const SocialError(SocialErrorKind.alreadyFriends);
    await tester.tap(find.text('Freund hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Ihr seid schon verbunden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settleToast(tester);
  });
}
