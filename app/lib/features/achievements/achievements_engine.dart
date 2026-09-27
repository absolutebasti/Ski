import '../../core/core.dart';
import 'achievement_models.dart';

/// Pure computation of the gamification snapshot (docs/GAMIFICATION.md).
/// Owned by the achievements-engine package; this stub keeps the app
/// compiling until the engine lands.
///
/// [countryOf] maps a resort id to its ISO country code (null = unknown).
Achievements computeAchievements(List<DaySummary> days, {String? Function(String? resortId)? countryOf, int? nowMs}) {
  return Achievements(
    points: 0,
    level: const LevelState(index: 1, titleDe: 'Rookie', titleEn: 'Rookie', distanceM: 0, nextAtM: 25000, progress: 0),
    streak: const StreakState(current: 0, longest: 0, lastDayMs: null),
    medals: const [],
    dayCount: days.length,
    distanceM: 0,
    dropM: 0,
    topSpeedMs: 0,
    avgSpeedMs: 0,
    newMedalIds: const [],
  );
}
