import 'package:drift/drift.dart' show Value;
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
  String? countryCode,
}) =>
    {
      'id': id,
      'user_id': 'u1',
      'started_at': _iso(startedAt),
      'ended_at': _iso(startedAt + 3600000),
      'resort_id': 'kitzbuehel',
      'resort_name': resortName,
      'country_code': countryCode,
      'points': (dropM / 10 + 30000.0 / 100 + runCount * 5 + 50).round(),
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

/// Moves a day's last-edit time to [at] — the repository stamps the wall
/// clock, a merge test needs to say which edit was first.
Future<void> stampUpdatedAt(AppDatabase db, String dayId, int at) =>
    (db.update(db.days)..where((d) => d.id.equals(dayId))).write(DaysCompanion(updatedAt: Value(at)));

/// In-memory [SyncApi]; records every call and can fail on demand.
///
/// With [serverMode] it also behaves like the `days` table: an upsert lands in
/// [remoteDays] (absent keys keep their value, `updated_at` moves with
/// `device_updated_at` as the triggers of migration 0015 do), so two
/// [SyncService]s on two databases can share one instance as 'the backend'.
class FakeSyncApi implements SyncApi {
  FakeSyncApi({this.userId = 'u1', this.serverMode = false});

  @override
  String? userId;

  final bool serverMode;

  /// Server clock in [serverMode], ms epoch; every write moves it on by 1 s.
  int serverNow = sampleStartedAt + 86400000;

  final List<Map<String, Object?>> upserts = [];

  /// Every [upsertDay] call, rejected ones included.
  int upsertCalls = 0;

  /// `sinceMs` of every fetchDays call (one per page).
  final List<int?> fetchCursors = [];

  /// `after` of every fetchDays call: null for the first page, then the key
  /// of the previous page's last row.
  final List<PageKey?> fetchKeys = [];

  /// Runs after each page was cut, with the 1-based page number — lets a test
  /// change [remoteDays] in the middle of a pull.
  void Function(int page)? afterFetch;

  final List<String> uploads = [];
  final List<String> removed = [];

  /// Every [setTrackPath] call (the extra write after a first upload).
  final List<String> trackPathWrites = [];
  final Map<String, String> trackPaths = {};

  /// Storage: path → gzip bytes.
  final Map<String, List<int>> storage = {};

  List<Map<String, Object?>> remoteDays = [];

  /// Thrown by every call while set.
  Object? failure;

  /// Thrown by [upsertDay] only — a 500 on the write while the pull works.
  Object? upsertFailure;

  /// Thrown by [fetchDays] only — a broken pull while writes work.
  Object? fetchFailure;

  /// Thrown by the next [failuresLeft] calls only, then cleared.
  int failuresLeft = 0;

  /// Pretends there is no network: the outbox must stay intact.
  bool offline = false;

  int refreshCalls = 0;

  /// What [refreshSession] answers; set false to simulate a dead refresh token.
  bool refreshResult = true;

  /// Runs after a successful refresh — e.g. to clear [failure].
  void Function()? onRefresh;

  void _check() {
    if (offline) throw const SyncOffline('test offline');
    final f = failure;
    if (f != null) {
      if (failuresLeft > 0) {
        failuresLeft--;
        if (failuresLeft == 0) failure = null;
      }
      throw f;
    }
  }

  @override
  Future<void> upsertDay(Map<String, Object?> row) async {
    upsertCalls++;
    _check();
    final f = upsertFailure;
    if (f != null) throw f;
    upserts.add(row);
    final id = row['id'] as String;
    if (row.containsKey('track_path')) {
      final path = row['track_path'] as String?;
      if (path == null) {
        trackPaths.remove(id);
      } else {
        trackPaths[id] = path;
      }
    }
    if (serverMode) _store(id, row);
  }

  void _store(String id, Map<String, Object?> row) {
    final i = remoteDays.indexWhere((r) => r['id'] == id);
    final old = i < 0 ? null : remoteDays[i];
    final merged = <String, Object?>{'track_path': null, ...?old, ...row};
    if (old == null || old['device_updated_at'] != row['device_updated_at']) {
      serverNow += 1000;
      merged['updated_at'] = _iso(serverNow);
    }
    merged['created_at'] = old?['created_at'] ?? merged['updated_at'];
    if (i < 0) {
      remoteDays.add(merged);
    } else {
      remoteDays[i] = merged;
    }
  }

  static int _micros(Map<String, Object?> r) => DateTime.tryParse(r['updated_at'] as String? ?? '')?.microsecondsSinceEpoch ?? 0;

  static int _order(Map<String, Object?> a, Map<String, Object?> b) {
    final byTime = _micros(a).compareTo(_micros(b));
    return byTime != 0 ? byTime : (a['id'] as String).compareTo(b['id'] as String);
  }

  @override
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs, PageKey? after, int limit = 500}) async {
    fetchCursors.add(sinceMs);
    fetchKeys.add(after);
    _check();
    final f = fetchFailure;
    if (f != null) throw f;
    final sorted = [...remoteDays]..sort(_order);
    final Iterable<Map<String, Object?>> rows;
    if (after != null) {
      final key = {'updated_at': after.updatedAt, 'id': after.id};
      rows = sorted.where((r) => _order(r, key) > 0);
    } else {
      rows = sorted.where((r) => sinceMs == null || _micros(r) > sinceMs * 1000);
    }
    final page = [for (final r in rows.take(limit)) Map<String, Object?>.from(r)];
    afterFetch?.call(fetchKeys.length);
    return page;
  }

  @override
  Future<String> uploadTrack(String dayId, List<int> gzipBytes) async {
    _check();
    uploads.add(dayId);
    final path = '$userId/$dayId.json.gz';
    storage[path] = gzipBytes;
    return path;
  }

  @override
  Future<void> setTrackPath(String dayId, String path) async {
    _check();
    trackPathWrites.add(dayId);
    trackPaths[dayId] = path;
    if (serverMode) {
      final i = remoteDays.indexWhere((r) => r['id'] == dayId);
      // device_updated_at unchanged → updated_at stays (migration 0015).
      if (i >= 0) remoteDays[i] = {...remoteDays[i], 'track_path': path};
    }
  }

  @override
  Future<String?> trackPathOf(String dayId) async {
    _check();
    return trackPaths[dayId];
  }

  @override
  Future<List<int>?> downloadTrack(String dayId) async {
    _check();
    final path = trackPaths[dayId];
    return path == null ? null : storage[path];
  }

  @override
  Future<void> removeTrack(String dayId) async {
    _check();
    removed.add(dayId);
    storage.remove('$userId/$dayId.json.gz');
  }

  @override
  Future<bool> refreshSession() async {
    if (offline) throw const SyncOffline('test offline');
    refreshCalls++;
    if (refreshResult) onRefresh?.call();
    return refreshResult;
  }
}
