import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/theme/typography.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/invite/invite_links.dart';

import '../../../support/pump.dart';

const _de = FriendsStrings(AppLocale(Locale('de')));
const _user = AuthUser(id: 'u1', displayName: 'Sebastian Fackelmann');

const kLena = Friend(userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT');
const kPaul = Friend(userId: 'u8', displayName: 'Paul Moser', countryCode: 'DE');
const kNinaRequest = Friend(userId: 'u7', displayName: 'Nina Aigner', countryCode: 'CH', status: FriendshipStatus.pending, incoming: true);
const kTomSent = Friend(userId: 'u6', displayName: 'Tom Huber', status: FriendshipStatus.pending, incoming: false);

List<Override> _overrides({FakeFriendsApi? api, AuthUser? user = _user, List<(String, String?)>? shared}) => [
      friendsApiProvider.overrideWithValue(api),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      if (shared != null) friendsShareProvider.overrideWithValue((text, {subject}) async => shared.add((text, subject))),
    ];

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1179, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpApp(tester, const Scaffold(body: FriendsSheetBody()), overrides: overrides);
  await tester.pumpAndSettle();
}

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the own code big with the overline above it', (tester) async {
    await _pump(tester, _overrides(api: FakeFriendsApi(userId: 'u1', code: 'KMJ4F2')));

    expect(find.byKey(const ValueKey('friends-signed-in')), findsOneWidget);
    expect(find.text('KMJ4F2'), findsOneWidget);
    expect(find.text('DEIN FREUNDESCODE'), findsOneWidget);
    expect(find.text(_de.share), findsOneWidget);
    expect(find.text(_de.friendsCount(0).overline), findsOneWidget);
    expect(find.text(_de.emptyLine), findsOneWidget);
  });

  testWidgets('Teilen hands the invite text with code and link to the share sink', (tester) async {
    final shared = <(String, String?)>[];
    await _pump(tester, _overrides(api: FakeFriendsApi(userId: 'u1', code: 'KMJ4F2'), shared: shared));

    await tester.tap(find.byKey(const ValueKey('friends-share')));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single.$1, 'Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2 · ${InviteLinks.share(InviteKind.friend, 'KMJ4F2')}');
    expect(shared.single.$2, 'Freunde');
  });

  testWidgets('entering a code calls addFriend and the request shows under Gesendet', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', byCode: {'ABC234': kTomSent});
    await _pump(tester, _overrides(api: api));

    // The add button waits for six valid characters.
    await tester.enterText(find.byKey(const ValueKey('friends-code-field')), 'ab');
    await tester.pumpAndSettle();
    expect(tester.widget<SecondaryButton>(find.byKey(const ValueKey('friends-add'))).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('friends-code-field')), 'abc234xyz');
    await tester.pumpAndSettle();
    expect(find.text('ABC234'), findsOneWidget, reason: 'upper-cased and limited to six characters');

    await tester.tap(find.byKey(const ValueKey('friends-add')));
    await tester.pumpAndSettle();

    expect(api.added, ['ABC234']);
    expect(find.text(_de.requestSent), findsOneWidget);
    expect(find.text('Tom Huber'), findsOneWidget);
    expect(find.text(_de.waiting), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('friends-code-field'))).controller!.text, isEmpty);
    await _settleToast(tester);
  });

  testWidgets('a wrong or own code is answered with a toast, not an exception', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', code: 'KMJ4F2');
    await _pump(tester, _overrides(api: api));

    await tester.enterText(find.byKey(const ValueKey('friends-code-field')), 'ZZZZZZ');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friends-add')));
    await tester.pumpAndSettle();
    expect(find.text(_de.error(FriendsErrorKind.codeNotFound)), findsOneWidget);
    await _settleToast(tester);

    await tester.enterText(find.byKey(const ValueKey('friends-code-field')), 'kmj4f2');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friends-add')));
    await tester.pumpAndSettle();
    expect(find.text(_de.error(FriendsErrorKind.self)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _settleToast(tester);
  });

  testWidgets('accepting a pending request moves the rider into the friend list', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [kLena, kNinaRequest]);
    await _pump(tester, _overrides(api: api));

    expect(find.text(_de.requests.overline), findsOneWidget);
    expect(find.byKey(const ValueKey('friends-request-u7')), findsOneWidget);
    expect(find.text(_de.friendsCount(1).overline), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friends-accept-u7')));
    await tester.pumpAndSettle();

    expect(api.accepted, ['u7']);
    expect(find.text(_de.requests.overline), findsNothing);
    expect(find.text(_de.friendsCount(2).overline), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-u7')), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-u9')), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('declining a request removes it without adding a friend', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [kNinaRequest]);
    await _pump(tester, _overrides(api: api));

    await tester.tap(find.byKey(const ValueKey('friends-decline-u7')));
    await tester.pumpAndSettle();

    expect(api.removed, ['u7']);
    expect(find.text(_de.requests.overline), findsNothing);
    expect(find.text(_de.friendsCount(0).overline), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('swiping a friend to the left removes the friendship', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [kLena, kPaul]);
    await _pump(tester, _overrides(api: api));

    expect(find.text(_de.friendsCount(2).overline), findsOneWidget);
    expect(find.text('Lena Bergmann 🇦🇹'), findsOneWidget);

    await tester.drag(find.byKey(const ValueKey('friend-u9')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(api.removed, ['u9']);
    expect(find.text(_de.friendsCount(1).overline), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-u9')), findsNothing);
    expect(find.byKey(const ValueKey('friend-u8')), findsOneWidget);
    expect(find.text(_de.removed), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('a failing remove keeps the row', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [kLena]);
    await _pump(tester, _overrides(api: api));
    api.failWith = const FriendsError(FriendsErrorKind.offline);

    await tester.drag(find.byKey(const ValueKey('friend-u9')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('friend-u9')), findsOneWidget);
    expect(find.text(_de.error(FriendsErrorKind.offline)), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('signed out: the Rider and one line, no code', (tester) async {
    await _pump(tester, _overrides(api: FakeFriendsApi(), user: null));
    expect(find.byKey(const ValueKey('friends-signed-out')), findsOneWidget);
    expect(find.text(_de.signedOutLine), findsOneWidget);
    expect(find.byKey(const ValueKey('friends-my-code')), findsNothing);
  });

  testWidgets('without a backend the sheet is offline, not broken', (tester) async {
    await _pump(tester, _overrides(api: null));
    expect(find.byKey(const ValueKey('friends-offline')), findsOneWidget);
    expect(find.text(_de.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing list shows the error line with retry and recovers', (tester) async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [kLena], failWith: const FriendsError(FriendsErrorKind.offline));
    await _pump(tester, _overrides(api: api));
    expect(find.text(_de.error(FriendsErrorKind.offline)), findsOneWidget);

    api.failWith = null;
    await tester.tap(find.text(_de.retry));
    await tester.pumpAndSettle();
    expect(find.text(_de.friendsCount(1).overline), findsOneWidget);
    expect(find.text('KMJ4F2'), findsOneWidget);
  });

  testWidgets('English copy', (tester) async {
    tester.view.physicalSize = const Size(1179, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(body: FriendsSheetBody()),
      overrides: _overrides(api: FakeFriendsApi(userId: 'u1', friends: const [kNinaRequest])),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    expect(find.text('YOUR FRIEND CODE'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('NO FRIENDS YET'), findsOneWidget);
  });
}
