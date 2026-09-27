import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/achievements_providers.dart';

/// Fixture catalogue mirroring docs/GAMIFICATION.md §4 (12 metrics × 4 tiers,
/// SI thresholds). Independent of the engine, which is written concurrently.
const _thresholds = <AchievementMetric, List<double>>{
  AchievementMetric.days: [1, 10, 25, 100],
  AchievementMetric.streak: [3, 5, 7, 14],
  AchievementMetric.vertical: [10000, 50000, 100000, 500000],
  AchievementMetric.distance: [100000, 500000, 1000000, 5000000],
  AchievementMetric.topSpeed: [60 / 3.6, 80 / 3.6, 100 / 3.6, 120 / 3.6],
  AchievementMetric.avgSpeed: [25 / 3.6, 35 / 3.6, 45 / 3.6, 55 / 3.6],
  AchievementMetric.runs: [50, 250, 1000, 5000],
  AchievementMetric.dayVertical: [2000, 3000, 4000, 6000],
  AchievementMetric.dayRuns: [10, 20, 30, 40],
  AchievementMetric.countries: [2, 3, 4, 5],
  AchievementMetric.resorts: [3, 10, 25, 50],
  AchievementMetric.points: [1000, 5000, 20000, 100000],
};

List<MedalDef> fixtureCatalogue() => [
      for (final e in _thresholds.entries)
        for (final (i, tier) in MedalTier.values.indexed)
          MedalDef(
            id: '${e.key.name}-${tier.name}',
            metric: e.key,
            tier: tier,
            threshold: e.value[i],
            titleDe: e.key == AchievementMetric.streak && tier == MedalTier.gold ? 'Sieben am Stück' : '${e.key.name} ${tier.name} de',
            titleEn: e.key == AchievementMetric.streak && tier == MedalTier.gold ? 'Seven in a row' : '${e.key.name} ${tier.name} en',
            hintDe: 'Hinweis',
            hintEn: 'Hint',
          ),
    ];

/// Snapshot: level 4 (Carver) at 312 km with 200 km as the next band, 1.234
/// points, 3-day streak, 7 of 48 medals earned (the first seven in catalogue
/// order), locked ones carrying a visible progress.
Achievements fixtureAchievements({List<String> newMedalIds = const [], int streak = 3, int earnedCount = 7}) {
  final catalogue = fixtureCatalogue();
  return Achievements(
    points: 1234,
    level: const LevelState(index: 4, titleDe: 'Carver', titleEn: 'Carver', distanceM: 162000, nextAtM: 200000, progress: 0.62),
    streak: StreakState(current: streak, longest: 5, lastDayMs: 1766790000000),
    medals: [
      for (final (i, def) in catalogue.indexed)
        MedalState(def: def, earnedAt: i < earnedCount ? 1766790000000 - i * 86400000 : null, progress: i < earnedCount ? 1 : 0.4),
    ],
    dayCount: 12,
    distanceM: 312000,
    dropM: 48000,
    topSpeedMs: 22,
    avgSpeedMs: 9,
    newMedalIds: newMedalIds,
  );
}

List<Override> achievementsOverrides(Achievements a) => [achievementsProvider.overrideWithValue(a)];
