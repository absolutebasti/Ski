import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/social.dart';

import 'challenge_fixtures.dart';

const _de = ChallengeStrings(AppLocale(Locale('de')));
const _en = ChallengeStrings(AppLocale(Locale('en')));

void main() {
  group('derived title (mirrors private.challenge_title)', () {
    test('drop_m', () {
      expect(_de.title(SocialMetric.dropM, 5000), 'Wochen-Challenge: 5.000 Höhenmeter');
      expect(_en.title(SocialMetric.dropM, 5000), 'Weekly challenge: 5,000 m vertical');
    });
    test('run_count with singular and plural', () {
      expect(_de.title(SocialMetric.runCount, 20), 'Wochen-Challenge: 20 Abfahrten');
      expect(_en.title(SocialMetric.runCount, 20), 'Weekly challenge: 20 runs');
      expect(_de.title(SocialMetric.runCount, 1), 'Wochen-Challenge: 1 Abfahrt');
      expect(_en.title(SocialMetric.runCount, 1), 'Weekly challenge: 1 run');
    });
    test('day_count', () {
      expect(_de.title(SocialMetric.dayCount, 3), 'Wochen-Challenge: 3 Skitage');
      expect(_en.title(SocialMetric.dayCount, 3), 'Weekly challenge: 3 ski days');
      expect(_en.title(SocialMetric.dayCount, 1), 'Weekly challenge: 1 ski day');
    });
    test('ski_distance_m in whole km', () {
      expect(_de.title(SocialMetric.skiDistanceM, 50000), 'Wochen-Challenge: 50 Ski-km');
      expect(_en.title(SocialMetric.skiDistanceM, 50000), 'Weekly challenge: 50 km');
    });
    test('max_speed_ms in km/h', () {
      expect(_de.title(SocialMetric.maxSpeedMs, 25), 'Wochen-Challenge: 90 km/h Top-Speed');
      expect(_en.title(SocialMetric.maxSpeedMs, 25), 'Weekly challenge: 90 km/h top speed');
    });
    test('points', () {
      expect(_de.title(SocialMetric.points, 1500), 'Wochen-Challenge: 1.500 Punkte');
      expect(_en.title(SocialMetric.points, 1500), 'Weekly challenge: 1,500 points');
    });
  });

  group('titleOf', () {
    test('picks the server column of the locale when both are present', () {
      final c = weekly();
      expect(_de.titleOf(c), 'Wochen-Challenge: 5.000 Höhenmeter');
      expect(_en.titleOf(c), 'Weekly challenge: 5,000 m vertical');
    });

    test('a legacy row (German title only) keeps it on de and derives on en', () {
      final legacy = Challenge(id: 'c1', title: '5.000 hm diese Woche', metric: SocialMetric.dropM, target: 5000, startsOn: DateTime(2026, 1, 12), endsOn: DateTime(2026, 1, 18));
      expect(_de.titleOf(legacy), '5.000 hm diese Woche');
      expect(_en.titleOf(legacy), 'Weekly challenge: 5,000 m vertical');
    });

    test('missing columns derive from metric + target in both languages', () {
      final c = weekly(titleDe: null, titleEn: null, metric: SocialMetric.runCount, target: 20);
      expect(_de.titleOf(c), 'Wochen-Challenge: 20 Abfahrten');
      expect(_en.titleOf(c), 'Weekly challenge: 20 runs');
    });

    test('only the German column present: en derives instead of showing German', () {
      final c = weekly(titleEn: null);
      expect(_en.titleOf(c), 'Weekly challenge: 5,000 m vertical');
    });
  });

  group('counts', () {
    test('n dabei · m geschafft', () {
      expect(_de.counts(12, 3), '12 dabei · 3 geschafft');
      expect(_en.counts(12, 3), '12 in · 3 done');
    });
    test('nobody yet', () {
      expect(_de.counts(0, 0), 'Noch niemand dabei');
      expect(_en.counts(0, 0), 'Nobody in yet');
    });
  });

  test('rank and window lines', () {
    expect(_de.rankOf(3, 12), 'Platz 3 von 12');
    expect(_en.rankOf(3, 12), 'Rank 3 of 12');
  });
}
