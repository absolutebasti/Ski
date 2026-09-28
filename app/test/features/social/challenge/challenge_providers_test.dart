import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../social_fixtures.dart';
import 'challenge_fixtures.dart';

ProviderContainer _container({ChallengeApi? api, FakeSocialApi? social, AuthUser? user}) {
  final c = ProviderContainer(
    overrides: [
      challengeApiProvider.overrideWithValue(api),
      socialApiProvider.overrideWithValue(social),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('currentChallenge', () {
    final running = weekly(id: 'run');
    final later = weekly(id: 'later', startsOn: DateTime(2026, 1, 19), endsOn: DateTime(2026, 1, 25));
    final soonest = weekly(id: 'soon', startsOn: DateTime(2026, 1, 12), endsOn: DateTime(2026, 1, 16));

    test('prefers the running challenge with the soonest deadline', () {
      expect(currentChallenge([later, running, soonest], kNow)?.id, 'soon');
    });
    test('falls back to the next upcoming one', () {
      final next = weekly(id: 'next', startsOn: DateTime(2026, 1, 26), endsOn: DateTime(2026, 2, 1));
      expect(currentChallenge([next, later], kNow)?.id, 'later');
    });
    test('null when there is nothing', () {
      expect(currentChallenge(const [], kNow), isNull);
    });
  });

  group('localProgress', () {
    final inside1 = daySummary(id: 'a', startedAt: DateTime(2026, 1, 12, 9).millisecondsSinceEpoch, dropM: 1800, runCount: 7, skiDistanceM: 20000);
    final inside2 = daySummary(id: 'b', startedAt: DateTime(2026, 1, 18, 23).millisecondsSinceEpoch, dropM: 2200, runCount: 9, skiDistanceM: 25000);
    final outside = daySummary(id: 'c', startedAt: DateTime(2026, 1, 19, 0, 1).millisecondsSinceEpoch, dropM: 9000, runCount: 30, skiDistanceM: 90000);

    test('sums vertical over the window days only (inclusive end day)', () {
      expect(localProgress([inside1, inside2, outside], weekly()), 4000);
    });
    test('runs, distance, days', () {
      expect(localProgress([inside1, inside2, outside], weekly(metric: SocialMetric.runCount)), 16);
      expect(localProgress([inside1, inside2, outside], weekly(metric: SocialMetric.skiDistanceM)), 45000);
      expect(localProgress([inside1, inside2, outside], weekly(metric: SocialMetric.dayCount)), 2);
    });
    test('top speed takes the maximum, not the sum', () {
      expect(localProgress([inside1, inside2], weekly(metric: SocialMetric.maxSpeedMs)), 17);
    });
    test('points follow dayPointsOf', () {
      final expected = dayPointsOf(dropM: 1800, skiDistanceM: 20000, runCount: 7) + dayPointsOf(dropM: 2200, skiDistanceM: 25000, runCount: 9);
      expect(localProgress([inside1, inside2], weekly(metric: SocialMetric.points)), expected);
    });
  });

  group('providers', () {
    test('openChallenges comes from the ChallengeApi when there is one', () async {
      final api = FakeChallengeApi(userId: 'u1', challenges: [weekly()]);
      final c = _container(api: api, social: FakeSocialApi(userId: 'u1', challenges: [weeklyChallenge()]), user: kUser);
      final rows = await c.read(openChallengesProvider.future);
      expect(rows.map((e) => e.id), ['c1']);
      expect(rows.single, isA<WeeklyChallenge>());
    });

    test('… and falls back to the SocialApi without one', () async {
      final c = _container(api: null, social: FakeSocialApi(userId: 'u1', challenges: [weeklyChallenge()]), user: kUser);
      final rows = await c.read(openChallengesProvider.future);
      expect(rows.single.title, '10.000 hm in einer Woche');
    });

    test('joined ids, board and history answer empty / offline without a backend', () async {
      final c = _container(api: null, user: kUser);
      expect(await c.read(myChallengeIdsProvider.future), isEmpty);
      expect(await c.read(challengeHistoryProvider.future), isEmpty);
      await expectLater(c.read(challengeBoardProvider('c1').future), throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.offline)));
    });

    test('signed out: no joined ids and no history, no calls made', () async {
      final api = FakeChallengeApi(userId: null, joined: {'c1'}, historyRows: kChallengeHistory);
      final c = _container(api: api, user: null);
      expect(await c.read(myChallengeIdsProvider.future), isEmpty);
      expect(await c.read(challengeHistoryProvider.future), isEmpty);
      expect(api.historyCalls, 0);
    });

    test('signed in: joined ids, board rows and history come from the api', () async {
      final api = FakeChallengeApi(userId: 'u1', joined: {'c1'}, boards: {'c1': kChallengeBoard}, historyRows: kChallengeHistory);
      final c = _container(api: api, user: kUser);
      expect(await c.read(myChallengeIdsProvider.future), {'c1'});
      expect(await c.read(challengeBoardProvider('c1').future), kChallengeBoard);
      expect((await c.read(challengeHistoryProvider.future)).length, 2);
      expect(api.boardCalls, ['c1']);
    });
  });
}
