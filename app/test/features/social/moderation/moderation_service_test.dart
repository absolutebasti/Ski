import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/friends/friends.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';
import 'package:slopetrack/features/social/social.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian Fackelmann');
const _query = LeaderboardQuery(seasonKey: '2025/26', resortId: 'kitzbuehel');
const kLenaFriend = Friend(userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT');

({ProviderContainer container, FakeModerationApi mod, FakeSocialApi social, FakeFriendsApi friends}) _setUp({String? uid = 'u1', List<ProviderOrFamily>? targets}) {
  final mod = FakeModerationApi(userId: uid);
  final social = FakeSocialApi(userId: uid);
  final friends = FakeFriendsApi(userId: uid, friends: const [kLenaFriend]);
  final container = ProviderContainer(overrides: [
    moderationApiProvider.overrideWithValue(mod),
    socialApiProvider.overrideWithValue(social),
    friendsApiProvider.overrideWithValue(friends),
    authStateProvider.overrideWith((ref) => Stream.value(uid == null ? null : _user)),
    if (targets != null) blockRefreshTargetsProvider.overrideWithValue(targets),
  ]);
  addTearDown(container.dispose);
  return (container: container, mod: mod, social: social, friends: friends);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('report hands (targetUserId, reason) to the api', () async {
    final t = _setUp();
    await t.container.read(moderationServiceProvider).report(targetUserId: 'u9', reason: ReportReason.cheating.encode('zu schnell'));
    expect(t.mod.reports, [('u9', 'cheating: zu schnell')]);
  });

  test('block inserts the block, removes the friendship and refreshes every board', () async {
    final t = _setUp();
    final c = t.container;
    // Keep the boards alive so an invalidation refetches them.
    final subs = [
      c.listen(leaderboardProvider(_query), (_, _) {}),
      c.listen(groupBoardProvider('g1'), (_, _) {}),
      c.listen(friendshipsProvider, (_, _) {}),
      c.listen(friendsBoardProvider(_query), (_, _) {}),
      c.listen(blockedIdsProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await c.read(leaderboardProvider(_query).future);
    await c.read(groupBoardProvider('g1').future);
    await c.read(friendshipsProvider.future);
    await c.read(friendsBoardProvider(_query).future);
    expect(await c.read(blockedIdsProvider.future), isEmpty);
    // The Rangliste may issue more than one leaderboard call per board read
    // (slice + own-rank fallback); assert growth, not absolute counts.
    final q0 = t.social.queries.length, b0 = t.social.boardCalls.length, l0 = t.friends.listCalls, f0 = t.friends.boardQueries.length;
    expect(q0, greaterThanOrEqualTo(1));
    expect(b0, greaterThanOrEqualTo(1));
    expect(l0, greaterThanOrEqualTo(1));
    expect(f0, greaterThanOrEqualTo(1));

    await c.read(moderationServiceProvider).block('u9');
    await _settle();

    expect(t.mod.blockCalls, ['u9']);
    expect(t.friends.removed, ['u9']);
    expect(await c.read(blockedIdsProvider.future), {'u9'});
    expect(t.mod.blockedIdsCalls, greaterThan(1), reason: 'blockedIdsProvider refetched');
    expect(t.social.queries.length, greaterThan(q0), reason: 'leaderboard refetched');
    expect(t.social.boardCalls.length, greaterThan(b0), reason: 'duel board refetched');
    expect(t.friends.listCalls, greaterThan(l0), reason: 'friends list refetched');
    expect(t.friends.boardQueries.length, greaterThan(f0), reason: 'friends board refetched');
    final q1 = t.social.queries.length, l1 = t.friends.listCalls;

    await c.read(moderationServiceProvider).unblock('u9');
    await _settle();
    expect(t.mod.unblockCalls, ['u9']);
    expect(await c.read(blockedIdsProvider.future), isEmpty);
    expect(t.social.queries.length, greaterThan(q1));
    expect(t.friends.listCalls, greaterThan(l1));
  });

  test('a failing friend removal does not undo the block', () async {
    final t = _setUp();
    t.friends.failWith = const FriendsError(FriendsErrorKind.failed);
    await t.container.read(moderationServiceProvider).block('u9');
    expect(t.mod.blocked, {'u9'});
  });

  test('extra refresh targets from a later package are invalidated too', () async {
    var builds = 0;
    final extra = Provider<int>((ref) => ++builds);
    final t = _setUp(targets: [...kBlockRefreshTargets, extra]);
    final sub = t.container.listen(extra, (_, _) {});
    addTearDown(sub.close);
    expect(t.container.read(extra), 1);
    await t.container.read(moderationServiceProvider).block('u9');
    await _settle();
    expect(t.container.read(extra), 2);
  });

  test('signed out: block/report throw notSignedIn, blockedIds is empty', () async {
    final t = _setUp(uid: null);
    expect(await t.container.read(blockedIdsProvider.future), isEmpty);
    expect(
      () => t.container.read(moderationServiceProvider).block('u9'),
      throwsA(isA<ModerationError>().having((e) => e.kind, 'kind', ModerationErrorKind.notSignedIn)),
    );
    expect(t.mod.blocked, isEmpty);
  });

  test('no backend: offline error, blockedIds empty', () async {
    final container = ProviderContainer(overrides: [
      moderationApiProvider.overrideWithValue(null),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(blockedIdsProvider.future), isEmpty);
    expect(
      () => container.read(moderationServiceProvider).report(targetUserId: 'u9', reason: 'other'),
      throwsA(isA<ModerationError>().having((e) => e.kind, 'kind', ModerationErrorKind.offline)),
    );
  });

  test('a failing blockedIds call yields an empty set, never an error', () async {
    final t = _setUp();
    t.mod.failWith = const ModerationError(ModerationErrorKind.failed);
    expect(await t.container.read(blockedIdsProvider.future), isEmpty);
  });
}
