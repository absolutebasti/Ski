import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/share/diagnostics_bundle.dart';
import '../db/database.dart';
import '../db/days_repository.dart';
import '../db/mappers.dart';
import '../db/providers.dart';
import 'auth_service.dart';
import 'remote_day.dart';
import 'sync_api.dart';
import 'sync_store.dart';

enum SyncState { idle, syncing, offline, error }

@immutable
class SyncStatus {
  const SyncStatus({this.state = SyncState.idle, this.lastSyncAt, this.pending = 0, this.message});

  final SyncState state;

  /// ms epoch of the last completed pull, null when never synced.
  final int? lastSyncAt;

  /// Days still waiting in the outbox.
  final int pending;
  final String? message;

  SyncStatus copyWith({SyncState? state, int? lastSyncAt, int? pending, String? message}) => SyncStatus(
        state: state ?? this.state,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pending: pending ?? this.pending,
        message: message,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.state == state &&
      other.lastSyncAt == lastSyncAt &&
      other.pending == pending &&
      other.message == message;

  @override
  int get hashCode => Object.hash(state, lastSyncAt, pending, message);

  @override
  String toString() => 'SyncStatus($state, pending: $pending, lastSyncAt: $lastSyncAt)';
}

/// Encodes the raw track of a day for the storage backup; null = nothing to
/// upload.
typedef TrackEncoder = Future<List<int>?> Function(String dayId);

/// Local-first sync: drift is the truth, the backend is a copy.
///
/// Nothing here ever blocks the UI — callers fire and forget; failures land in
/// [status] and the outbox.
class SyncService {
  SyncService({
    required this.repo,
    required this.api,
    this.store = const PrefsSyncStore(),
    TrackEncoder? trackEncoder,
    this.sleep = _realSleep,
    this.maxAttempts = 3,
  }) {
    _trackEncoder = trackEncoder ?? _defaultTrackEncoder;
  }

  final DaysRepository repo;

  /// Null while the backend is unavailable — every call becomes a no-op.
  final SyncApi? api;
  final SyncStore store;

  /// Injected so tests do not wait out the backoff.
  final Future<void> Function(Duration) sleep;

  /// After this many failed attempts an outbox entry is left alone.
  final int maxAttempts;

  late final TrackEncoder _trackEncoder;
  final StreamController<SyncStatus> _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  bool _running = false;
  bool _disposed = false;

  SyncStatus get current => _current;

  /// Seeded with the current value, so late listeners see the state at once.
  Stream<SyncStatus> get status async* {
    yield _current;
    yield* _status.stream;
  }

  bool get isAvailable => api?.userId != null;

  Future<int> pendingCount() => repo.outboxCount();

  // ------------------------------------------------------------------ push

  /// Upserts the day's aggregates, then (best effort) backs up the raw track.
  Future<void> pushDay(String dayId) => _push(dayId, deleted: false);

  /// Pushes the tombstone of a soft-deleted day.
  Future<void> pushDelete(String dayId) => _push(dayId, deleted: true);

  Future<void> _push(String dayId, {required bool deleted}) async {
    final api = this.api;
    final uid = api?.userId;
    if (api == null || uid == null) return;
    final row = await _dayRow(dayId);
    if (row == null) {
      // Hard-discarded locally — nothing left to push.
      await repo.markSynced(dayId, DateTime.now().millisecondsSinceEpoch);
      return;
    }
    final deviceUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    await api.upsertDay(dayRowToRemote(
      row,
      userId: uid,
      deviceUpdatedAtMs: deviceUpdatedAt,
      deleted: deleted || row.deletedAt != null,
    ));
    await repo.markSynced(dayId, deviceUpdatedAt);
    if (!deleted && row.deletedAt == null) await _backupTrack(api, dayId);
  }

  /// Storage upload is a bonus, never a reason to fail a push.
  Future<void> _backupTrack(SyncApi api, String dayId) async {
    try {
      final bytes = await _trackEncoder(dayId);
      if (bytes == null || bytes.isEmpty) return;
      final path = await api.uploadTrack(dayId, bytes);
      await api.setTrackPath(dayId, path);
    } catch (e) {
      debugPrint('track backup failed for $dayId: $e');
    }
  }

  // ------------------------------------------------------------------ pull

