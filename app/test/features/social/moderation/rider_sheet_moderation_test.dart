import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';
import 'package:slopetrack/features/social/rider/rider.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../rider/rider_fixtures.dart';
import '../social_fixtures.dart';

/// RiderSheet with the DEFAULT riderActionsProvider (SOC-MODERATION fills
/// report/block there) and the moderation fakes.
Future<void> _pump(WidgetTester tester, {required FakeModerationApi mod, FakeFriendsApi? friends, Locale locale = const Locale('de')}) async {
  tester.view.physicalSize = const Size(1179, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final social = FakeSocialApi(userId: 'u1');
  final overrides = <Override>[
    ...screenOverrides(resorts: kResorts),
    ...socialOverrides(api: social, user: kUser),
    riderApiProvider.overrideWithValue(FakeRiderApi(profiles: {'u9': kLena})),
    moderationApiProvider.overrideWithValue(mod),
    friendsApiProvider.overrideWithValue(friends ?? FakeFriendsApi(userId: 'u1')),
  ];
  await pumpApp(
    tester,
    Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: const EdgeInsets.all(20), child: const RiderSheetBody(userId: 'u9'))),
    overrides: overrides,
    locale: locale,
  );
  await tester.pumpAndSettle();
}

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the profile shows Melden and Blockieren by default', (tester) async {
    await _pump(tester, mod: FakeModerationApi(userId: 'u1'));
    expect(find.text('Melden'), findsOneWidget);
    expect(find.text('Blockieren'), findsOneWidget);
    expect(find.text('Herausfordern'), findsOneWidget);
    expect(find.byKey(const ValueKey('rider-blocked')), findsNothing);
  });

  testWidgets('Melden opens the ReportSheet and the api receives (targetUserId, reason)', (tester) async {
    final mod = FakeModerationApi(userId: 'u1');
    await _pump(tester, mod: mod);

    await tester.tap(find.text('Melden'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-sheet')), findsOneWidget);
    expect(find.text('Was stimmt mit dem Profil von Lena Bergmann nicht?'), findsOneWidget);

    await tester.tap(find.text('Anstößiger Name'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();

    expect(mod.reports, [('u9', 'offensive_name')]);
    expect(find.byKey(const ValueKey('report-sheet')), findsNothing, reason: 'sheet closed');
    expect(find.text('Danke, wir schauen uns das an'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('Blockieren asks first; confirming blocks and the profile shows Blockiert', (tester) async {
    final mod = FakeModerationApi(userId: 'u1');
    final friends = FakeFriendsApi(userId: 'u1', friends: const [Friend(userId: 'u9', displayName: 'Lena Bergmann')]);
    await _pump(tester, mod: mod, friends: friends);

    await tester.tap(find.text('Blockieren'));
    await tester.pumpAndSettle();
    expect(find.text('Lena Bergmann blockieren?'), findsOneWidget);
    expect(mod.blocked, isEmpty, reason: 'nothing happens before the confirmation');

    await tester.tap(find.byKey(const ValueKey('block-confirm')));
    await tester.pumpAndSettle();

    expect(mod.blocked, {'u9'});
    expect(friends.removed, ['u9']);
    expect(find.byKey(const ValueKey('rider-blocked')), findsOneWidget);
    expect(find.text('Blockiert'), findsWidgets);
    expect(find.text('Blockieren'), findsNothing);
    expect(find.text('Herausfordern'), findsNothing);
    expect(find.text('Blockierung aufheben'), findsOneWidget);
    await _settleToast(tester);

    await tester.tap(find.byKey(const ValueKey('rider-unblock')));
    await tester.pumpAndSettle();
    expect(mod.blocked, isEmpty);
    expect(find.byKey(const ValueKey('rider-blocked')), findsNothing);
    expect(find.text('Blockieren'), findsOneWidget);
    expect(find.text('Herausfordern'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('an already blocked rider opens in the blocked state', (tester) async {
    await _pump(tester, mod: FakeModerationApi(userId: 'u1', blocked: const {'u9'}));
    expect(find.byKey(const ValueKey('rider-blocked')), findsOneWidget);
    expect(find.text('Blockieren'), findsNothing);
    expect(find.text('Melden'), findsOneWidget, reason: 'reporting stays possible');
  });

  testWidgets('English copy', (tester) async {
    await _pump(tester, mod: FakeModerationApi(userId: 'u1', blocked: const {'u9'}), locale: const Locale('en'));
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
  });
}
