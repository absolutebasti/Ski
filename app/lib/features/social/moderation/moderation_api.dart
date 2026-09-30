import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../../../data/sync/sync_api.dart';
import '../social_models.dart' show parseDisplayName;

/// Why a moderation call could not be carried out.
enum ModerationErrorKind { offline, notSignedIn, failed }

class ModerationError implements Exception {
  const ModerationError(this.kind, [this.detail]);
  final ModerationErrorKind kind;
  final String? detail;

  @override
  String toString() => 'ModerationError(${kind.name}${detail == null ? '' : ', $detail'})';
}

/// The reason chips of the ReportSheet. [wire] is the stable prefix stored in
/// `reports.reason` so the founder can filter reports without parsing copy.
enum ReportReason {
  offensiveName('offensive_name'),
  cheating('cheating'),
  other('other');

  const ReportReason(this.wire);
  final String wire;

  /// `reports.reason` check constraint: 1…200 characters.
  static const int maxReasonLength = 200;

  /// 'cheating: 4.000 hm in 10 Minuten' — trimmed to the column limit.
  String encode(String? details) {
    final d = details?.trim() ?? '';
    final s = d.isEmpty ? wire : '$wire: $d';
    return s.runes.length <= maxReasonLength ? s : String.fromCharCodes(s.runes.take(maxReasonLength));
  }
}

/// One row of the `blocked_riders()` RPC (migration 0015): a rider the
/// signed-in user has blocked, with the name and avatar the unblock list
/// shows. [displayName] / [avatarUrl] are null when the rider has no profile
/// (or a blank name); the page resolves the name via `riderName`.
class BlockedRider {
  const BlockedRider({required this.userId, this.displayName, this.avatarUrl, this.blockedAt});

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;

  /// Null for a row without a `user_id`.
  static BlockedRider? fromRow(Map<String, dynamic> row) {
    final id = row['user_id'];
    if (id is! String || id.isEmpty) return null;
    final avatar = row['avatar_url'];
    final at = row['created_at'];
    return BlockedRider(
      userId: id,
      displayName: parseDisplayName(row['display_name']),
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
      blockedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlockedRider && other.userId == userId && other.displayName == displayName && other.avatarUrl == avatarUrl && other.blockedAt == blockedAt;

  @override
  int get hashCode => Object.hash(userId, displayName, avatarUrl, blockedAt);

  @override
  String toString() => 'BlockedRider($userId, $displayName)';
}

/// Every remote call of Melden / Blockieren, behind an interface so the sheets
/// are testable without Supabase ([FakeModerationApi] in fake_moderation_api.dart).
///
/// Implementations never throw raw Postgrest/network errors — they map to
/// [ModerationError]. While signed out they throw [ModerationErrorKind.notSignedIn]
/// (or return an empty set for [blockedIds]).
abstract class ModerationApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// Insert into `public.reports` (migration 0006). [reason] is 1…200 chars,
  /// see [ReportReason.encode]. Self-reports are rejected server-side.
  Future<void> report({required String targetUserId, required String reason});

  /// Insert into `public.blocks` (migration 0005). Idempotent.
  Future<void> block(String userId);

  /// Delete from `public.blocks`. Idempotent.
  Future<void> unblock(String userId);

  /// Ids the signed-in user has blocked; empty while signed out.
  Future<Set<String>> blockedIds();

  /// The blocked riders with name and avatar, newest block first (RPC
  /// `blocked_riders`, migration 0015 — `rider_profile` hides blocked pairs
  /// and `profiles` is own-row). Empty while signed out.
  Future<List<BlockedRider>> blockedRiders();
}

/// Supabase implementation; 10 s timeout, network failures become
/// [ModerationErrorKind.offline].
class SupabaseModerationApi implements ModerationApi {
  SupabaseModerationApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<void> report({required String targetUserId, required String reason}) => _guard(() async {
        final uid = _requireUser();
        // No `.select()`: the client has no SELECT grant on reports (0006).
        await _client.from('reports').insert({'reporter': uid, 'target_user_id': targetUserId, 'reason': reason});
      });

  @override
  Future<void> block(String userId) => _guard(() async {
        final uid = _requireUser();
        try {
          await _client.from('blocks').insert({'user_id': uid, 'blocked_id': userId});
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow; // already blocked → fine
        }
      });

  @override
  Future<void> unblock(String userId) => _guard(() async {
        final uid = _requireUser();
        await _client.from('blocks').delete().eq('user_id', uid).eq('blocked_id', userId);
      });

  @override
  Future<Set<String>> blockedIds() => _guard(() async {
        final uid = userId;
        if (uid == null) return const <String>{};
        final rows = await _client.from('blocks').select('blocked_id').eq('user_id', uid);
        return {
          for (final r in rows)
            if (r['blocked_id'] is String) r['blocked_id'] as String,
        };
      });

  @override
  Future<List<BlockedRider>> blockedRiders() => _guard(() async {
        if (userId == null) return const <BlockedRider>[];
        final rows = await _client.rpc<dynamic>('blocked_riders');
        if (rows is! List) return const <BlockedRider>[];
        return [
          for (final r in rows)
            if (r is Map) ?BlockedRider.fromRow(Map<String, dynamic>.from(r)),
        ];
      });

  String _requireUser() {
    final uid = userId;
    if (uid == null) throw const ModerationError(ModerationErrorKind.notSignedIn);
    return uid;
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op().timeout(timeout);
    } on ModerationError {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.contains('not_signed_in')) throw const ModerationError(ModerationErrorKind.notSignedIn);
      throw ModerationError(ModerationErrorKind.failed, '$e');
    } catch (e) {
      if (SupabaseSyncApi.isOfflineError(e)) throw ModerationError(ModerationErrorKind.offline, '$e');
      throw ModerationError(ModerationErrorKind.failed, '$e');
    }
  }
}

/// Null while the backend is unavailable — the sheets then show the offline
/// line. Override with a [FakeModerationApi] in tests.
final moderationApiProvider = Provider<ModerationApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseModerationApi(client);
});
