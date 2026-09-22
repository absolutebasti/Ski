import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/auth_service.dart';
import 'profile_api.dart';

/// Sentinel for "leave this column untouched" — `null` means "clear it".
class Keep {
  const Keep();
}

const Keep keep = Keep();

/// The `profiles` row as the app sees it.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.homeResortId,
    this.shareLeaderboards = false,
  });

  /// Same default as the server column.
  static const String fallbackName = 'Skifahrer';

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? homeResortId;

  /// Opt-in for Rangliste and Tagesduell; off until the user switches it on.
  final bool shareLeaderboards;

  factory Profile.fromRow(Map<String, Object?> row) => Profile(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? (row['display_name'] as String).trim()
            : fallbackName,
        avatarUrl: row['avatar_url'] as String?,
        homeResortId: row['home_resort_id'] as String?,
        shareLeaderboards: row['share_leaderboards'] as bool? ?? false,
      );

  /// First letter for the avatar circle; '?' when the name is empty.
  String get initial {
    final t = displayName.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }

  Profile copyWith({
    String? displayName,
    Object? avatarUrl = keep,
    Object? homeResortId = keep,
    bool? shareLeaderboards,
  }) =>
      Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl is Keep ? this.avatarUrl : avatarUrl as String?,
        homeResortId: homeResortId is Keep ? this.homeResortId : homeResortId as String?,
        shareLeaderboards: shareLeaderboards ?? this.shareLeaderboards,
      );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.homeResortId == homeResortId &&
      other.shareLeaderboards == shareLeaderboards;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, homeResortId, shareLeaderboards);

  @override
  String toString() => 'Profile($id, $displayName, resort: $homeResortId, share: $shareLeaderboards)';
}

/// Reads and writes the `profiles` row, cached in memory for the session.
///
/// Never throws at the caller: a failed round-trip keeps the local value, so
/// the Konto sheet stays usable offline.
class ProfileService {
  ProfileService({this.api, this.onChanged});

  /// Null while the backend is unavailable — everything stays local.
  final ProfileApi? api;

  /// Called after the cache changed, next to [changes].
  final VoidCallback? onChanged;

  final StreamController<Profile?> _changes = StreamController<Profile?>.broadcast();

  /// Emits after every real local change, so `profileProvider` can re-emit
  /// without depending back on this service.
  Stream<Profile?> get changes => _changes.stream;

  Profile? _cached;

  /// Last known profile without a round-trip; null when signed out.
  Profile? get cached => _cached;

  /// Loads the row of [userId] (or of the signed-in user) once per session.
  Future<Profile?> load({String? userId, String? fallbackName, bool force = false}) async {
    final api = this.api;
    final uid = userId ?? api?.userId;
    if (uid == null) {
      clear();
      return null;
    }
    if (!force && _cached?.id == uid) return _cached;
    if (api == null) return _cached = _placeholder(uid, fallbackName);
    try {
      final row = await api.fetch(uid);
      _cached = row == null ? _placeholder(uid, fallbackName) : Profile.fromRow(row);
    } catch (e) {
      // Offline or a server hiccup — keep what we have, never block the sheet.
      debugPrint('profile load failed: $e');
      if (_cached?.id != uid) _cached = _placeholder(uid, fallbackName);
    }
    return _cached;
  }

  /// Applies the given columns locally first, then pushes them.
  ///
  /// Pass `null` to clear [avatarUrl] / [homeResortId]; omit them to keep them.
  /// Returns the new local value; never throws.
  Future<Profile?> update({
    String? displayName,
    Object? avatarUrl = keep,
    Object? homeResortId = keep,
    bool? shareLeaderboards,
  }) async {
    final api = this.api;
    final uid = _cached?.id ?? api?.userId;
    if (uid == null) return null;

    final name = displayName?.trim();
    final patch = <String, Object?>{
      if (name != null && name.isNotEmpty) 'display_name': name,
      if (avatarUrl is! Keep) 'avatar_url': avatarUrl,
      if (homeResortId is! Keep) 'home_resort_id': homeResortId,
      'share_leaderboards': ?shareLeaderboards,
    };
    if (patch.isEmpty) return _cached;

    final base = _cached ?? Profile(id: uid, displayName: Profile.fallbackName);
    final next = base.copyWith(
      displayName: name != null && name.isNotEmpty ? name : null,
      avatarUrl: avatarUrl,
      homeResortId: homeResortId,
      shareLeaderboards: shareLeaderboards,
    );
    if (next != _cached) {
      _cached = next;
      onChanged?.call();
      if (!_changes.isClosed) _changes.add(next);
    }
    if (api != null) {
      try {
        await api.update(uid, patch);
      } catch (e) {
        // The local value stays; the next load repairs it.
        debugPrint('profile update failed: $e');
      }
    }
    return _cached;
  }

  /// Drops the cache — called on sign out.
  void clear() => _cached = null;

  void dispose() => unawaited(_changes.close());

  Profile _placeholder(String uid, String? fallbackName) {
    final name = fallbackName?.trim();
    return Profile(id: uid, displayName: name == null || name.isEmpty ? Profile.fallbackName : name);
  }
}

/// Explicit types on both providers — inference would otherwise chase the
/// reference from [profileProvider] back into the service.
final Provider<ProfileService> profileServiceProvider = Provider<ProfileService>((ref) {
  final service = ProfileService(api: ref.watch(profileApiProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// The signed-in user's profile; null when signed out. Re-emits whenever the
/// service writes — it listens to [ProfileService.changes] and invalidates
/// itself, so the dependency stays one-directional.
final FutureProvider<Profile?> profileProvider = FutureProvider<Profile?>((ref) async {
  final service = ref.watch(profileServiceProvider);
  final sub = service.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    service.clear();
    return null;
  }
  return service.load(userId: user.id, fallbackName: user.displayName);
});
