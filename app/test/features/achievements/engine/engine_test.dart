import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/achievements_engine.dart';
import 'package:slopetrack/features/achievements/medal_catalog.dart';

import 'fixtures.dart';

MedalState medal(Achievements a, String id) => a.medals.firstWhere((m) => m.def.id == id);

void main() {
  group('empty', () {
    test('0 days → everything at zero, all medals locked', () {
      final a = computeAchievements(const []);
      expect(a.points, 0);
      expect(a.dayCount, 0);
      expect(a.level.index, 1);
      expect(a.level.progress, 0);
      expect(a.level.nextAtM, 25000);
      expect(a.streak.current, 0);
      expect(a.streak.longest, 0);
      expect(a.streak.lastDayMs, isNull);
      expect(a.medals.length, medalCatalog.length);
      expect(a.earned, isEmpty);
      expect(a.medals.every((m) => m.progress == 0), isTrue);
      expect(a.newMedalIds, isEmpty);
      expect(a.avgSpeedMs, 0);
    });
  });

  group('one day', () {
    test('first day earns days-bronze and lists it as new', () {
      final a = computeAchievements([day(startedAt: at(12))]);
      expect(a.dayCount, 1);
      expect(a.streak.current, 1);
      expect(a.streak.longest, 1);
      expect(a.streak.lastDayMs, at(12));
      expect(medal(a, 'days-bronze').earnedAt, at(12));
      expect(medal(a, 'days-bronze').progress, 1);
      expect(a.newMedalIds, ['days-bronze']);
      expect(medal(a, 'days-silver').progress, closeTo(0.1, 1e-9));
    });
  });

  group('points', () {
    test('known day: 1.849 hm, 14,1 km, 12 runs → 436', () {
      final a = computeAchievements([day(startedAt: at(1), dropM: 1849, skiKm: 14.1, runs: 12)]);
      expect(a.points, 185 + 141 + 60 + 50);
    });

    test('streak bonus from the third consecutive day', () {
      final days = [for (var d = 1; d <= 4; d++) day(startedAt: at(d), dropM: 1849, skiKm: 14.1, runs: 12)];
      expect(computeAchievements(days.sublist(0, 2)).points, 2 * 436);
      expect(computeAchievements(days.sublist(0, 3)).points, 3 * 436 + 25);
      expect(computeAchievements(days).points, 4 * 436 + 50);
    });

    test('a second recording on the same date gets no streak bonus', () {
      final days = [...streakDays(3), day(startedAt: at(3, hour: 15))];
      expect(computeAchievements(days).points, 4 * 290 + 25);
    });

    test('points medal earnedAt is the day crossing 1.000', () {
      final days = [for (var d = 1; d <= 3; d++) day(startedAt: at(d), dropM: 1849, skiKm: 14.1, runs: 12)];
      final a = computeAchievements(days);
      expect(a.points, 1333);
      expect(medal(a, 'points-bronze').earnedAt, at(3));
      expect(medal(a, 'points-silver').earned, isFalse);
    });
  });

  group('level', () {
    test('24,9 km stays level 1 near the top of the band', () {
      final a = computeAchievements([day(startedAt: at(1), skiKm: 24.9)]);
      expect(a.level.index, 1);
      expect(a.level.titleDe, 'Rookie');
      expect(a.level.nextAtM, 25000);
      expect(a.level.progress, closeTo(0.996, 1e-9));
    });

    test('25 km is level 2 at progress 0', () {
      final a = computeAchievements([day(startedAt: at(1), skiKm: 25)]);
      expect(a.level.index, 2);
      expect(a.level.titleDe, 'Einsteiger');
      expect(a.level.titleEn, 'Starter');
      expect(a.level.progress, 0);
      expect(a.level.nextAtM, 50000);
    });

    test('10.000 km is level 14 Black without a next level', () {
      final a = computeAchievements([day(startedAt: at(1), skiKm: 10000)]);
      expect(a.level.index, 14);
      expect(a.level.titleDe, 'Black');
      expect(a.level.nextAtM, isNull);
      expect(a.level.progress, 1);
    });

    test('progress is the position inside the band', () {
      expect(levelFor(37500).index, 2);
      expect(levelFor(37500).progress, closeTo(0.5, 1e-9));
    });
  });

  group('streak', () {
    // 1–3 (3 days), gap on the 4th, 5–11 (7 days) with a duplicate on the 6th.
    final days = [...streakDays(3, from: 1), ...streakDays(7, from: 5), day(startedAt: at(6, hour: 14))];

    test('gap breaks the streak, duplicate date counts once', () {
      final a = computeAchievements(days);
      expect(a.dayCount, 11);
      expect(a.streak.current, 7);
      expect(a.streak.longest, 7);
      expect(a.streak.lastDayMs, at(11));
    });

    test('streak medals are earned by the day reaching the threshold', () {
      final a = computeAchievements(days);
      expect(medal(a, 'streak-bronze').earnedAt, at(3));
      expect(medal(a, 'streak-silver').earnedAt, at(9));
      expect(medal(a, 'streak-gold').earnedAt, at(11));
      expect(medal(a, 'streak-black').earned, isFalse);
      expect(medal(a, 'streak-black').progress, closeTo(0.5, 1e-9));
    });

    test('input order does not matter', () {
      final a = computeAchievements(days.reversed.toList());
      expect(a.streak.current, 7);
      expect(medal(a, 'streak-gold').earnedAt, at(11));
    });

    test('nowMs: a streak older than yesterday is no longer current', () {
      final three = streakDays(3);
      expect(computeAchievements(three, nowMs: at(4)).streak.current, 3);
      expect(computeAchievements(three, nowMs: at(5)).streak.current, 0);
      expect(computeAchievements(three, nowMs: at(5)).streak.longest, 3);
      expect(computeAchievements(three).streak.current, 3);
    });

    test('calendar days are local, not 24 h windows', () {
      final late = day(startedAt: at(1, hour: 23));
      final early = day(startedAt: at(2, hour: 1));
      expect(computeAchievements([late, early]).streak.current, 2);
      final sameDay = day(startedAt: at(1, hour: 1));
      expect(computeAchievements([sameDay, late]).streak.current, 1);
    });
  });

  group('medals over time', () {
    final ten = streakDays(10);

    test('earnedAt is chronological across tiers', () {
      final a = computeAchievements(ten);
      expect(medal(a, 'days-bronze').earnedAt, at(1));
      expect(medal(a, 'days-silver').earnedAt, at(10));
      expect(medal(a, 'runs-bronze').earnedAt, at(7));
      expect(medal(a, 'points-bronze').earnedAt, at(4));
      for (final metric in medalMetricOrder) {
        final earned = medalsOf(metric).map((d) => medal(a, d.id).earnedAt).whereType<int>().toList();
        expect(earned, orderedEquals(earned..sort()), reason: metric.name);
      }
    });

    test('newMedalIds lists only medals earned by the latest day', () {
      expect(computeAchievements(ten).newMedalIds, ['days-silver', 'vertical-bronze', 'distance-bronze']);
      expect(computeAchievements(ten.sublist(0, 9)).newMedalIds, isEmpty);
      expect(computeAchievements(ten.sublist(0, 7)).newMedalIds, ['streak-gold', 'runs-bronze']);
    });

    test('progress of locked medals reflects lifetime values', () {
      final a = computeAchievements(ten);
      expect(medal(a, 'days-gold').progress, closeTo(0.4, 1e-9));
      expect(medal(a, 'vertical-bronze').earnedAt, at(10));
      expect(medal(a, 'vertical-silver').progress, closeTo(0.2, 1e-9));
      expect(medal(a, 'distance-bronze').progress, closeTo(1, 1e-9));
      expect(medal(a, 'distance-bronze').earnedAt, at(10));
    });
  });

  group('single-day medals and speeds', () {
    test('top speed and day medals from one strong day', () {
      final a = computeAchievements([day(startedAt: at(1), maxKmh: 80, dropM: 3000, runs: 20)]);
      expect(a.topSpeedMs, closeTo(80 / 3.6, 1e-9));
      expect(medal(a, 'topSpeed-silver').earned, isTrue);
      expect(medal(a, 'topSpeed-gold').earned, isFalse);
      expect(medal(a, 'dayVertical-silver').earned, isTrue);
      expect(medal(a, 'dayRuns-silver').earned, isTrue);
      expect(medal(a, 'dayRuns-gold').earned, isFalse);
    });

    test('avg speed = Σ distance / Σ ski time', () {
      final a = computeAchievements([
        day(startedAt: at(1), skiKm: 10, skiMinutes: 60),
        day(startedAt: at(2), skiKm: 20, skiMinutes: 30),
      ]);
      expect(a.avgSpeedMs, closeTo(30000 / 5400, 1e-9));
      expect(medal(a, 'avgSpeed-bronze').progress, closeTo(20 / 25, 1e-9));
    });

    test('avg speed is 0 without ski time', () {
      final a = computeAchievements([day(startedAt: at(1), skiMinutes: 0)]);
      expect(a.avgSpeedMs, 0);
    });
  });

  group('suspicious days', () {
    test('excluded from top speed, day medals and points, still a day', () {
      final a = computeAchievements([day(startedAt: at(1), maxKmh: 200, dropM: 5000, runs: 30)]);
      expect(a.dayCount, 1);
      expect(a.points, 0);
      expect(a.topSpeedMs, 0);
      expect(medal(a, 'days-bronze').earned, isTrue);
      expect(medal(a, 'topSpeed-bronze').earned, isFalse);
      expect(medal(a, 'dayVertical-bronze').earned, isFalse);
      expect(medal(a, 'dayRuns-bronze').earned, isFalse);
      expect(a.newMedalIds, ['days-bronze']);
    });

    test('each rule flags on its own', () {
      expect(isSuspiciousDay(day(startedAt: at(1), maxKmh: 45 * 3.6 + 1).stats), isTrue);
      expect(isSuspiciousDay(day(startedAt: at(1), dropM: 15001).stats), isTrue);
      expect(isSuspiciousDay(day(startedAt: at(1), runs: 81).stats), isTrue);
      expect(isSuspiciousDay(day(startedAt: at(1), maxKmh: 45 * 3.6, dropM: 15000, runs: 80).stats), isFalse);
    });

    test('a suspicious day still extends the streak for the next day', () {
      final days = [day(startedAt: at(1)), day(startedAt: at(2), runs: 90), day(startedAt: at(3))];
      final a = computeAchievements(days);
      expect(a.streak.current, 3);
      expect(medal(a, 'streak-bronze').earnedAt, at(3));
      expect(a.points, 290 + 0 + 290 + 25);
    });
  });

  group('countries and resorts', () {
    final days = [
      day(startedAt: at(1), resortId: 'a'),
      day(startedAt: at(2), resortId: 'b'),
      day(startedAt: at(3), resortId: 'c'),
      day(startedAt: at(4), resortId: 'a'),
      day(startedAt: at(5)),
    ];
    String? country(String? id) => switch (id) { 'a' || 'c' => 'CH', 'b' => 'AT', _ => null };

    test('distinct resorts by id, countries via countryOf', () {
      final a = computeAchievements(days, countryOf: country);
      expect(medal(a, 'resorts-bronze').earnedAt, at(3));
      expect(medal(a, 'resorts-silver').progress, closeTo(0.3, 1e-9));
      expect(medal(a, 'countries-bronze').earnedAt, at(2));
      expect(medal(a, 'countries-silver').progress, closeTo(2 / 3, 1e-9));
    });

    test('without countryOf no country medal', () {
      final a = computeAchievements(days);
      expect(medal(a, 'countries-bronze').earned, isFalse);
      expect(medal(a, 'countries-bronze').progress, 0);
      expect(medal(a, 'resorts-bronze').earned, isTrue);
    });
  });
}
