import 'package:shared_preferences/shared_preferences.dart';

/// Where the sync cursor lives. Abstracted so the sync loop is testable
/// without plugins.
abstract class SyncStore {
  Future<int?> lastSyncAt();
  Future<void> setLastSyncAt(int ms);
}

class PrefsSyncStore implements SyncStore {
  const PrefsSyncStore();

  static const String key = 'sync.lastSyncAt';

  @override
  Future<int?> lastSyncAt() async {
    try {
      return (await SharedPreferences.getInstance()).getInt(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLastSyncAt(int ms) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(key, ms);
    } catch (_) {
      // best effort — a lost cursor only means we pull a bit more next time
    }
  }
}

class MemorySyncStore implements SyncStore {
  MemorySyncStore([this._value]);
  int? _value;

  @override
  Future<int?> lastSyncAt() async => _value;

  @override
  Future<void> setLastSyncAt(int ms) async => _value = ms;
}
