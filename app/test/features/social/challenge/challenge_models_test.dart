import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/social.dart';

import 'challenge_fixtures.dart';

void main() {
  group('WeeklyChallenge', () {
    test('fromJson keeps both title columns and stays a Challenge', () {
      final c = WeeklyChallenge.fromJson({
        'id': 'c1',
        'title': 'Wochen-Challenge: 5.000 Höhenmeter',
        'title_de': 'Wochen-Challenge: 5.000 Höhenmeter',
        'title_en': 'Weekly challenge: 5,000 m vertical',
        'metric': 'drop_m',
        'target': 5000,
        'starts_on': '2026-01-12',
        'ends_on': '2026-01-18',
      });
      expect(c, isA<Challenge>());
      expect(c.titleDe, 'Wochen-Challenge: 5.000 Höhenmeter');
      expect(c.titleEn, 'Weekly challenge: 5,000 m vertical');
      expect(c.metric, SocialMetric.dropM);
      expect(c.target, 5000);
      expect(c.startsOn, DateTime(2026, 1, 12));
      expect(c.endsOn, DateTime(2026, 1, 18));
    });

    test('missing or blank title columns become null', () {
      final c = WeeklyChallenge.fromJson({'id': 'c1', 'title': 'x', 'metric': 'drop_m', 'target': 1, 'starts_on': '2026-01-12', 'ends_on': '2026-01-18', 'title_en': '  '});
      expect(c.titleDe, isNull);
      expect(c.titleEn, isNull);
    });

    test('isEnded is true from the day after ends_on', () {
      final c = weekly();
      expect(c.isEnded(DateTime(2026, 1, 18, 23, 59)), isFalse);
      expect(c.isEnded(DateTime(2026, 1, 19, 0, 1)), isTrue);
    });
  });

  group('ChallengeBoardEntry', () {
    test('fromJson takes bigint ranks, numeric strings and upper-cases the flag', () {
      final e = ChallengeBoardEntry.fromJson({
        'rank': 2,
        'user_id': 'u1',
        'display_name': 'Sebastian',
        'avatar_url': null,
        'country_code': 'at',
        'value': '4000',
        'done': false,
        'participants': 3,
        'done_count': '1',
      });
      expect(e.rank, 2);
      expect(e.userId, 'u1');
      expect(e.countryCode, 'AT');
      expect(e.value, 4000);
      expect(e.done, isFalse);
      expect(e.participants, 3);
      expect(e.doneCount, 1);
    });

    test('a nameless row keeps a null name and zero counts', () {
      final e = ChallengeBoardEntry.fromJson({'rank': 1, 'user_id': 'u2', 'value': 12.5});
      expect(e.displayName, isNull, reason: 'the UI localises the fallback (riderName)');
      expect(e.participants, 0);
      expect(e.doneCount, 0);
      expect(e.done, isFalse);
    });

    test('boardCounts reads the window counts off the first row', () {
      expect(boardCounts(kChallengeBoard), (3, 1));
      expect(boardCounts(const []), (0, 0));
    });

    test('value equality', () {
      expect(kChallengeBoard.first, const ChallengeBoardEntry(rank: 1, userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT', value: 6200, done: true, participants: 3, doneCount: 1));
      expect(kChallengeBoard.first, isNot(kChallengeBoard[1]));
    });
  });

  group('ChallengeHistoryEntry', () {
    test('fromJson builds the challenge from the flattened RPC row', () {
      final h = ChallengeHistoryEntry.fromJson({
        'challenge_id': 'c0',
        'title': 'Wochen-Challenge: 20 Abfahrten',
        'title_de': 'Wochen-Challenge: 20 Abfahrten',
        'title_en': 'Weekly challenge: 20 runs',
        'metric': 'run_count',
        'target': 20,
        'starts_on': '2026-01-05',
        'ends_on': '2026-01-11',
        'value': 14,
        'done': false,
        'rank': 1,
        'participants': 1,
        'done_count': 0,
      });
      expect(h.challenge.id, 'c0');
      expect(h.challenge.titleEn, 'Weekly challenge: 20 runs');
      expect(h.challenge.metric, SocialMetric.runCount);
      expect(h.value, 14);
      expect(h.done, isFalse);
      expect(h.rank, 1);
      expect(h.participants, 1);
      expect(h.doneCount, 0);
    });
  });
}
