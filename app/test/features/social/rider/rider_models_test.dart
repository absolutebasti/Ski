import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/social/rider/rider.dart';

import 'rider_fixtures.dart';

void main() {
  test('fromJson parses every RPC column, tolerant to num/string types', () {
    final p = RiderProfile.fromJson(kLenaJson);
    expect(p.userId, 'u9');
    expect(p.displayName, 'Lena Bergmann');
    expect(p.countryCode, 'AT', reason: 'upper-cased');
    expect(p.homeResortId, 'kitzbuehel');
    expect(p.seasonKey, '2025/26');
    expect(p.seasonDropM, 12480);
    expect(p.seasonSkiDistanceM, 98400);
    expect(p.seasonRunCount, 87);
    expect(p.seasonDayCount, 9);
    expect(p.seasonPoints, 2300);
    expect(p.lifetimeDropM, 60000);
    expect(p.lifetimeSkiDistanceM, 120000);
    expect(p.lifetimeRunCount, 120);
    expect(p.lifetimeDayCount, 12);
    expect(p.lifetimeMaxSpeedMs, 22);
    expect(p.lifetimePoints, 1500);
    expect(p.lifetimeAvgSkiSpeedMs, 8);
    expect(p.bestDayDropM, 2400);
    expect(p.bestDayRunCount, 12);
    expect(p.longestStreak, 3);
    expect(p.resortCount, 3);
    expect(p.countryCount, 1);
    expect(p.lastDayMs, DateTime.utc(2026, 1, 13, 9).millisecondsSinceEpoch);
    expect(p, kLena);
  });

  test('missing columns fall back to zero / null', () {
    final p = RiderProfile.fromJson(const {'user_id': 'x'});
    expect(p.displayName, 'Skifahrer');
    expect(p.countryCode, isNull);
    expect(p.lastDayMs, isNull);
    expect(p.seasonDropM, 0);
    expect(riderMedalCount(p), 0);
  });

  test('medal count follows the catalogue thresholds on the totals', () {
    expect(riderMedalCount(kLena), kLenaMedals);
    final ids = riderMedals(kLena).map((m) => m.id).toList();
    expect(ids, containsAll(['days-bronze', 'days-silver', 'streak-bronze', 'vertical-silver', 'distance-bronze', 'topSpeed-bronze', 'avgSpeed-bronze', 'runs-bronze', 'dayVertical-bronze', 'dayRuns-bronze', 'resorts-bronze', 'points-bronze']));
    expect(ids, isNot(contains('countries-bronze')));
    expect(ids, isNot(contains('days-gold')));
  });

  test('a km/h threshold is met at exactly the converted value', () {
    const p = RiderProfile(userId: 'u', displayName: 'U', seasonKey: '2025/26', lifetimeMaxSpeedMs: 100 / 3.6);
    expect(riderMedals(p).where((m) => m.metric == AchievementMetric.topSpeed).map((m) => m.tier), [MedalTier.bronze, MedalTier.silver, MedalTier.gold]);
  });
}
