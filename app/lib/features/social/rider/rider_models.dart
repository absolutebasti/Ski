import 'package:flutter/foundation.dart';

import '../../achievements/achievement_models.dart';
import '../../achievements/medal_catalog.dart';
import '../social_models.dart' show parseDisplayName;

/// One row of the `rider_profile` RPC (supabase/migrations/0008_rider_profile.sql):
/// the public face of another rider — identity, this season's numbers and the
/// lifetime totals the client turns into level and medals.
///
/// Every figure is SI (metres, m/s, plain counts); format only in widgets.
@immutable
class RiderProfile {
  const RiderProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.countryCode,
    this.homeResortId,
    required this.seasonKey,
    this.seasonDropM = 0,
    this.seasonSkiDistanceM = 0,
    this.seasonRunCount = 0,
    this.seasonDayCount = 0,
    this.seasonPoints = 0,
    this.lifetimeDropM = 0,
    this.lifetimeSkiDistanceM = 0,
    this.lifetimeRunCount = 0,
    this.lifetimeDayCount = 0,
    this.lifetimeMaxSpeedMs = 0,
    this.lifetimePoints = 0,
    this.lifetimeAvgSkiSpeedMs = 0,
    this.bestDayDropM = 0,
    this.bestDayRunCount = 0,
    this.longestStreak = 0,
    this.resortCount = 0,
    this.countryCount = 0,
    this.lastDayMs,
  });

  final String userId;

  /// As delivered, blank folded to null; render via `riderName`.
  final String? displayName;
  final String? avatarUrl;

  /// Team country (`profiles.country_code`, ISO-3166 alpha-2, upper case).
  final String? countryCode;
  final String? homeResortId;

  /// Season the `season*` figures cover, e.g. '2025/26' (server clock).
  final String seasonKey;
  final double seasonDropM;
  final double seasonSkiDistanceM;
  final int seasonRunCount;
  final int seasonDayCount;
  final double seasonPoints;

  final double lifetimeDropM;

  /// Feeds `levelFor` (docs/GAMIFICATION.md §2).
  final double lifetimeSkiDistanceM;
  final int lifetimeRunCount;
  final int lifetimeDayCount;
  final double lifetimeMaxSpeedMs;

  /// Server day points (no streak bonus) — see migration 0004.
  final double lifetimePoints;
  final double lifetimeAvgSkiSpeedMs;
  final double bestDayDropM;
  final int bestDayRunCount;
  final int longestStreak;
  final int resortCount;
  final int countryCount;

  /// Start of the most recent day, epoch ms; null without days.
  final int? lastDayMs;

  factory RiderProfile.fromJson(Map<String, Object?> j) => RiderProfile(
        userId: (j['user_id'] as String?) ?? '',
        displayName: parseDisplayName(j['display_name']),
        avatarUrl: j['avatar_url'] as String?,
        countryCode: (j['country_code'] as String?)?.toUpperCase(),
        homeResortId: j['home_resort_id'] as String?,
        seasonKey: (j['season_key'] as String?) ?? '',
        seasonDropM: _double(j['season_drop_m']),
        seasonSkiDistanceM: _double(j['season_ski_distance_m']),
        seasonRunCount: _int(j['season_run_count']),
        seasonDayCount: _int(j['season_day_count']),
        seasonPoints: _double(j['season_points']),
        lifetimeDropM: _double(j['lifetime_drop_m']),
        lifetimeSkiDistanceM: _double(j['lifetime_ski_distance_m']),
        lifetimeRunCount: _int(j['lifetime_run_count']),
        lifetimeDayCount: _int(j['lifetime_day_count']),
        lifetimeMaxSpeedMs: _double(j['lifetime_max_speed_ms']),
        lifetimePoints: _double(j['lifetime_points']),
        lifetimeAvgSkiSpeedMs: _double(j['lifetime_avg_ski_speed_ms']),
        bestDayDropM: _double(j['best_day_drop_m']),
        bestDayRunCount: _int(j['best_day_run_count']),
        longestStreak: _int(j['longest_streak']),
        resortCount: _int(j['resort_count']),
        countryCount: _int(j['country_count']),
        lastDayMs: _ms(j['last_day']),
      );

  /// Value of every medal metric on the server totals — the same shape the
  /// device engine judges medals on (docs/GAMIFICATION.md §4).
  Map<AchievementMetric, double> get metricValues => {
        AchievementMetric.days: lifetimeDayCount.toDouble(),
        AchievementMetric.streak: longestStreak.toDouble(),
        AchievementMetric.vertical: lifetimeDropM,
        AchievementMetric.distance: lifetimeSkiDistanceM,
        AchievementMetric.topSpeed: lifetimeMaxSpeedMs,
        AchievementMetric.avgSpeed: lifetimeAvgSkiSpeedMs,
        AchievementMetric.runs: lifetimeRunCount.toDouble(),
        AchievementMetric.dayVertical: bestDayDropM,
        AchievementMetric.dayRuns: bestDayRunCount.toDouble(),
        AchievementMetric.countries: countryCount.toDouble(),
        AchievementMetric.resorts: resortCount.toDouble(),
        AchievementMetric.points: lifetimePoints,
      };

  @override
  bool operator ==(Object other) =>
      other is RiderProfile &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.seasonKey == seasonKey &&
      other.seasonDropM == seasonDropM &&
      other.lifetimeSkiDistanceM == lifetimeSkiDistanceM &&
      other.lastDayMs == lastDayMs;

  @override
  int get hashCode => Object.hash(userId, displayName, seasonKey, seasonDropM, lifetimeSkiDistanceM, lastDayMs);
}

/// Tolerance for thresholds converted from km/h (mirrors the engine).
const double _eps = 1e-9;

/// Medals [rider] has earned, judged with the device catalogue on the RPC
/// totals. Catalogue order.
List<MedalDef> riderMedals(RiderProfile rider) {
  final values = rider.metricValues;
  return [
    for (final def in medalCatalog)
      if ((values[def.metric] ?? 0) >= def.threshold - _eps) def,
  ];
}

/// `riderMedals(rider).length` — what the sheet prints as 'n / 48 Medaillen'.
int riderMedalCount(RiderProfile rider) => riderMedals(rider).length;

int _int(Object? v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);

double _double(Object? v) => v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

int? _ms(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  return DateTime.tryParse('$v')?.millisecondsSinceEpoch;
}
