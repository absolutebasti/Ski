import 'package:slopetrack/features/social/social.dart';
import 'package:flutter_test/flutter_test.dart';

import 'social_fixtures.dart';

void main() {
  group('period keys', () {
    test('season, month and ISO week', () {
      expect(LeaderboardPeriod.season.keyFor(kNow), '2025/26');
      expect(LeaderboardPeriod.month.keyFor(kNow), '2026-01');
      expect(LeaderboardPeriod.week.keyFor(kNow), '2026-W03');
    });

    test('ISO week rolls over on Monday, not on Sunday', () {
      expect(isoWeekKey(DateTime(2026, 1, 4)), '2026-W01'); // Sunday
      expect(isoWeekKey(DateTime(2026, 1, 5)), '2026-W02'); // Monday
      expect(isoWeekKey(DateTime(2025, 12, 31)), '2026-W01'); // ISO year jumps
    });

    test('the query sends the period key, not always the season', () {
      final season = LeaderboardQuery.at(kNow);
      final week = LeaderboardQuery.at(kNow, period: LeaderboardPeriod.week);
      expect(season.wireKey, '2025/26');
      expect(week.wireKey, '2026-W03');
      expect(week.seasonKey, '2025/26');
      expect(season == LeaderboardQuery.at(kNow), isTrue, reason: 'value equality keeps the family cached');
      expect(season == week, isFalse);
    });
  });

  test('myRankOf finds the signed-in user and nothing else', () {
    expect(myRankOf(kEntries, 'u1'), const MyRank(rank: 4, total: 5, value: 12480));
    expect(myRankOf(kEntries, 'nobody'), isNull);
    expect(myRankOf(kEntries, null), isNull);
  });

  test('initials', () {
    expect(initialsOf('Sebastian Fackelmann'), 'SF');
    expect(initialsOf('Leo'), 'L');
    expect(initialsOf('  '), '?');
    expect(initialsOf('Åsa Öberg'), 'ÅÖ');
  });

  group('duel codes', () {
    test('the alphabet leaves out every ambiguous glyph', () {
      for (final ch in ['0', 'O', '1', 'I', 'L']) {
        expect(SupabaseSocialApi.codeAlphabet.contains(ch), isFalse, reason: ch);
      }
    });

    test('generated codes are six valid characters', () {
      for (var i = 0; i < 50; i++) {
        final code = SupabaseSocialApi.newCode();
        expect(code.length, 6);
        expect(SupabaseSocialApi.isValidCode(code), isTrue);
      }
    });

    test('normalise uppercases and strips, and never rewrites a valid code', () {
      expect(SupabaseSocialApi.normaliseCode(' kmj-4f2 '), 'KMJ4F2');
      expect(SupabaseSocialApi.isValidCode('KMJ4F2'), isTrue);
      expect(SupabaseSocialApi.isValidCode('KMJ4F'), isFalse);
      expect(SupabaseSocialApi.isValidCode('KMJ4F0'), isFalse);
    });
  });

  group('challenge window', () {
    test('local progress only counts days inside the window', () {
      final c = weeklyChallenge();
      final days = [
        daySummary(id: 'in-1', startedAt: DateTime(2026, 1, 12, 10).millisecondsSinceEpoch, dropM: 1800),
        daySummary(id: 'in-2', startedAt: DateTime(2026, 1, 18, 23).millisecondsSinceEpoch, dropM: 2200),
        daySummary(id: 'before', startedAt: DateTime(2026, 1, 11, 23).millisecondsSinceEpoch, dropM: 5000),
        daySummary(id: 'after', startedAt: DateTime(2026, 1, 19, 8).millisecondsSinceEpoch, dropM: 5000),
      ];
      expect(localProgress(days, c), 4000);
      expect(localProgress(days, weeklyChallenge(metric: SocialMetric.dayCount)), 2);
      expect(localProgress(days, weeklyChallenge(metric: SocialMetric.runCount)), 14);
    });

    test('daysLeft counts whole days including today', () {
      expect(weeklyChallenge().daysLeft(kNow), 3);
      expect(weeklyChallenge().daysLeft(DateTime(2026, 1, 18, 20)), 0);
    });

    test('currentChallenge prefers the running one', () {
      final running = weeklyChallenge();
      final later = Challenge(
        id: 'c2',
        title: 'Später',
        metric: SocialMetric.dropM,
        target: 5000,
        startsOn: DateTime(2026, 2, 1),
        endsOn: DateTime(2026, 2, 7),
      );
      expect(currentChallenge([later, running], kNow), running);
      expect(currentChallenge([later], kNow), later);
      expect(currentChallenge(const [], kNow), isNull);
    });
  });

  group('country teams (migration 0004)', () {
    test('points is a leaderboard metric on the wire, not a challenge one', () {
      expect(SocialMetric.points.wire, 'points');
      expect(SocialMetric.leaderboard, contains(SocialMetric.points));
      expect(SocialMetric.challenge, isNot(contains(SocialMetric.points)));
      expect(SocialMetric.fromWire('points'), SocialMetric.points);
    });

    test('dayPointsOf matches the server formula without the streak bonus', () {
      expect(dayPointsOf(dropM: 1849, skiDistanceM: 14100, runCount: 12), 436);
      expect(dayPointsOf(dropM: 0, skiDistanceM: 0, runCount: 0), 50);
    });

    test('LeaderboardQuery carries the country and derives its scope', () {
      final country = LeaderboardQuery.at(kNow, countryCode: 'AT');
      final resort = LeaderboardQuery.at(kNow, resortId: 'kitzbuehel');
      final all = LeaderboardQuery.at(kNow);
      expect(country.scope, LeaderboardScope.country);
      expect(resort.scope, LeaderboardScope.resort);
      expect(all.scope, LeaderboardScope.all);
      expect(country, isNot(all), reason: 'the family must not share a cache entry');
      expect(country.copyWith(clearCountry: true), all);
      expect(resort.copyWith(countryCode: 'AT').scope, LeaderboardScope.country);
    });

    test('CountryEntry.fromJson and the points order', () {
      final at = CountryEntry.fromJson({'country_code': 'at', 'riders': 250, 'points': 91234.0, 'drop_m': 812000.0});
      final ch = CountryEntry.fromJson({'country_code': 'CH', 'riders': 90, 'points': 120000, 'drop_m': 500000});
      expect(at.countryCode, 'AT');
      expect(at.riders, 250);
      expect(at.points, 91234);
      expect(([at, ch]..sort(compareCountries)).first, ch);
    });

    test('flagEmoji builds regional indicators and rejects junk', () {
      expect(flagEmoji('AT'), '\u{1F1E6}\u{1F1F9}');
      expect(flagEmoji('ch'), '\u{1F1E8}\u{1F1ED}');
      expect(flagEmoji(''), '');
      expect(flagEmoji(null), '');
      expect(flagEmoji('A1'), '');
      expect(flagEmoji('AUT'), '');
    });
  });
}
