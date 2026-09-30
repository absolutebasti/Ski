import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/settings.dart';
import '../../features/account/profile_service.dart';
import '../../features/share/diagnostics_bundle.dart';
import '../db/database.dart';
import '../db/days_repository.dart';
import '../db/mappers.dart';
import '../db/providers.dart';
import '../resorts/resort_repository.dart';
import 'auth_service.dart';
import 'profile_repair.dart';
import 'remote_day.dart';
import 'sync_api.dart';
import 'sync_store.dart';

/// [throttled]: the server rate-limited the pushes (`rate_limited`, P0005);
/// the outbox waits for [SyncService.throttleWindow] and goes on by itself —
/// the Konto row says 'Sync pausiert, geht gleich weiter', never 'offline'.
enum SyncState { idle, syncing, offline, throttled, error }

@immutable
class SyncStatus {
  const SyncStatus({this.state = SyncState.idle, this.lastSyncAt, this.pending = 0, this.message, this.needsSignIn = false});

  final SyncState state;

  /// ms epoch of the last completed pull, null when never synced.
  final int? lastSyncAt;

  /// Days still waiting in the outbox.
  final int pending;
  final String? message;

  /// [SyncState.error] because the session is gone: a 401 survived one token
  /// refresh. The Konto sheet asks for a fresh Sign in with Apple.
  final bool needsSignIn;

  SyncStatus copyWith({SyncState? state, int? lastSyncAt, int? pending, String? message, bool? needsSignIn}) => SyncStatus(
        state: state ?? this.state,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pending: pending ?? this.pending,
        message: message,
        needsSignIn: needsSignIn ?? this.needsSignIn,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.state == state &&
      other.lastSyncAt == lastSyncAt &&
      other.pending == pending &&
      other.message == message &&
      other.needsSignIn == needsSignIn;

  @override
  int get hashCode => Object.hash(state, lastSyncAt, pending, message, needsSignIn);

  @override
  String toString() => 'SyncStatus($state, pending: $pending, lastSyncAt: $lastSyncAt${needsSignIn ? ', needsSignIn' : ''})';
}

/// Encodes the raw track of a day for the storage backup; null = nothing to
/// upload.
typedef TrackEncoder = Future<List<int>?> Function(String dayId);

/// Resolves the team country (ISO alpha-2) a day counts for, given its resort
/// id; null = unknown. The default in [syncServiceProvider] takes the resort's
/// country and falls back to `Settings.countryCode`.
typedef CountryResolver = String? Function(String? resortId);

/// Local-first sync: drift is the truth, the backend is a copy.
///
/// Nothing here ever blocks the UI — callers fire and forget; failures land in
/// [status] and the outbox.
///
/// Retries: a failed push bumps `attempts` and schedules the entry for
/// `now + backoffFor(attempts)` (1 s … 1 h, in memory); the 30 s poll picks it
/// up once due. Attempts are reset on app start and on sign-in.
///
/// Two devices (SYNC-2): `device_updated_at` is the local row's `updatedAt`,
/// so every device merges last-edit-wins. A run pulls first and pushes after:
/// an offline edit that is older than what another device pushed meanwhile
/// loses locally and is never sent. The pull pages by keyset
/// `(updated_at, id)`; a push only clears the outbox entries it actually sent.
class SyncService {
  SyncService({
    required this.repo,
    required this.api,
    this.store = const PrefsSyncStore(),
    TrackEncoder? trackEncoder,
    CountryResolver? countryFor,
    this.now = _realNow,
    this.pageSize = 500,
    this.resumeGap = const Duration(minutes: 5),
    this.throttleWindow = const Duration(minutes: 1),
  }) : countryFor = countryFor ?? _noCountry {
    _trackEncoder = trackEncoder ?? _defaultTrackEncoder;
  }

  final DaysRepository repo;

  /// Null while the backend is unavailable — every call becomes a no-op.
  final SyncApi? api;
  final SyncStore store;

  /// Fills `days.country_code` on push (migration 0004).
  final CountryResolver countryFor;

