@Skip('SOC-DEEPLINK unfinished 2026-09-28: the listener does not process links yet and is not mounted in the app')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/invite/invite.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian');
const _duel = 'https://slopetrack.app/d/KMJ4F2';

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(WidgetTester tester, List<Override> overrides) async {
  final key = GlobalKey();
  await pumpApp(tester, InviteListener(key: key, child: const Scaffold(body: Text('shell'))), overrides: overrides);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(key.currentContext!);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('signed in: link joins the duel via SocialApi, toast, Rangliste requested', (tester) async {
    final source = FakeInviteLinkSource();
    final social = FakeSocialApi(userId: 'u1');
    final container = await _pump(tester, [
      inviteLinkSourceProvider.overrideWithValue(source),
      socialApiProvider.overrideWithValue(social),
      friendsApiProvider.overrideWithValue(FakeFriendsApi(userId: 'u1')),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
    ]);
    expect(container.read(inviteLinkHandlerProvider).isStarted, isTrue);

    source.emit(_duel);
    await tester.pumpAndSettle();

    expect(social.joined, ['KMJ4F2']);
    expect(find.text('Duell KMJ4F2 beigetreten'), findsOneWidget);
    expect(container.read(ranglisteRequestProvider), 1);
    await _settleToast(tester);
    await source.close();
  });

  testWidgets('signed in: /f link sends the friend request through FriendsApi', (tester) async {
    final source = FakeInviteLinkSource();
    final friends = FakeFriendsApi(userId: 'u1', byCode: {'ABC234': const Friend(userId: 'u9', displayName: 'Lena')});
    final container = await _pump(tester, [
      inviteLinkSourceProvider.overrideWithValue(source),
      socialApiProvider.overrideWithValue(FakeSocialApi(userId: 'u1')),
      friendsApiProvider.overrideWithValue(friends),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
    ]);

    source.emit('slopetrack://f/ABC234');
    await tester.pumpAndSettle();

    expect(friends.added, ['ABC234']);
    expect(find.text('Freundschaftsanfrage gesendet'), findsOneWidget);
    expect(container.read(ranglisteRequestProvider), 1);
    await _settleToast(tester);
    await source.close();
  });

  testWidgets('signed out: code persisted in SharedPreferences, consumed once after sign-in', (tester) async {
    final source = FakeInviteLinkSource();
    final social = FakeSocialApi(userId: 'u1');
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    final container = await _pump(tester, [
      inviteLinkSourceProvider.overrideWithValue(source),
      socialApiProvider.overrideWithValue(social),
      friendsApiProvider.overrideWithValue(FakeFriendsApi(userId: 'u1')),
      authStateProvider.overrideWith((ref) => auth.stream),
    ]);
    auth.add(null);
    await tester.pumpAndSettle();

    source.emit(_duel);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SharedPrefsPendingInviteStore.key), 'd:KMJ4F2');
    expect(social.joined, isEmpty);
    expect(find.text('Duell gemerkt – melde dich im Konto an'), findsOneWidget);
    expect(container.read(ranglisteRequestProvider), 0);
    await _settleToast(tester);

    auth.add(_user);
    await tester.pumpAndSettle();

    expect(social.joined, ['KMJ4F2']);
    expect(prefs.containsKey(SharedPrefsPendingInviteStore.key), isFalse);
    expect(find.text('Duell KMJ4F2 beigetreten'), findsOneWidget);
    expect(container.read(ranglisteRequestProvider), 1);
    await _settleToast(tester);

    // A second auth event with the same user must not join again.
    auth.add(_user);
    await tester.pumpAndSettle();
    expect(social.joined, ['KMJ4F2']);
    await source.close();
  });

  testWidgets('a duel_full error shows the social module copy and does not switch tabs', (tester) async {
    final source = FakeInviteLinkSource();
    final container = await _pump(tester, [
      inviteLinkSourceProvider.overrideWithValue(source),
      socialApiProvider.overrideWithValue(FakeSocialApi(userId: 'u1', failWith: const SocialError(SocialErrorKind.duelFull))),
      friendsApiProvider.overrideWithValue(FakeFriendsApi(userId: 'u1')),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
    ]);

    source.emit(_duel);
    await tester.pumpAndSettle();

    expect(find.text('Das Duell ist voll'), findsOneWidget);
    expect(container.read(ranglisteRequestProvider), 0);
    await _settleToast(tester);
    await source.close();
  });

  testWidgets('without a backend the link is kept for later instead of failing', (tester) async {
    final source = FakeInviteLinkSource();
    await _pump(tester, [
      inviteLinkSourceProvider.overrideWithValue(source),
      socialApiProvider.overrideWithValue(null),
      friendsApiProvider.overrideWithValue(null),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);

    source.emit(_duel);
    await tester.pumpAndSettle();

    expect(find.text('Duell gemerkt – melde dich im Konto an'), findsOneWidget);
    await _settleToast(tester);
    await source.close();
  });
}
