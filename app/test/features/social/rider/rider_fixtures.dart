import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:slopetrack/features/social/rider/rider.dart';

/// Lena: level 4 (120 km lifetime), 13 medals on the catalogue thresholds
/// (days 2, streak 1, vertical 2, distance 1, top speed 1, avg speed 1,
/// runs 1, day vertical 1, day runs 1, countries 0, resorts 1, points 1).
const kLena = RiderProfile(
  userId: 'u9',
  displayName: 'Lena Bergmann',
  countryCode: 'AT',
  homeResortId: 'kitzbuehel',
  seasonKey: '2025/26',
  seasonDropM: 12480,
  seasonSkiDistanceM: 98400,
  seasonRunCount: 87,
  seasonDayCount: 9,
  seasonPoints: 2300,
  lifetimeDropM: 60000,
  lifetimeSkiDistanceM: 120000,
  lifetimeRunCount: 120,
  lifetimeDayCount: 12,
  lifetimeMaxSpeedMs: 22,
  lifetimePoints: 1500,
  lifetimeAvgSkiSpeedMs: 8,
  bestDayDropM: 2400,
  bestDayRunCount: 12,
  longestStreak: 3,
  resortCount: 3,
  countryCount: 1,
  lastDayMs: 1768294800000, // 2026-01-13 09:00 UTC
);

const int kLenaMedals = 13;

/// The row as PostgREST delivers it (bigint as int, double as num or string).
const Map<String, Object?> kLenaJson = {
  'user_id': 'u9',
  'display_name': 'Lena Bergmann',
  'avatar_url': null,
  'country_code': 'at',
  'home_resort_id': 'kitzbuehel',
  'season_key': '2025/26',
  'season_drop_m': 12480.0,
  'season_ski_distance_m': '98400',
  'season_run_count': 87,
  'season_day_count': 9,
  'season_points': 2300,
  'lifetime_drop_m': 60000,
  'lifetime_ski_distance_m': 120000.0,
  'lifetime_run_count': 120,
  'lifetime_day_count': 12,
  'lifetime_max_speed_ms': 22,
  'lifetime_points': 1500,
  'lifetime_avg_ski_speed_ms': 8.0,
  'best_day_drop_m': 2400,
  'best_day_run_count': 12,
  'longest_streak': 3,
  'resort_count': 3,
  'country_count': 1,
  'last_day': '2026-01-13T09:00:00+00:00',
};

/// Records what the sheet handed to the share sink.
class ShareRecorder {
  final List<(String, String)> shared = [];
  Future<void> call({required String text, required String subject}) async => shared.add((text, subject));
}

List<Override> riderOverrides({required FakeRiderApi api, ShareRecorder? share, RiderActions actions = const RiderActions()}) => [
      riderApiProvider.overrideWithValue(api),
      riderActionsProvider.overrideWithValue(actions),
      if (share != null) riderShareProvider.overrideWithValue(share.call),
    ];
