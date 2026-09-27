import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
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
    this.countryCode,
  });

  /// Same default as the server column.
  static const String fallbackName = 'Skifahrer';

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? homeResortId;

  /// Opt-in for Rangliste and Tagesduell; off until the user switches it on.
  final bool shareLeaderboards;

  /// Team country (ISO-3166 alpha-2, upper case) — mirrors
  /// `Settings.countryCode` on the server (migration 0004). Null = not set.
  final String? countryCode;

  factory Profile.fromRow(Map<String, Object?> row) => Profile(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? (row['display_name'] as String).trim()
            : fallbackName,
        avatarUrl: row['avatar_url'] as String?,
        homeResortId: row['home_resort_id'] as String?,
        shareLeaderboards: row['share_leaderboards'] as bool? ?? false,
        countryCode: normaliseCountry(row['country_code'] as String?),
      );

  /// Upper-case alpha-2 or null; anything else would trip the server check.
  static String? normaliseCountry(String? code) {
    final c = code?.trim().toUpperCase();
    return c == null || c.length != 2 ? null : c;
  }

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
    Object? countryCode = keep,
  }) =>
      Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl is Keep ? this.avatarUrl : avatarUrl as String?,
        homeResortId: homeResortId is Keep ? this.homeResortId : homeResortId as String?,
        shareLeaderboards: shareLeaderboards ?? this.shareLeaderboards,
        countryCode: countryCode is Keep ? this.countryCode : normaliseCountry(countryCode as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.homeResortId == homeResortId &&
      other.shareLeaderboards == shareLeaderboards &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, homeResortId, shareLeaderboards, countryCode);

  @override
  String toString() => 'Profile($id, $displayName, resort: $homeResortId, share: $shareLeaderboards, country: $countryCode)';
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
  /// Pass `null` to clear [avatarUrl] / [homeResortId] / [countryCode]; omit
  /// them to keep them. Returns the new local value; never throws.
  Future<Profile?> update({
    String? displayName,
    Object? avatarUrl = keep,
    Object? homeResortId = keep,
    bool? shareLeaderboards,
    Object? countryCode = keep,
    String? userId,
  }) async {
    final api = this.api;
    final uid = _cached?.id ?? userId ?? api?.userId;
    if (uid == null) return null;

    final name = displayName?.trim();
    final country = countryCode is Keep ? keep : Profile.normaliseCountry(countryCode as String?);
    final patch = <String, Object?>{
      if (name != null && name.isNotEmpty) 'display_name': name,
      if (avatarUrl is! Keep) 'avatar_url': avatarUrl,
      if (homeResortId is! Keep) 'home_resort_id': homeResortId,
      'share_leaderboards': ?shareLeaderboards,
      if (country is! Keep) 'country_code': country,
    };
    if (patch.isEmpty) return _cached;

    final base = _cached ?? Profile(id: uid, displayName: Profile.fallbackName);
    final next = base.copyWith(
      displayName: name != null && name.isNotEmpty ? name : null,
      avatarUrl: avatarUrl,
      homeResortId: homeResortId,
      shareLeaderboards: shareLeaderboards,
      countryCode: country,
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

  /// Mirrors the team country onto `profiles.country_code` when it differs
  /// from what the server has (or from the cache). No-op without a code, an
  /// api or a user; never throws. Called on sign-in from the sync loop and
  /// from [profileProvider] whenever the setting changes.
  Future<void> pushCountry(String? code, {String? userId}) async {
    final country = Profile.normaliseCountry(code);
    final api = this.api;
    if (country == null || api == null) return;
    final uid = userId ?? _cached?.id ?? api.userId;
    if (uid == null) return;
    if (_cached?.id != uid) await load(userId: uid);
    if (_cached?.countryCode == country) return;
    await update(countryCode: country, userId: uid);
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
  final profile = await service.load(userId: user.id, fallbackName: user.displayName);
  // Team country follows the setting (onboarding v3); a mismatch is pushed
  // once — update() emits on [ProfileService.changes], which re-runs this
  // provider with the codes now equal.
  final country = Profile.normaliseCountry(ref.watch(settingsProvider.select((s) => s.countryCode)));
  if (country != null && profile != null && profile.countryCode != country) {
    return service.update(countryCode: country, userId: user.id);
  }
  return profile;
});
