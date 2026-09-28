import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/invite/invite_links.dart';
import 'package:slopetrack/features/social/social_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _de = FriendsStrings(AppLocale(Locale('de')));
const _en = FriendsStrings(AppLocale(Locale('en')));

void main() {
  group('FriendCode', () {
    test('normalises and validates like the duel codes', () {
      expect(FriendCode.normalise(' kmj-4f2 '), 'KMJ4F2');
      expect(FriendCode.isValid('KMJ4F2'), isTrue);
      expect(FriendCode.isValid('KMJ4F'), isFalse);
      expect(FriendCode.isValid('KMJ4F0'), isFalse, reason: '0 is not in the alphabet');
      expect(FriendCode.isValid('KMJ4FI'), isFalse, reason: 'I is not in the alphabet');
      expect(FriendCode.link('kmj4f2'), '${InviteLinks.share(InviteKind.friend, 'KMJ4F2')}');
    });

    test('share text carries the code and the link in both languages', () {
      expect(_de.shareText('kmj4f2'), 'Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2 · ${InviteLinks.share(InviteKind.friend, 'KMJ4F2')}');
      expect(_en.shareText('KMJ4F2'), 'Race me in SlopeTrack – friend code KMJ4F2 · ${InviteLinks.share(InviteKind.friend, 'KMJ4F2')}');
    });
  });

  group('Friend.fromJson', () {
    test('reads the friends_list row shape', () {
      final f = Friend.fromJson({
        'user_id': 'u7',
        'display_name': ' Nina Aigner ',
        'avatar_url': null,
        'country_code': 'ch',
        'status': 'pending',
        'incoming': true,
        'created_at': '2026-01-15T09:00:00+00:00',
      });
      expect(f.userId, 'u7');
      expect(f.displayName, 'Nina Aigner');
      expect(f.countryCode, 'CH');
      expect(f.isIncomingRequest, isTrue);
      expect(f.isOutgoingRequest, isFalse);
      expect(f.isAccepted, isFalse);
      expect(f.createdAt, isNotNull);
    });

    test('falls back for an empty name and a bad country', () {
      final f = Friend.fromJson({'user_id': 'u1', 'display_name': '', 'country_code': 'AUT', 'status': 'accepted'});
      expect(f.displayName, 'Skifahrer');
      expect(f.countryCode, isNull);
      expect(f.isAccepted, isTrue);
    });
  });

  group('SupabaseFriendsApi.mapError', () {
    FriendsErrorKind kind(String message) => SupabaseFriendsApi.mapError(PostgrestException(message: message)).kind;

    test('maps the 0007 RPC messages', () {
      expect(kind('code_not_found'), FriendsErrorKind.codeNotFound);
      expect(kind('already_friends'), FriendsErrorKind.alreadyFriends);
      expect(kind('request_not_found'), FriendsErrorKind.requestNotFound);
      expect(kind('not_signed_in'), FriendsErrorKind.notSignedIn);
      expect(kind('self'), FriendsErrorKind.self);
      expect(kind('something else'), FriendsErrorKind.failed);
      expect(kind('herself'), FriendsErrorKind.failed, reason: 'only the bare word is the self error');
    });

    test('network failures become offline', () {
      expect(SupabaseFriendsApi.mapError(Exception('SocketException: Failed host lookup')).kind, FriendsErrorKind.offline);
      expect(SupabaseFriendsApi.mapError(StateError('x')).kind, FriendsErrorKind.failed);
    });
  });

  group('providers', () {
    test('friendsBoardProvider hands wireKey and metric to the api', () async {
      final api = FakeFriendsApi(userId: 'u1', entries: const [
        LeaderboardEntry(rank: 1, userId: 'u9', displayName: 'Lena Bergmann', value: 24100, total: 2),
        LeaderboardEntry(rank: 2, userId: 'u1', displayName: 'Sebastian', value: 12480, total: 2),
      ]);
      final container = ProviderContainer(overrides: [
        friendsApiProvider.overrideWithValue(api),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u1', displayName: 'Sebastian'))),
      ]);
      addTearDown(container.dispose);
      final query = LeaderboardQuery.at(DateTime(2026, 1, 15), period: LeaderboardPeriod.week, metric: SocialMetric.points, countryCode: 'AT');
      final rows = await container.read(friendsBoardProvider(query).future);
      expect(rows, hasLength(2));
      expect(api.boardQueries.single.wireKey, '2026-W03');
      expect(api.boardQueries.single.metric, SocialMetric.points);
    });

    test('friends / pending / sent split the friendships list', () async {
      final api = FakeFriendsApi(userId: 'u1', friends: const [
        Friend(userId: 'u9', displayName: 'Zoe', status: FriendshipStatus.accepted),
        Friend(userId: 'u8', displayName: 'Anna', status: FriendshipStatus.accepted),
        Friend(userId: 'u7', displayName: 'Nina', status: FriendshipStatus.pending, incoming: true),
        Friend(userId: 'u6', displayName: 'Tom', status: FriendshipStatus.pending, incoming: false),
      ]);
      final container = ProviderContainer(overrides: [
        friendsApiProvider.overrideWithValue(api),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u1', displayName: 'Sebastian'))),
      ]);
      addTearDown(container.dispose);
      await container.read(friendshipsProvider.future);
      expect(container.read(friendsProvider).value!.map((f) => f.displayName), ['Anna', 'Zoe']);
      expect(container.read(pendingRequestsProvider).value!.map((f) => f.userId), ['u7']);
      expect(container.read(sentRequestsProvider).value!.map((f) => f.userId), ['u6']);
      expect(await container.read(myFriendCodeProvider.future), 'KMJ4F2');
    });

    test('without a backend the board throws offline and the code is null', () async {
      final container = ProviderContainer(overrides: [
        friendsApiProvider.overrideWithValue(null),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);
      final query = LeaderboardQuery.at(DateTime(2026, 1, 15));
      await expectLater(container.read(friendsBoardProvider(query).future), throwsA(isA<FriendsError>()));
      expect(await container.read(myFriendCodeProvider.future), isNull);
      await expectLater(container.read(friendshipsProvider.future), throwsA(isA<FriendsError>()));
    });

    test('signed out with a backend: empty list, no call', () async {
      final api = FakeFriendsApi();
      final container = ProviderContainer(overrides: [
        friendsApiProvider.overrideWithValue(api),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(friendshipsProvider.future), isEmpty);
      expect(api.listCalls, 0);
    });
  });

  test('every string exists in both languages and has no exclamation mark', () {
    for (final s in [_de, _en]) {
      final all = [
        s.title, s.myCode, s.myCodeLine, s.codeUnavailable, s.share, s.copy, s.copied, s.shareText('KMJ4F2'),
        s.addFriend, s.codeHint, s.add, s.requestSent, s.nowFriends, s.requests, s.accept, s.decline, s.sent,
        s.waiting, s.withdraw, s.accepted, s.declined, s.friendsCount(0), s.friendsCount(1), s.friendsCount(3),
        s.remove, s.removed, s.swipeHint, s.emptyLine, s.signedOutLine, s.offlineLine, s.retry,
        s.boardEmptyHeadline, s.boardEmptyLine, s.invite,
        for (final k in FriendsErrorKind.values) s.error(k),
      ];
      for (final t in all) {
        expect(t.trim(), isNotEmpty);
        expect(t.contains('!'), isFalse, reason: t);
      }
    }
    expect(_de.title, isNot(_en.title));
  });
}