  /// Injected clock (ms epoch) so tests can move through the backoff.
  final int Function() now;

  /// Rows per `fetchDays` page.
  final int pageSize;

  /// [syncOnResume] only runs when the last sync is older than this.
  final Duration resumeGap;

  /// How long the outbox pauses after the server said `rate_limited`. The
  /// server window is one hour per rider; one rejected write per minute until
  /// it opens again is cheap, and the pull keeps working meanwhile.
  final Duration throttleWindow;

  /// Longest wait between two attempts of one outbox entry.
  static const Duration maxBackoff = Duration(hours: 1);

  late final TrackEncoder _trackEncoder;
  final StreamController<SyncStatus> _status = StreamController<SyncStatus>.broadcast();
  final Map<int, int> _nextAttemptAt = {};
  SyncStatus _current = const SyncStatus();
  bool _running = false;
  bool _disposed = false;
  bool _refreshedThisRun = false;
  int? _lastRunAt;
  int? _throttledUntil;
  String? _throttleMessage;

  SyncStatus get current => _current;

  /// Seeded with the current value, so late listeners see the state at once.
  Stream<SyncStatus> get status async* {
    yield _current;
    yield* _status.stream;
  }

  bool get isAvailable => api?.userId != null;

  Future<int> pendingCount() => repo.outboxCount();

  /// ms epoch before which [outboxId] is not retried; null = due now.
  int? nextAttemptAt(int outboxId) => _nextAttemptAt[outboxId];

  /// ms epoch until which pushes are paused after a `rate_limited`; null = not throttled.
  int? get throttledUntil => _throttledUntil;

  /// True while the pause is still running — the 30 s poll waits it out.
  bool get isThrottled {
    final until = _throttledUntil;
    return until != null && now() < until;
  }

  // ------------------------------------------------------------------ push

  /// Upserts the day's aggregates, then (best effort) backs up the raw track.
  Future<void> pushDay(String dayId) => _push(dayId, deleted: false);

  /// Pushes the tombstone of a soft-deleted day and drops its track backup.
  Future<void> pushDelete(String dayId) => _push(dayId, deleted: true);

  /// [upToOutboxId]: the entry being drained; only entries up to it are
  /// cleared afterwards. Without one, the newest entry at read time is taken.
  ///
  /// Writes per push: one. The backup path travels inside the upsert once the
  /// track is in storage; only the very first push of a day needs the extra
  /// `setTrackPath` after its upload (free on the server since migration 0015).
  Future<void> _push(String dayId, {required bool deleted, int? upToOutboxId}) async {
    final api = this.api;
    final uid = api?.userId;
    if (api == null || uid == null) return;
    // Read before the row: an edit queued from here on gets a higher id and
    // stays queued.
    final upTo = upToOutboxId ?? await repo.latestOutboxId(dayId) ?? 0;
    final row = await _dayRow(dayId);
    if (row == null) {
      // Hard-discarded locally — nothing left to push.
      await repo.markSynced(dayId, now());
      return;
    }
    // Last edit, not push time: what the other device compares against.
    final deviceUpdatedAt = row.updatedAt;
    final tombstone = deleted || row.deletedAt != null;
    await api.upsertDay(dayRowToRemote(
      row,
      userId: uid,
      deviceUpdatedAtMs: deviceUpdatedAt,
      deleted: tombstone,
      trackPath: row.trackPath,
      countryCode: countryFor(row.resortId),
    ));
    await repo.markSynced(dayId, deviceUpdatedAt, upToOutboxId: upTo);
    if (tombstone) {
      await _removeTrack(api, dayId);
    } else if (row.trackPath == null) {
      await _backupTrack(api, row);
    }
  }

