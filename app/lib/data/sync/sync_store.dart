import 'package:shared_preferences/shared_preferences.dart';

/// Where the sync bookkeeping lives. Abstracted so the sync loop is testable
/// without plugins.
///
/// The pull cursor is kept per user (`sync.lastSyncAt.<uid>`), so switching
/// Konten on one device never skips rows of the other account.
abstract class SyncStore {
  /// ms epoch of the newest `updated_at` pulled for [uid], null = never.
  Future<int?> lastSyncAt(String uid);
  Future<void> setLastSyncAt(String uid, int ms);

  /// The uid the outbox was last drained for; null when nobody has synced yet.
  Future<String?> lastUserId();
  Future<void> setLastUserId(String? uid);

  /// Explicit confirm flag: when true, outbox entries queued under a previous
  /// Konto are pushed under the next one. Default false — the days stay local.
  Future<bool> migrateOutboxOnUserChange();
  Future<void> setMigrateOutboxOnUserChange(bool value);
}

class PrefsSyncStore implements SyncStore {
  const PrefsSyncStore();

  /// Pre-hardening single-device cursor; no longer read.
  static const String legacyKey = 'sync.lastSyncAt';
  static const String userKey = 'sync.lastUserId';
  static const String migrateKey = 'sync.migrateOutbox';

  static String cursorKey(String uid) => 'sync.lastSyncAt.$uid';

  @override
  Future<int?> lastSyncAt(String uid) async {
    try {
      return (await SharedPreferences.getInstance()).getInt(cursorKey(uid));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLastSyncAt(String uid, int ms) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(cursorKey(uid), ms);
    } catch (_) {
      // best effort — a lost cursor only means we pull a bit more next time
    }
  }

  @override
  Future<String?> lastUserId() async {
    try {
      return (await SharedPreferences.getInstance()).getString(userKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLastUserId(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid == null) {
        await prefs.remove(userKey);
      } else {
        await prefs.setString(userKey, uid);
      }
    } catch (_) {
      // best effort
    }
  }

  @override
  Future<bool> migrateOutboxOnUserChange() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(migrateKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setMigrateOutboxOnUserChange(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(migrateKey, value);
    } catch (_) {
      // best effort
    }
  }
}

class MemorySyncStore implements SyncStore {
  MemorySyncStore({Map<String, int>? cursors, String? lastUserId, bool migrateOutbox = false}) : _cursors = {...?cursors} {
    _lastUserId = lastUserId;
    _migrate = migrateOutbox;
  }

  final Map<String, int> _cursors;
  String? _lastUserId;
  bool _migrate = false;

  Map<String, int> get cursors => Map.unmodifiable(_cursors);

  @override
  Future<int?> lastSyncAt(String uid) async => _cursors[uid];

  @override
  Future<void> setLastSyncAt(String uid, int ms) async => _cursors[uid] = ms;

  @override
  Future<String?> lastUserId() async => _lastUserId;

  @override
  Future<void> setLastUserId(String? uid) async => _lastUserId = uid;

  @override
  Future<bool> migrateOutboxOnUserChange() async => _migrate;

  @override
  Future<void> setMigrateOutboxOnUserChange(bool value) async => _migrate = value;
}
