import 'package:drift/native.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/sync/sync_api.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

/// Distinct values for every field so the push mapping can be asserted.
const DayStats sampleStats = DayStats(
  elapsedMs: 21600000,
  skiMs: 3600000,
  liftMs: 5400000,
  pauseMs: 1800000,
  signalLossMs: 60000,
  otherMs: 120000,
  runCount: 17,
  liftCount: 16,
  dropM: 8123.5,
  ascentM: 8010.25,
  skiDistanceM: 41234.75,
  liftDistanceM: 22111.5,
  totalDistanceM: 63346.25,
  maxSpeedMs: 24.5,
  avgSkiSpeedMs: 11.25,
  maxAltM: 2310.5,
  minAltM: 812.25,
  acceptedFixes: 4200,
  rejectedFixes: 33,
  hasBarometer: true,
  vehicleFlag: true,
  avgHeartRateBpm: 132,
  maxHeartRateBpm: 178,
);

/// 2026-01-15 08:00 UTC — inside season 2025/26.
const int sampleStartedAt = 1768464000000;

Future<void> seedFinishedDay(
  DaysRepository repo, {
  String id = 'd1',
  int startedAt = sampleStartedAt,
  DayStats stats = sampleStats,
  String? resortId = 'kitzbuehel',
  String? resortName = 'Kitzbühel',
  List<TrackPoint> points = const [],
}) async {
  await repo.createActiveDay(id: id, startedAt: startedAt, resortId: resortId, resortName: resortName);
  if (points.isNotEmpty) await repo.appendPoints(id, points);
  await repo.finishDay(id, endedAt: startedAt + stats.elapsedMs, stats: stats, segments: const []);
}

List<TrackPoint> samplePoints({int startedAt = sampleStartedAt, int count = 5}) => [
      for (var i = 0; i < count; i++)
        TrackPoint(
          ts: startedAt + i * 1000,
          lat: 47.44 + i * 0.0001,
          lon: 12.39 + i * 0.0001,
          gpsAltM: 1800 - i.toDouble(),
          fusedAltM: 1800 - i.toDouble(),
          speedMs: 10 + i.toDouble(),
          accepted: true,
          state: MotionState.run,
        ),
    ];

/// One remote `days` row as the backend returns it (ISO timestamps).
Map<String, Object?> remoteRow({
  String id = 'd1',
  int startedAt = sampleStartedAt,
  required int deviceUpdatedAt,
  int? updatedAt,
  int? deletedAt,
  double dropM = 5000,
  double maxSpeedMs = 20,
  int runCount = 10,
  String? resortName = 'Remote-Gebiet',
}) =>
    {
      'id': id,
      'user_id': 'u1',
      'started_at': _iso(startedAt),
      'ended_at': _iso(startedAt + 3600000),
      'resort_id': 'kitzbuehel',
      'resort_name': resortName,
      'season_key': seasonKeyFromMs(startedAt),
      'run_count': runCount,
      'lift_count': 9,
      'drop_m': dropM,
      'ascent_m': 4900.0,
      'ski_distance_m': 30000.0,
      'lift_distance_m': 20000.0,
      'max_speed_ms': maxSpeedMs,
      'avg_ski_speed_ms': 10.5,
      'ski_ms': 3000000,
      'lift_ms': 2000000,
      'pause_ms': 1000000,
      'elapsed_ms': 6000000,
      'max_alt_m': 2000.0,
      'min_alt_m': 900.0,
      'engine_version': 1,
      'has_barometer': true,
      'vehicle_flag': false,
      'track_path': null,
      'device_updated_at': _iso(deviceUpdatedAt),
      'deleted_at': deletedAt == null ? null : _iso(deletedAt),
      'created_at': _iso(startedAt),
      'updated_at': _iso(updatedAt ?? deviceUpdatedAt),
    };

String _iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

/// In-memory [SyncApi]; records every call and can fail on demand.
class FakeSyncApi implements SyncApi {
  FakeSyncApi({this.userId = 'u1'});

  @override
  String? userId;

  final List<Map<String, Object?>> upserts = [];
  final List<int?> fetchCursors = [];
  final List<String> uploads = [];
  final Map<String, String> trackPaths = {};

  List<Map<String, Object?>> remoteDays = [];

  /// Thrown by every call while set.
  Object? failure;

  /// Pretends there is no network: the outbox must stay intact.
  bool offline = false;

  void _check() {
    if (offline) throw const SyncOffline('test offline');
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<void> upsertDay(Map<String, Object?> row) async {
    _check();
    upserts.add(row);
  }

  @override
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs}) async {
    _check();
    fetchCursors.add(sinceMs);
    return remoteDays;
  }

  @override
  Future<String> uploadTrack(String dayId, List<int> gzipBytes) async {
    _check();
    uploads.add(dayId);
    return '$userId/$dayId.json.gz';
  }

  @override
  Future<void> setTrackPath(String dayId, String path) async {
    _check();
    trackPaths[dayId] = path;
  }
}