  /// Storage upload is a bonus, never a reason to fail a push. Runs once per
  /// finished track: the path is kept locally (`finishDay` clears it again)
  /// and travels inside the next upsert.
  Future<void> _backupTrack(SyncApi api, DayRow row) async {
    try {
      final bytes = await _trackEncoder(row.id);
      if (bytes == null || bytes.isEmpty) return;
      final path = await api.uploadTrack(row.id, bytes);
      await api.setTrackPath(row.id, path);
      // Not when the day changed during the upload — that track is stale.
      await repo.setTrackPath(row.id, path, ifUpdatedAt: row.updatedAt);
    } catch (e) {
      debugPrint('track backup failed for ${row.id}: $e');
    }
  }

  /// Same for the storage delete: the tombstone is what matters.
  Future<void> _removeTrack(SyncApi api, String dayId) async {
    try {
      await api.removeTrack(dayId);
    } catch (e) {
      debugPrint('track removal failed for $dayId: $e');
    }
  }

  // ------------------------------------------------------------------ pull

  /// Merges every remote day changed since the user's stored cursor, page by
  /// page (keyset on `(updated_at, id)`); the cursor only moves once the last
  /// page is in.
  Future<void> pullAll() async {
    final api = this.api;
    final uid = api?.userId;
    if (api == null || uid == null) return;
    final since = await store.lastSyncAt(uid);
    var cursor = since ?? 0;
    PageKey? after;
    while (true) {
      final rows = await api.fetchDays(sinceMs: since, after: after, limit: pageSize);
      for (final row in rows) {
        final updatedAt = remoteTs(row['updated_at']) ?? remoteTs(row['device_updated_at']) ?? 0;
        if (updatedAt > cursor) cursor = updatedAt;
        final id = row['id'] as String?;
        if (id == null) continue;
        if (row['deleted_at'] != null) {
          // The device clock of the delete, like every other merge: so the own
          // tombstone coming back (markSynced stored device_updated_at) is a no-op.
          final editedAt = remoteTs(row['device_updated_at']) ?? updatedAt;
          await repo.softDeleteFromRemote(id, remoteUpdatedAt: editedAt == 0 ? null : editedAt);
        } else {
          await repo.upsertFromRemote(row);
        }
      }
      if (rows.length < pageSize) break;
      final next = PageKey.of(rows.last);
      if (next == null || next == after) break; // malformed page — never loop
      after = next;
    }
    // Only ever move forward on a server timestamp — the device clock may be
    // off, and advancing it blindly would skip rows written in the meantime.
    if (cursor > (since ?? 0)) {
      await store.setLastSyncAt(uid, cursor);
      _current = _current.copyWith(lastSyncAt: cursor);
    }
  }

  // ------------------------------------------------------------------ loop

  /// Pulls, then drains the outbox. Safe to call at any time; concurrent calls
  /// collapse into one.
  ///
  /// Pull first (SYNC-2): the merge decides which local edits are still the
  /// newest before anything is sent — the server takes whatever arrives, so
  /// pushing an old offline edit first would overwrite a newer one from
  /// another device. A pull that fails for another reason than the network or
  /// the session does not hold the outbox back; the run then ends in `error`.
  Future<void> syncNow() async {
    if (_disposed || _running) return;
    final api = this.api;
    final uid = api?.userId;
    if (api == null || uid == null) {
      await _emit(SyncState.idle);
      return;
    }
    _running = true;
    _refreshedThisRun = false;
    try {
      await _emit(SyncState.syncing);
      await _handleUserChange(uid);
      Object? pullError;
      try {
        await _withAuthRetry(pullAll);
      } on SyncOffline {
        rethrow;
      } on SyncNeedsSignIn {
        rethrow;
      } catch (e) {
        pullError = e;
      }
      final drained = await _drainOutbox();
      if (drained == _Drain.offline) return;
      if (pullError != null) {
        await _emit(SyncState.error, message: '$pullError');
        return;
      }
      _lastRunAt = now();
      if (drained == _Drain.throttled) {
        await _emit(SyncState.throttled, message: _throttleMessage);
      } else {
        await _emit(SyncState.idle);
      }
    } on SyncOffline catch (e) {
      await _emit(SyncState.offline, message: e.message);
    } on SyncNeedsSignIn catch (e) {
      await _emit(SyncState.error, message: e.message, needsSignIn: true);
    } catch (e) {
      await _emit(SyncState.error, message: '$e');
    } finally {
      _running = false;
    }
  }

