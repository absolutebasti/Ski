import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../../../data/sync/sync_api.dart';
import '../social_models.dart';
import 'friends_models.dart';

/// Why a friends call could not be carried out (mirrors [SocialErrorKind]).
enum FriendsErrorKind { offline, notSignedIn, codeNotFound, self, alreadyFriends, requestNotFound, failed }

class FriendsError implements Exception {
  const FriendsError(this.kind, [this.detail]);
  final FriendsErrorKind kind;
  final String? detail;

  @override
  String toString() => 'FriendsError(${kind.name}${detail == null ? '' : ', $detail'})';
}

/// Every remote call of the Freunde module goes through this interface so the
/// sheet and the board can be tested without a Supabase client.
///
/// Implementations never throw raw Postgrest/network errors — they map to
/// [FriendsError]. Calls are safe while signed out: they return an empty
/// result or throw [FriendsErrorKind.notSignedIn].
abstract class FriendsApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// `profiles.friend_code` of the signed-in user; null when signed out or the
  /// profile row does not exist yet.
  Future<String?> myCode();

  /// RPC `friends_list()` — accepted friends and pending requests, both
  /// directions.
  Future<List<Friend>> friends();

  /// RPC `add_friend_by_code(p_code)`. Returns the new pending friend (or the
  /// accepted one when the other side had asked first). Throws
  /// [FriendsErrorKind.codeNotFound], [FriendsErrorKind.self],
  /// [FriendsErrorKind.alreadyFriends].
  Future<Friend> addFriendByCode(String code);

  /// RPC `accept_friend(p_user_id)`. Throws [FriendsErrorKind.requestNotFound].
  Future<void> acceptFriend(String userId);

  /// RPC `remove_friend(p_user_id)` — unfriend, decline or withdraw. Idempotent.
  Future<void> removeFriend(String userId);

  /// RPC `friends_board(p_season_key, p_metric)` — the leaderboard row shape
  /// over accepted friends + self, ranked by [LeaderboardQuery.metric].
  Future<List<LeaderboardEntry>> board(LeaderboardQuery query);
}

/// Supabase implementation. 10 s timeout per call; network failures become
/// [FriendsErrorKind.offline].
class SupabaseFriendsApi implements FriendsApi {
  SupabaseFriendsApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<String?> myCode() => _guard(() async {
        final uid = userId;
        if (uid == null) return null;
        final row = await _client.from('profiles').select('friend_code').eq('id', uid).maybeSingle();
        final code = (row?['friend_code'] as String?)?.trim();
        return code == null || code.isEmpty ? null : code;
      });

  @override
  Future<List<Friend>> friends() => _guard(() async {
        if (userId == null) return const <Friend>[];
        final rows = await _client.rpc<dynamic>('friends_list');
        return _rows(rows).map(Friend.fromJson).toList();
      });

  @override
  Future<Friend> addFriendByCode(String code) => _guard(() async {
        _requireUser();
        final normalised = FriendCode.normalise(code);
        if (!FriendCode.isValid(normalised)) throw const FriendsError(FriendsErrorKind.codeNotFound);
        final raw = await _client.rpc<dynamic>('add_friend_by_code', params: {'p_code': normalised});
        final rows = _rows(raw);
        if (rows.isEmpty) throw const FriendsError(FriendsErrorKind.codeNotFound);
        return Friend.fromJson(rows.first);
      });

  @override
  Future<void> acceptFriend(String userId) => _guard(() async {
        _requireUser();
        await _client.rpc<dynamic>('accept_friend', params: {'p_user_id': userId});
      });

  @override
  Future<void> removeFriend(String userId) => _guard(() async {
        _requireUser();
        await _client.rpc<dynamic>('remove_friend', params: {'p_user_id': userId});
      });

  @override
  Future<List<LeaderboardEntry>> board(LeaderboardQuery query) => _guard(() async {
        _requireUser();
        final rows = await _client.rpc<dynamic>('friends_board', params: {
          'p_season_key': query.wireKey,
          'p_metric': query.metric.wire,
        });
        return _rows(rows).map(LeaderboardEntry.fromJson).toList();
      });

  String _requireUser() {
    final uid = userId;
    if (uid == null) throw const FriendsError(FriendsErrorKind.notSignedIn);
    return uid;
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op().timeout(timeout);
    } on FriendsError {
      rethrow;
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Postgrest messages of the 0007 RPCs → [FriendsError]; anything
  /// network-shaped → offline.
  static FriendsError mapError(Object e) {
    if (e is FriendsError) return e;
    if (e is PostgrestException) {
      final m = e.message;
      if (m.contains('code_not_found')) return const FriendsError(FriendsErrorKind.codeNotFound);
      if (m.contains('already_friends')) return const FriendsError(FriendsErrorKind.alreadyFriends);
      if (m.contains('request_not_found')) return const FriendsError(FriendsErrorKind.requestNotFound);
      if (m.contains('not_signed_in')) return const FriendsError(FriendsErrorKind.notSignedIn);
      if (RegExp(r'(^|\W)self(\W|$)').hasMatch(m)) return const FriendsError(FriendsErrorKind.self);
      return FriendsError(FriendsErrorKind.failed, m);
    }
    if (SupabaseSyncApi.isOfflineError(e)) return FriendsError(FriendsErrorKind.offline, '$e');
    return FriendsError(FriendsErrorKind.failed, '$e');
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, Object?>.from(r),
    ];
  }
}

/// Null while the backend is unavailable — the sheet then shows its offline
/// line and the friends board its offline state.
final friendsApiProvider = Provider<FriendsApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseFriendsApi(client);
});
