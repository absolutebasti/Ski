/// Pure computation of the gamification snapshot (docs/GAMIFICATION.md).
///
/// Works on finished [DaySummary] rows only — no clock, no I/O — so it runs
/// offline and signed-out and is trivially testable.
library;

import 'dart:math' as math;

import '../../core/core.dart';
import 'achievement_models.dart';
import 'medal_catalog.dart';

const int _msPerDay = 86400000;

/// Tolerance for thresholds converted from km/h (floating-point noise).
const double _eps = 1e-9;

/// A day whose stats cannot be trusted: excluded from points, top speed and
/// the single-day medals, but it still counts as a ski day (streak, days).
bool isSuspiciousDay(DayStats s) => s.maxSpeedMs > 45 || s.dropM > 15000 || s.runCount > 80;

/// Ordinal of the local calendar day containing [ms] (epoch days of the
/// local date, DST-safe). Two recordings on one date share an ordinal.
int localDayOrdinal(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ _msPerDay;
}

/// Points of one finished day (§1) — the same formula the server stores in
/// `days.points` (migration 0004), so device and leaderboard agree. No streak
/// bonus. Suspicious days score 0.
int dayPoints(DayStats s) {
  if (isSuspiciousDay(s)) return 0;
  return (s.dropM / 10 + s.skiDistanceM / 100 + s.runCount * 5 + 50).round();
}

/// Level band for a lifetime ski distance (§2).
LevelState levelFor(double distanceM) {
  var i = 0;
  while (i + 1 < levelTable.length && distanceM >= levelTable[i + 1].minM) {
    i++;
  }
  final def = levelTable[i];
  final next = i + 1 < levelTable.length ? levelTable[i + 1] : null;
  final progress = next == null ? 1.0 : ((distanceM - def.minM) / (next.minM - def.minM)).clamp(0.0, 1.0);
  return LevelState(
    index: def.index,
    titleDe: def.titleDe,
    titleEn: def.titleEn,
    distanceM: distanceM,
    nextAtM: next?.minM,
    progress: progress,
  );
}

/// Computes the whole snapshot from finished days in any order.
///
/// [countryOf] maps a resort id to its ISO country code (null = unknown).
/// [nowMs]: when given, `streak.current` drops to 0 once the most recent day
/// lies more than one calendar day in the past; without it the current
/// streak is simply the run ending at the most recent day (§3).
Achievements computeAchievements(List<DaySummary> days, {String? Function(String? resortId)? countryOf, String Function(String resortId)? canonicalId, int? nowMs}) {
  final sorted = [...days]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  var points = 0;
  var distanceM = 0.0;
  var dropM = 0.0;
  var runs = 0;
  var skiMs = 0;
  var topSpeedMs = 0.0;
  var bestDayDropM = 0.0;
  var bestDayRuns = 0;
  var dayCount = 0;
  var streak = 0;
  var longest = 0;
  int? prevOrdinal;
  final countries = <String>{};
  final resorts = <String>{};
  final earnedAt = <String, int>{};

  for (final day in sorted) {
    final s = day.stats;
    dayCount++;
    final ordinal = localDayOrdinal(day.startedAt);
    final extendsStreak = ordinal != prevOrdinal;
    if (prevOrdinal == null || ordinal - prevOrdinal > 1) {
      streak = 1;
    } else if (extendsStreak) {
      streak += 1;
    }
    prevOrdinal = ordinal;
    longest = math.max(longest, streak);

    distanceM += s.skiDistanceM;
    dropM += s.dropM;
    runs += s.runCount;
    skiMs += s.skiMs;
    if (!isSuspiciousDay(s)) {
      topSpeedMs = math.max(topSpeedMs, s.maxSpeedMs);
      bestDayDropM = math.max(bestDayDropM, s.dropM);
      bestDayRuns = math.max(bestDayRuns, s.runCount);
      points += dayPoints(s);
    }
    // Alias ids (e.g. lech-zuers → st-anton, 0018) count as one resort.
    final resortId = day.resortId == null ? null : (canonicalId?.call(day.resortId!) ?? day.resortId);
    if (resortId != null) resorts.add(resortId);
    final country = countryOf?.call(resortId);
    if (country != null && country.isNotEmpty) countries.add(country);

    final values = _metricValues(
      dayCount: dayCount,
      streak: streak,
      dropM: dropM,
      distanceM: distanceM,
      topSpeedMs: topSpeedMs,
      avgSpeedMs: _avg(distanceM, skiMs),
      runs: runs,
      bestDayDropM: bestDayDropM,
      bestDayRuns: bestDayRuns,
      countries: countries.length,
      resorts: resorts.length,
      points: points,
    );
    for (final def in medalCatalog) {
      if (earnedAt.containsKey(def.id)) continue;
      if (values[def.metric]! >= def.threshold - _eps) earnedAt[def.id] = day.startedAt;
    }
  }

  final avgSpeedMs = _avg(distanceM, skiMs);
  final finalValues = _metricValues(
    dayCount: dayCount,
    streak: longest,
    dropM: dropM,
    distanceM: distanceM,
    topSpeedMs: topSpeedMs,
    avgSpeedMs: avgSpeedMs,
    runs: runs,
    bestDayDropM: bestDayDropM,
    bestDayRuns: bestDayRuns,
    countries: countries.length,
    resorts: resorts.length,
    points: points,
  );
  final medals = [
    for (final def in medalCatalog)
      MedalState(
        def: def,
        earnedAt: earnedAt[def.id],
        progress: earnedAt.containsKey(def.id) ? 1.0 : (finalValues[def.metric]! / def.threshold).clamp(0.0, 1.0),
      ),
  ];

  final lastDayMs = sorted.isEmpty ? null : sorted.last.startedAt;
  var current = streak;
  if (nowMs != null && prevOrdinal != null && localDayOrdinal(nowMs) - prevOrdinal > 1) current = 0;

  return Achievements(
    points: points,
    level: levelFor(distanceM),
    streak: StreakState(current: current, longest: longest, lastDayMs: lastDayMs),
    medals: medals,
    dayCount: dayCount,
    distanceM: distanceM,
    dropM: dropM,
    topSpeedMs: topSpeedMs,
    avgSpeedMs: avgSpeedMs,
    newMedalIds: [
      for (final def in medalCatalog)
        if (lastDayMs != null && earnedAt[def.id] == lastDayMs) def.id,
    ],
  );
}

double _avg(double distanceM, int skiMs) => skiMs > 0 ? distanceM / (skiMs / 1000) : 0;

Map<AchievementMetric, double> _metricValues({
  required int dayCount,
  required int streak,
  required double dropM,
  required double distanceM,
  required double topSpeedMs,
  required double avgSpeedMs,
  required int runs,
  required double bestDayDropM,
  required int bestDayRuns,
  required int countries,
  required int resorts,
  required int points,
}) =>
    {
      AchievementMetric.days: dayCount.toDouble(),
      AchievementMetric.streak: streak.toDouble(),
      AchievementMetric.vertical: dropM,
      AchievementMetric.distance: distanceM,
      AchievementMetric.topSpeed: topSpeedMs,
      AchievementMetric.avgSpeed: avgSpeedMs,
      AchievementMetric.runs: runs.toDouble(),
      AchievementMetric.dayVertical: bestDayDropM,
      AchievementMetric.dayRuns: bestDayRuns.toDouble(),
      AchievementMetric.countries: countries.toDouble(),
      AchievementMetric.resorts: resorts.toDouble(),
      AchievementMetric.points: points.toDouble(),
    };