  /// App start and sign-in: every outbox entry gets a fresh run of retries.
  Future<void> resetAttempts() async {
    _nextAttemptAt.clear();
    await repo.resetAttempts();
  }

  /// [resetAttempts] + [syncNow] — what start and sign-in call.
  Future<void> syncFresh() async {
    await resetAttempts();
    await syncNow();
  }

  /// `AppLifecycleState.resumed`: a pull at most every [resumeGap].
  Future<void> syncOnResume() async {
    final last = _lastRunAt;
    if (last != null && now() - last < resumeGap.inMilliseconds) return;
    await syncNow();
  }

  /// The explicit 'take over my local days' confirm: from now on outbox
  /// entries follow a Konto switch, and everything unsynced is queued again.
  Future<void> migrateLocalDays() async {
    await store.setMigrateOutboxOnUserChange(true);
    await repo.requeueUnsynced();
    await syncFresh();
  }

  /// Another Konto than last time: its cursor starts where it left off (epoch
  /// for a new one). Entries queued under the previous Konto are dropped —
  /// the days stay local — unless the confirm flag says to migrate them.
  Future<void> _handleUserChange(String uid) async {
    final previous = await store.lastUserId();
    if (previous == uid) return;
    if (previous != null) {
      if (await store.migrateOutboxOnUserChange()) {
        await resetAttempts();
      } else {
        await repo.clearOutbox();
        _nextAttemptAt.clear();
      }
    }
    await store.setLastUserId(uid);
    // Explicit: a fresh Konto starts without the previous Konto's cursor.
    _current = SyncStatus(state: _current.state, pending: _current.pending, lastSyncAt: await store.lastSyncAt(uid), message: _current.message, needsSignIn: _current.needsSignIn);
  }

  /// [_Drain.offline] when we went offline (the outbox stays untouched);
  /// [_Drain.throttled] while the server rate limit is on — nothing is sent
  /// until [throttleWindow] is over, then the drain simply tries again.
  Future<_Drain> _drainOutbox() async {
    if (isThrottled) return _Drain.throttled;
    _throttledUntil = null;
    _throttleMessage = null;
    for (final entry in await repo.outbox()) {
      final due = _nextAttemptAt[entry.id];
      if (due != null && now() < due) continue;
      try {
        final op = SyncOpX.fromDb(entry.op);
        await _withAuthRetry(() => _push(entry.dayId, deleted: op == SyncOp.delete, upToOutboxId: entry.id));
        _nextAttemptAt.remove(entry.id);
      } on SyncOffline catch (e) {
        await _emit(SyncState.offline, message: e.message);
        return _Drain.offline;
      } on SyncNeedsSignIn {
        rethrow;
      } on PostgrestException catch (e) {
        if (e.code == 'P0005') {
          // rate_limited (migration 0006) is per rider: the whole outbox
          // pauses for the window, nothing counts as a failed attempt.
          _throttledUntil = now() + throttleWindow.inMilliseconds;
          _throttleMessage = e.message;
          return _Drain.throttled;
        }
        // too_many_days (P0004) concerns this one day (3 per local date): it
        // backs off like any failure so the rest of the outbox still drains.
        await _fail(entry, e);
      } catch (e) {
        await _fail(entry, e);
      }
    }
    return _Drain.done;
  }

  Future<void> _fail(SyncOutboxRow entry, Object e) async {
    final attempts = await repo.bumpAttempt(entry.id, '$e');
    _nextAttemptAt[entry.id] = now() + backoffFor(attempts).inMilliseconds;
  }

