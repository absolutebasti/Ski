/// Gamification contract (lead-owned; see docs/GAMIFICATION.md).
///
/// Everything is computed locally from the user's finished days — no server
/// state. Points and level feed the leaderboards through `days` sync later.
library;

/// Metric a medal or level is judged on.
enum AchievementMetric { days, streak, vertical, distance, topSpeed, avgSpeed, runs, dayVertical, dayRuns, countries, resorts, points }

/// Tier of a medal: bronze → silver → gold → black (the SlopeTrack top tier).
enum MedalTier { bronze, silver, gold, black }

/// A medal definition. `threshold` is in the metric's SI unit (metres, m/s,
/// counts). Ids are stable strings used for persistence and tests.
class MedalDef {
  const MedalDef({
    required this.id,
    required this.metric,
    required this.tier,
    required this.threshold,
    required this.titleDe,
    required this.titleEn,
    required this.hintDe,
    required this.hintEn,
  });
  final String id;
  final AchievementMetric metric;
  final MedalTier tier;
  final double threshold;
  final String titleDe;
  final String titleEn;
  final String hintDe;
  final String hintEn;
}

/// A medal the user has (or has not yet) earned.
class MedalState {
  const MedalState({required this.def, required this.earnedAt, required this.progress});
  final MedalDef def;
  /// Epoch ms of the day that earned it; null = locked.
  final int? earnedAt;
  /// 0…1 towards the threshold (1 when earned).
  final double progress;
  bool get earned => earnedAt != null;
}

/// Level by total ski distance (docs/GAMIFICATION.md §2). `index` starts at 1.
class LevelState {
  const LevelState({
    required this.index,
    required this.titleDe,
    required this.titleEn,
    required this.distanceM,
    required this.nextAtM,
    required this.progress,
  });
  final int index;
  final String titleDe;
  final String titleEn;
  /// Lifetime ski distance in metres.
  final double distanceM;
  /// Distance needed for the next level; null at the top level.
  final double? nextAtM;
  /// 0…1 inside the current level band.
  final double progress;
}

/// Consecutive ski days (calendar days in the device time zone).
class StreakState {
  const StreakState({required this.current, required this.longest, required this.lastDayMs});
  final int current;
  final int longest;
  /// Epoch ms of the last counted day; null without days.
  final int? lastDayMs;
}

/// The whole gamification snapshot for the signed-in or local user.
class Achievements {
  const Achievements({
    required this.points,
    required this.level,
    required this.streak,
    required this.medals,
    required this.dayCount,
    required this.distanceM,
    required this.dropM,
    required this.topSpeedMs,
    required this.avgSpeedMs,
    required this.newMedalIds,
  });
  /// Season-independent lifetime points (docs/GAMIFICATION.md §1).
  final int points;
  final LevelState level;
  final StreakState streak;
  /// Every defined medal with its state, in catalogue order.
  final List<MedalState> medals;
  final int dayCount;
  final double distanceM;
  final double dropM;
  final double topSpeedMs;
  /// Lifetime average skiing speed = Σ ski distance / Σ ski time.
  final double avgSpeedMs;
  /// Medals earned by the most recent day (for the Tagesbilanz banner).
  final List<String> newMedalIds;

  List<MedalState> get earned => medals.where((m) => m.earned).toList();
}
