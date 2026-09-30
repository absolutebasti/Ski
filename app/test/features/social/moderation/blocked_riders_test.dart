import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian');

ProviderContainer _container(ModerationApi? api, {AuthUser? user = _user}) {
  final c = ProviderContainer(overrides: [
    moderationApiProvider.overrideWithValue(api),
    authStateProvider.overrideWith((ref) => Stream.value(user)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('BlockedRider.fromRow', () {
    test('maps the RPC row', () {
      final r = BlockedRider.fromRow({
        'user_id': 'u2',
        'display_name': ' Lena ',
        'avatar_url': 'https://example.invalid/l.png',
        'created_at': '2026-09-30T08:00:00+00:00',
      });
      expect(r, BlockedRider(userId: 'u2', displayName: 'Lena', avatarUrl: 'https://example.invalid/l.png', blockedAt: DateTime.utc(2026, 9, 30, 8)));
    });

    test('a rider without a profile row has no name or avatar', () {
      final r = BlockedRider.fromRow({'user_id': 'u3', 'display_name': null, 'avatar_url': null, 'created_at': null});
      expect(r, const BlockedRider(userId: 'u3'));
    });

    test('blank name → null, missing id → no row', () {
      expect(BlockedRider.fromRow({'user_id': 'u4', 'display_name': '  '})?.displayName, isNull);
      expect(BlockedRider.fromRow({'display_name': 'x'}), isNull);
    });
  });

  group('blockedRidersProvider', () {
    test('newest block first, fake riders map fills the names', () async {
      final api = FakeModerationApi(userId: 'u1', blocked: const {'u2', 'u3'}, riders: const {'u2': BlockedRider(userId: 'u2', displayName: 'Lena')});
      final c = _container(api);
      final list = await c.read(blockedRidersProvider.future);
      expect(list, const [BlockedRider(userId: 'u3'), BlockedRider(userId: 'u2', displayName: 'Lena')]);
    });

    test('empty without a backend, signed out or on error', () async {
      expect(await _container(null).read(blockedRidersProvider.future), isEmpty);
      expect(await _container(FakeModerationApi(blocked: const {'u2'}), user: null).read(blockedRidersProvider.future), isEmpty);
      final failing = FakeModerationApi(userId: 'u1', blocked: const {'u2'}, failWith: const ModerationError(ModerationErrorKind.offline));
      expect(await _container(failing).read(blockedRidersProvider.future), isEmpty);
    });

    test('unblock through the service refetches it', () async {
      final api = FakeModerationApi(userId: 'u1', blocked: const {'u2', 'u3'});
      final c = _container(api);
      final sub = c.listen(blockedRidersProvider, (_, _) {});
      addTearDown(sub.close);
      expect((await c.read(blockedRidersProvider.future)).map((r) => r.userId), ['u3', 'u2']);
      final before = api.blockedRidersCalls;
      await c.read(moderationServiceProvider).unblock('u3');
      expect((await c.read(blockedRidersProvider.future)).map((r) => r.userId), ['u2']);
      expect(api.blockedRidersCalls, greaterThan(before));
    });
  });
}
