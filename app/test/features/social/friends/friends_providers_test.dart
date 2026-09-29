import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/friends/friends.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian Fackelmann');

const _lena = Friend(userId: 'u9', displayName: 'Lena Bergmann');
const _ninaRequest = Friend(userId: 'u7', displayName: 'Nina Aigner', status: FriendshipStatus.pending, incoming: true);
const _paulRequest = Friend(userId: 'u8', displayName: 'Paul Moser', status: FriendshipStatus.pending, incoming: true);
const _tomSent = Friend(userId: 'u6', displayName: 'Tom Huber', status: FriendshipStatus.pending, incoming: false);

ProviderContainer _container({FakeFriendsApi? api, AuthUser? user = _user}) {
  final c = ProviderContainer(
    overrides: [
      friendsApiProvider.overrideWithValue(api),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle(ProviderContainer c) async {
  // authStateProvider's first value arrives asynchronously and re-runs
  // friendshipsProvider once; wait for the final result.
  await Future<void>.delayed(Duration.zero);
  await c.read(friendshipsProvider.future);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('pendingRequestCountProvider counts the incoming requests (2 of 4 rows)', () async {
    final c = _container(api: FakeFriendsApi(userId: 'u1', friends: const [_lena, _ninaRequest, _paulRequest, _tomSent]));
    c.listen(pendingRequestCountProvider, (_, _) {});
    await _settle(c);

    expect(c.read(pendingRequestCountProvider), 2);
    expect(c.read(pendingRequestsProvider).asData?.value.map((f) => f.userId), ['u7', 'u8']);
    expect(c.read(sentRequestsProvider).asData?.value.map((f) => f.userId), ['u6']);
    expect(c.read(friendsProvider).asData?.value.map((f) => f.userId), ['u9']);
  });

  test('zero without requests, signed out, and without a backend', () async {
    final none = _container(api: FakeFriendsApi(userId: 'u1', friends: const [_lena, _tomSent]));
    none.listen(pendingRequestCountProvider, (_, _) {});
    await _settle(none);
    expect(none.read(pendingRequestCountProvider), 0);

    final signedOut = _container(api: FakeFriendsApi(friends: const [_ninaRequest]), user: null);
    signedOut.listen(pendingRequestCountProvider, (_, _) {});
    await _settle(signedOut);
    expect(signedOut.read(pendingRequestCountProvider), 0);

    final offline = _container(api: null);
    offline.listen(pendingRequestCountProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(offline.read(friendshipsProvider).hasError, isTrue);
    expect(offline.read(pendingRequestCountProvider), 0);
  });

  test('the count follows the list: accepting a request drops it to 1', () async {
    final api = FakeFriendsApi(userId: 'u1', friends: const [_ninaRequest, _paulRequest]);
    final c = _container(api: api);
    c.listen(pendingRequestCountProvider, (_, _) {});
    await _settle(c);
    expect(c.read(pendingRequestCountProvider), 2);

    await api.acceptFriend('u7');
    c.invalidate(friendshipsProvider);
    await _settle(c);
    expect(c.read(pendingRequestCountProvider), 1);
  });
}
