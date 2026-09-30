import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';

/// Used when Apple hides the name (it is only handed over on first consent)
/// and no cached name is around. Same literal as the server default.
const String kFallbackDisplayName = 'Skifahrer';

/// profiles.display_name is limited to 24 characters server-side (migration
/// 0006, `char_length` = code points); an empty result falls back to
/// [kFallbackDisplayName].
String clipDisplayName(String name) {
  final n = name.trim();
  if (n.isEmpty) return kFallbackDisplayName;
  final runes = n.runes;
  return runes.length <= 24 ? n : String.fromCharCodes(runes.take(24)).trimRight();
}

/// The three `profiles` calls behind [ProfileRepair]; a fake stands in for
/// tests (SYNC-2).
abstract class ProfileRepairApi {
  /// Id of the signed-in user, null when signed out.
  String? get userId;

  /// `display_name` of the own row; null when there is no row at all.
  Future<String?> displayNameOf(String uid);

  /// Creates the row, never overwrites an existing one (on conflict do nothing).
  Future<void> insertProfile(String uid, String displayName);

  /// Rewrites the name of an existing row.
  Future<void> renameProfile(String uid, String displayName);
}

class SupabaseProfileRepairApi implements ProfileRepairApi {
  SupabaseProfileRepairApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<String?> displayNameOf(String uid) async {
    final row = await _client.from('profiles').select('display_name').eq('id', uid).maybeSingle().timeout(timeout);
    if (row == null) return null;
    return (row['display_name'] as String?) ?? '';
  }

  @override
  Future<void> insertProfile(String uid, String displayName) => _client
      .from('profiles')
      .upsert({'id': uid, 'display_name': displayName}, onConflict: 'id', ignoreDuplicates: true)
      .timeout(timeout);

  @override
  Future<void> renameProfile(String uid, String displayName) =>
      _client.from('profiles').update({'display_name': displayName}).eq('id', uid).timeout(timeout);
}

/// Where the Apple full name waits until the profiles row exists. Apple hands
/// the name over exactly once (first consent), so losing it to a failed insert
/// would leave the rider as 'Skifahrer' for good. Kept per user id: a name
/// cached for one Konto must never land on the row of the next one signing in
/// on the same phone.
abstract class AppleNameCache {
  Future<String?> read(String uid);
  Future<void> write(String uid, String name);
  Future<void> clear(String uid);
}

class PrefsAppleNameCache implements AppleNameCache {
  const PrefsAppleNameCache();

  static String keyFor(String uid) => 'profile.appleName.$uid';

  @override
  Future<String?> read(String uid) async {
    try {
      return (await SharedPreferences.getInstance()).getString(keyFor(uid));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String uid, String name) async {
    try {
      await (await SharedPreferences.getInstance()).setString(keyFor(uid), name);
    } catch (_) {
      // best effort — the fallback name is what the server gets then
    }
  }

  @override
  Future<void> clear(String uid) async {
    try {
      await (await SharedPreferences.getInstance()).remove(keyFor(uid));
    } catch (_) {
      // best effort
    }
  }
}

class MemoryAppleNameCache implements AppleNameCache {
  MemoryAppleNameCache([Map<String, String>? names]) : names = {...?names};
  final Map<String, String> names;

  @override
  Future<String?> read(String uid) async => names[uid];

  @override
  Future<void> write(String uid, String name) async => names[uid] = name;

  @override
  Future<void> clear(String uid) async => names.remove(uid);
}

/// Makes sure the signed-in user has a `profiles` row (SYNC-2).
///
/// A row can be missing when the insert on first sign-in failed (offline,
/// timeout, server hiccup); without it nothing social works and the rider is
/// invisible on every board. [repairIfMissing] runs on sign-in, on app start
/// and on every sync tick; after one successful check per user it is a no-op
/// until the next sign-in, so the tick costs nothing.
class ProfileRepair {
  ProfileRepair({required this.api, this.cache = const PrefsAppleNameCache(), this.fallbackName = kFallbackDisplayName});

  /// Null while the backend is unavailable — every call is a no-op.
  final ProfileRepairApi? api;
  final AppleNameCache cache;
  final String fallbackName;

  String? _verifiedFor;
  Future<bool>? _inFlight;

  /// The user id whose row was seen (or created) during this session.
  String? get verifiedFor => _verifiedFor;

  /// Forgets the verified user, e.g. after a sign-out; the next call checks again.
  void reset() => _verifiedFor = null;

  /// After a successful account deletion: nothing of [uid] is kept around.
  Future<void> forget(String uid) async {
    if (_verifiedFor == uid) _verifiedFor = null;
    await cache.clear(uid);
  }

  /// Inserts the row when it is missing, with the cached Apple name (else
  /// [fallbackName]); a success clears the cache. When [appleName] is given
  /// (first sign-in) it is cached first, and a row still carrying the fallback
  /// name is renamed to it. Returns true when a row was written. Never throws.
  ///
  /// Calls without a name collapse into a running one. A call with a name
  /// never does: the auth-state listener usually starts a check a moment
  /// before the sign-in hands the name over, and that name must not be lost.
  Future<bool> repairIfMissing({String? userId, String? appleName}) async {
    final api = this.api;
    if (api == null) return false;
    final uid = userId ?? api.userId;
    if (uid == null) return false;
    final fresh = appleName?.trim();
    final hasFresh = fresh != null && fresh.isNotEmpty;
    if (hasFresh) await cache.write(uid, fresh);
    final running = _inFlight;
    if (running != null) {
      if (!hasFresh) return running;
      await running;
    }
    // The name may still have to reach a row that was already seen.
    if (hasFresh && _verifiedFor == uid) _verifiedFor = null;
    if (_verifiedFor == uid) return false;
    final run = _repair(api, uid);
    _inFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_inFlight, run)) _inFlight = null;
    }
  }

  Future<bool> _repair(ProfileRepairApi api, String uid) async {
    try {
      final existing = await api.displayNameOf(uid);
      final cached = (await cache.read(uid))?.trim();
      final hasCached = cached != null && cached.isNotEmpty;
      var wrote = false;
      if (existing == null) {
        await api.insertProfile(uid, clipDisplayName(hasCached ? cached : fallbackName));
        wrote = true;
      } else if (hasCached && (existing.trim().isEmpty || existing == fallbackName)) {
        await api.renameProfile(uid, clipDisplayName(cached));
        wrote = true;
      }
      // Only now: a failed write keeps the name for the next tick.
      await cache.clear(uid);
      _verifiedFor = uid;
      return wrote;
    } catch (e) {
      // Offline or a server hiccup: the cached name stays, the next tick retries.
      debugPrint('profile repair failed: $e');
      return false;
    }
  }
}

/// One object for the whole app: [AuthService] feeds it on sign-in and
/// `startAutoSync` (sync_service.dart) calls `repairIfMissing()` on app start,
/// on every auth change and on every sync tick.
final profileRepairProvider = Provider<ProfileRepair>((ref) {
  final client = ref.watch(supabaseProvider);
  return ProfileRepair(api: client == null ? null : SupabaseProfileRepairApi(client));
});