  /// Runs [op]; on a 401 refreshes the session once per run and retries. A
  /// second 401 (or a failed refresh) becomes [SyncNeedsSignIn].
  Future<T> _withAuthRetry<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      if (e is SyncOffline || !SupabaseSyncApi.isAuthError(e)) rethrow;
      if (_refreshedThisRun) throw SyncNeedsSignIn('$e');
      _refreshedThisRun = true;
      final api = this.api;
      if (api == null || !await api.refreshSession()) throw SyncNeedsSignIn('$e');
      try {
        return await op();
      } catch (e2) {
        if (e2 is SyncOffline || !SupabaseSyncApi.isAuthError(e2)) rethrow;
        throw SyncNeedsSignIn('$e2');
      }
    }
  }

  /// Wait after [attempts] failures: 1 s, 2 s, 4 s … capped at [maxBackoff].
  static Duration backoffFor(int attempts) {
    final seconds = 1 << (attempts - 1).clamp(0, 12);
    return Duration(seconds: math.min(seconds, maxBackoff.inSeconds));
  }

  Future<void> _emit(SyncState state, {String? message, bool needsSignIn = false}) async {
    if (_disposed) return;
    final pending = await pendingCount();
    _current = SyncStatus(
      state: state,
      lastSyncAt: _current.lastSyncAt,
      pending: pending,
      message: message,
      needsSignIn: needsSignIn,
    );
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

  static int _realNow() => DateTime.now().millisecondsSinceEpoch;

  static String? _noCountry(String? resortId) => null;
}

enum _Drain { done, offline, throttled }

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    repo: ref.watch(daysRepositoryProvider),
    api: ref.watch(syncApiProvider),
    // Read lazily per push: the resort list loads async and the settings may
    // change; neither should rebuild (and dispose) the service.
    countryFor: (resortId) {
      final resort = resortId == null ? null : ref.read(resortRepositoryProvider).asData?.value.byId(resortId);
      return resort?.country ?? ref.read(settingsProvider).countryCode;
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Live [SyncStatus]; `needsSignIn` is what the Konto sheet looks at.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) => ref.watch(syncServiceProvider).status);

/// True while the backend rejects the session — show 'Bitte neu anmelden'.
final syncNeedsSignInProvider = Provider<bool>((ref) => ref.watch(syncStatusProvider).value?.needsSignIn ?? false);

/// Hook for main.dart: syncs on start, on every sign-in, on resume (debounced)
/// and whenever the outbox has work while the app is in the foreground. The
/// profile repair (SYNC-2) rides along: on start, on sign-in and on every
/// tick — a no-op once the row was seen.
void startAutoSync(Ref ref) {
  final service = ref.read(syncServiceProvider);
  final repair = ref.read(profileRepairProvider);

  // A row that was just created or renamed must show up on the Konto page.
  Future<void> repairProfile({String? userId}) async {
    if (!await repair.repairIfMissing(userId: userId) || !ref.mounted) return;
    ref.read(profileServiceProvider).clear();
    ref.invalidate(profileProvider);
  }

  String? lastUserId;
  ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (previous, next) {
    final user = next.value;
    if (user == null) {
      lastUserId = null;
      repair.reset();
      return;
    }
    if (user.id == lastUserId) return;
    lastUserId = user.id;
    unawaited(repairProfile(userId: user.id));
    unawaited(service.syncFresh());
    // Team country → profiles.country_code (migration 0004); fire and forget.
    unawaited(ref.read(profileServiceProvider).pushCountry(ref.read(settingsProvider).countryCode, userId: user.id));
  }, fireImmediately: true);

  unawaited(service.syncFresh());

  final timer = Timer.periodic(const Duration(seconds: 30), (_) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    unawaited(repairProfile());
    // A rate-limited outbox waits its window out instead of knocking every 30 s.
    if (await service.pendingCount() > 0 && !service.isThrottled) unawaited(service.syncNow());
  });
  ref.onDispose(timer.cancel);

  final observer = _ResumeObserver(() => unawaited(service.syncOnResume()));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);
  final void Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// `ref.read(autoSyncProvider)` once in main.dart starts the loop.
final autoSyncProvider = Provider<void>(startAutoSync);
