import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../features/share/diagnostics_bundle.dart';
import '../../tracking/tracking.dart';
import '../db/days_repository.dart';
import '../db/providers.dart';
import 'sync_api.dart';

/// Brings the raw track of a pulled day back onto the phone (SYNC-HARDENING).
///
/// A day that arrived via pull has aggregates but no points. When its backend
/// row carries a `track_path`, the gzip [DiagnosticsBundle] is downloaded and
/// decoded into points and segments; the DayStats columns are recomputed from
/// them (signal loss, accepted/rejected fixes, heart rate …) since the backend
/// never stores those.
class TrackRestoreService {
  const TrackRestoreService({required this.repo, required this.api});

  final DaysRepository repo;

  /// Null while the backend is unavailable — nothing can be restored.
  final SyncApi? api;

  /// True when [dayId] is a finished day without local points and the backend
  /// has a backup for it. Never throws.
  Future<bool> hasRemoteTrack(String dayId) async {
    final api = this.api;
    if (api == null || api.userId == null) return false;
    try {
      final day = await repo.day(dayId);
      if (day == null || day.status == DayStatus.active) return false;
      if (await repo.pointCount(dayId) > 0) return false;
      final path = await api.trackPathOf(dayId);
      return path != null && path.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Downloads and writes the track; true when points were restored. False
  /// when nothing was to do (signed out, day has points, no backup). Throws on
  /// network or decode failures so the caller can show a toast.
  Future<bool> restore(String dayId) async {
    final api = this.api;
    if (api == null || api.userId == null) return false;
    final day = await repo.day(dayId);
    if (day == null || day.status == DayStatus.active) return false;
    if (await repo.pointCount(dayId) > 0) return false;
    final bytes = await api.downloadTrack(dayId);
    if (bytes == null || bytes.isEmpty) return false;
    final decoded = decodeBundle(dayId, bytes, hasBarometer: day.stats.hasBarometer);
    if (decoded.points.isEmpty) return false;
    await repo.restoreTrack(dayId, points: decoded.points, segments: decoded.segments, stats: decoded.stats);
    return true;
  }

  /// Pure: bundle bytes → points, segments (from the bundle, else replayed
  /// through the engine) and recomputed stats.
  static DayComputation decodeBundle(String dayId, List<int> bytes, {bool hasBarometer = false}) {
    final json = DiagnosticsBundle.decode(bytes);
    final points = [
      for (final p in (json['points'] as List?) ?? const [])
        if (p is Map) TrackPoint.fromJson(Map<String, Object?>.from(p)),
    ]..sort((a, b) => a.ts.compareTo(b.ts));
    var segments = [
      for (final s in (json['segments'] as List?) ?? const [])
        if (s is Map) segmentFromJson(Map<String, Object?>.from(s), dayId: dayId),
    ]..sort((a, b) => a.idx.compareTo(b.idx));
    if (segments.isEmpty && points.isNotEmpty) {
      segments = TrackingEngine.computeDay(dayId, points).segments;
    }
    final day = json['day'];
    final bundleStats = day is Map ? day['stats'] : null;
    final baro = bundleStats is Map && bundleStats['hasBarometer'] is bool ? bundleStats['hasBarometer'] as bool : hasBarometer;
    final stats = computeDayStats(segments, points, hasBarometer: baro);
    return DayComputation(segments: segments, stats: stats, points: points);
  }

  /// Inverse of [DiagnosticsBundle.segmentToJson].
  static Segment segmentFromJson(Map<String, Object?> j, {required String dayId}) => Segment(
        id: (j['id'] as String?) ?? '$dayId-${j['idx']}',
        dayId: dayId,
        kind: SegmentKind.values.firstWhere((e) => e.name == j['kind'], orElse: () => SegmentKind.other),
        idx: _i(j['idx']),
        runNumber: _in(j['runNumber']),
        startTs: _i(j['startTs']),
        endTs: _i(j['endTs']),
        startAltM: _d(j['startAltM']),
        endAltM: _d(j['endAltM']),
        dropM: _d(j['dropM']),
        distanceM: _d(j['distanceM']),
        movingMs: _i(j['movingMs']),
        maxSpeedMs: _d(j['maxSpeedMs']),
        maxSpeedAtTs: _in(j['maxSpeedAtTs']),
        avgSpeedMs: _d(j['avgSpeedMs']),
        avgGradientPct: _d(j['avgGradientPct']),
        steepest100mPct: _dn(j['steepest100mPct']),
        startPointTs: _in(j['startPointTs']),
        endPointTs: _in(j['endPointTs']),
        flags: _i(j['flags']),
        pisteName: j['pisteName'] as String?,
        pisteOsmId: j['pisteOsmId'] as String?,
        liftName: j['liftName'] as String?,
      );

  static int _i(Object? v) => _in(v) ?? 0;
  static int? _in(Object? v) => v is num ? v.toInt() : null;
  static double _d(Object? v) => _dn(v) ?? 0;
  static double? _dn(Object? v) => v is num ? v.toDouble() : null;
}

final trackRestoreServiceProvider = Provider<TrackRestoreService>(
  (ref) => TrackRestoreService(repo: ref.watch(daysRepositoryProvider), api: ref.watch(syncApiProvider)),
);

/// Restores the track of [dayId] when it has none locally; resolves to true
/// when points were written. Reading it triggers the download — the caller
/// invalidates `dayDetailProvider(dayId)` afterwards.
final trackRestoreProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, dayId) => ref.watch(trackRestoreServiceProvider).restore(dayId),
);

/// Whether 'Spur laden' applies to [dayId]: no local points, backup exists.
final hasRemoteTrackProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, dayId) => ref.watch(trackRestoreServiceProvider).hasRemoteTrack(dayId),
);
