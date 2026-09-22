import '../../core/core.dart';
import '../db/database.dart';

/// Maps a local `days` row onto the backend's `days` columns.
///
/// Server-generated columns (`suspicious`, `created_at`, `updated_at`) are
/// never written; `season_key` comes from core/season.dart.
Map<String, Object?> dayRowToRemote(
  DayRow r, {
  required String userId,
  required int deviceUpdatedAtMs,
  bool deleted = false,
  String? trackPath,
}) {
  final deletedAt = deleted ? (r.deletedAt ?? deviceUpdatedAtMs) : r.deletedAt;
  return {
    'id': r.id,
    'user_id': userId,
    'started_at': _iso(r.startedAt),
    'ended_at': _isoOrNull(r.endedAt),
    'resort_id': r.resortId,
    'resort_name': r.resortName,
    'season_key': seasonKeyFromMs(r.startedAt),
    'run_count': r.runCount,
    'lift_count': r.liftCount,
    'drop_m': r.dropM,
    'ascent_m': r.ascentM,
    'ski_distance_m': r.skiDistanceM,
    'lift_distance_m': r.liftDistanceM,
    'max_speed_ms': r.maxSpeedMs,
    'avg_ski_speed_ms': r.avgSkiSpeedMs,
    'ski_ms': r.skiMs,
    'lift_ms': r.liftMs,
    'pause_ms': r.pauseMs,
    'elapsed_ms': r.elapsedMs,
    'max_alt_m': r.maxAltM,
    'min_alt_m': r.minAltM,
    'engine_version': r.engineVersion,
    'has_barometer': r.hasBarometer,
    'vehicle_flag': r.vehicleFlag,
    'track_path': ?trackPath,
    'device_updated_at': _iso(deviceUpdatedAtMs),
    'deleted_at': _isoOrNull(deletedAt),
  };
}

String _iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

String? _isoOrNull(int? ms) => ms == null ? null : _iso(ms);

/// Accepts ms epoch ints and ISO-8601 strings (Postgres `timestamptz`).
int? remoteTs(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? int.tryParse(v);
  return null;
}