  /// Merges every remote day changed since the stored cursor.
  Future<void> pullAll() async {
    final api = this.api;
    if (api == null || api.userId == null) return;
    final since = await store.lastSyncAt();
    final rows = await api.fetchDays(sinceMs: since);
    var cursor = since ?? 0;
    for (final row in rows) {
      final updatedAt = remoteTs(row['updated_at']) ?? remoteTs(row['device_updated_at']) ?? 0;
      if (updatedAt > cursor) cursor = updatedAt;
      final id = row['id'] as String?;
      if (id == null) continue;
      if (row['deleted_at'] != null) {
        await repo.softDeleteFromRemote(id, remoteUpdatedAt: updatedAt == 0 ? null : updatedAt);
      } else {
        await repo.upsertFromRemote(row);
      }
    }
    // Only ever move forward on a server timestamp — the device clock may be
    // off, and advancing it blindly would skip rows written in the meantime.
    if (cursor > (since ?? 0)) {
      await store.setLastSyncAt(cursor);
      _current = _current.copyWith(lastSyncAt: cursor);
    }
  }

  // ------------------------------------------------------------------ loop

  /// Drains the outbox, then pulls. Safe to call at any time; concurrent calls
  /// collapse into one.
  Future<void> syncNow() async {
    if (_disposed || _running) return;
    final api = this.api;
    if (api == null || api.userId == null) {
      await _emit(SyncState.idle);
      return;
    }
    _running = true;
    try {
      await _emit(SyncState.syncing);
      if (!await _drainOutbox()) return;
      await pullAll();
      await _emit(SyncState.idle);
    } on SyncOffline catch (e) {
      await _emit(SyncState.offline, message: e.message);
    } catch (e) {
      await _emit(SyncState.error, message: '$e');
    } finally {
      _running = false;
    }
  }

  /// Returns false when we went offline and the outbox stays untouched.
  Future<bool> _drainOutbox() async {
    for (final entry in await repo.outbox()) {
      if (entry.attempts >= maxAttempts) continue;
      try {
        final op = SyncOpX.fromDb(entry.op);
        await _push(entry.dayId, deleted: op == SyncOp.delete);
      } on SyncOffline catch (e) {
        await _emit(SyncState.offline, message: e.message);
        return false;
      } catch (e) {
        await repo.bumpAttempt(entry.id, '$e');
        await sleep(backoffFor(entry.attempts));
      }
    }
    return true;
  }

  /// 1 s, 2 s, 4 s — enough to ride out a flaky lift-station connection.
  static Duration backoffFor(int attempts) => Duration(seconds: 1 << attempts.clamp(0, 6));

  Future<void> _emit(SyncState state, {String? message}) async {
    if (_disposed) return;
    final pending = await pendingCount();
    _current = SyncStatus(state: state, lastSyncAt: _current.lastSyncAt, pending: pending, message: message);
    if (!_status.isClosed) _status.add(_current);
  }

  Future<DayRow?> _dayRow(String dayId) =>
      (repo.db.select(repo.db.days)..where((d) => d.id.equals(dayId))).getSingleOrNull();

  /// Diagnostics-style gzip JSON of the whole day (raw points included).
  Future<List<int>?> _defaultTrackEncoder(String dayId) async {
    final row = await _dayRow(dayId);
    if (row == null) return null;
    final points = await repo.pointsRaw(dayId);
    if (points.isEmpty) return null;
    final segments = await repo.segmentsOf(dayId);
    return DiagnosticsBundle.encode(
      DiagnosticsBundle.toJson(day: dayFromRow(row), segments: segments, points: points, device: 'sync'),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _status.close();
  }

  static Future<void> _realSleep(Duration d) => Future<void>.delayed(d);
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(repo: ref.watch(daysRepositoryProvider), api: ref.watch(syncApiProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Hook for main.dart: syncs on start, on every sign-in and whenever the
/// outbox has work while the app is in the foreground.
void startAutoSync(Ref ref) {
  final service = ref.read(syncServiceProvider);
  String? lastUserId;
  ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (previous, next) {
    final user = next.value;
    if (user == null) {
      lastUserId = null;
      return;
    }
    if (user.id == lastUserId) return;
    lastUserId = user.id;
    unawaited(service.syncNow());
  }, fireImmediately: true);

  unawaited(service.syncNow());

  final timer = Timer.periodic(const Duration(seconds: 30), (_) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (await service.pendingCount() > 0) unawaited(service.syncNow());
  });
  ref.onDispose(timer.cancel);
}

/// `ref.read(autoSyncProvider)` once in main.dart starts the loop.
final autoSyncProvider = Provider<void>(startAutoSync);
