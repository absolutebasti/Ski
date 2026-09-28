import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../../../data/sync/sync_api.dart';
import '../social_api.dart';
import '../social_models.dart';
import 'challenge_models.dart';

/// Detail of the [SocialError] thrown when joining a challenge whose window
/// has closed (the insert policy of 0010 rejects it with 42501).
const String kChallengeEnded = 'challenge_ended';

/// Every remote call of the Wochen-Challenge goes through this interface so
/// the card, the board sheet and the history can be tested without Supabase
/// ([FakeChallengeApi] in fake_challenge_api.dart).
///
/// Failures are [SocialError]s — the vocabulary the Social tab already speaks.
/// Calls are safe while signed out: they return an empty result or throw
/// [SocialErrorKind.notSignedIn]. There is no way to send a value: progress is
/// computed by the server from the synced days (migration 0010).
abstract class ChallengeApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// `challenges` whose `ends_on` is today or later, earliest end first. Rows
  /// are [WeeklyChallenge]s (both title columns).
  Future<List<Challenge>> openChallenges();

  /// Ids of the challenges the signed-in user joined (`challenge_participants`).
  Future<Set<String>> myChallengeIds();

  /// Inserts the own participant row — nothing else. Idempotent (joining twice
  /// is fine). Throws [SocialErrorKind.failed] with detail [kChallengeEnded]
  /// when the window has closed.
  Future<void> join(String challengeId);

  /// Deletes the own participant row. Idempotent.
  Future<void> leave(String challengeId);

  /// RPC `challenge_board(p_challenge_id)` — every participant ranked, riders
  /// blocked by the caller hidden, window counts on each row.
  Future<List<ChallengeBoardEntry>> board(String challengeId);

  /// RPC `my_challenge_history(p_limit)` — ended challenges the caller joined,
  /// newest first.
  Future<List<ChallengeHistoryEntry>> history({int limit = 20});
}

/// Supabase implementation. 10 s timeout per call; network failures become
/// [SocialErrorKind.offline].
class SupabaseChallengeApi implements ChallengeApi {
  SupabaseChallengeApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<List<Challenge>> openChallenges() => _guard(() async {
        final rows = await _client.from('challenges').select().gte('ends_on', formatDate(today())).order('ends_on');
        return _rows(rows).map(WeeklyChallenge.fromJson).toList();
      });

  @override
  Future<Set<String>> myChallengeIds() => _guard(() async {
        final uid = userId;
        if (uid == null) return const <String>{};
        final rows = await _client.from('challenge_participants').select('challenge_id').eq('user_id', uid);
        return {
          for (final r in _rows(rows))
            if (r['challenge_id'] is String) r['challenge_id'] as String,
        };
      });

  @override
  Future<void> join(String challengeId) => _guard(() async {
        final uid = _requireUser();
        try {
          // Only these two columns are insertable (column-level grant, 0010).
          await _client.from('challenge_participants').insert({'challenge_id': challengeId, 'user_id': uid});
        } on PostgrestException catch (e) {
          if (e.code == '23505') return; // already in
          if (e.code == '42501') throw const SocialError(SocialErrorKind.failed, kChallengeEnded);
          rethrow;
        }
      });

  @override
  Future<void> leave(String challengeId) => _guard(() async {
        final uid = _requireUser();
        await _client.from('challenge_participants').delete().eq('challenge_id', challengeId).eq('user_id', uid);
      });

  @override
  Future<List<ChallengeBoardEntry>> board(String challengeId) => _guard(() async {
        _requireUser();
        final rows = await _client.rpc<dynamic>('challenge_board', params: {'p_challenge_id': challengeId});
        return _rows(rows).map(ChallengeBoardEntry.fromJson).toList();
      });

  @override
  Future<List<ChallengeHistoryEntry>> history({int limit = 20}) => _guard(() async {
        _requireUser();
        final rows = await _client.rpc<dynamic>('my_challenge_history', params: {'p_limit': limit});
        return _rows(rows).map(ChallengeHistoryEntry.fromJson).toList();
      });

  String _requireUser() {
    final uid = userId;
    if (uid == null) throw const SocialError(SocialErrorKind.notSignedIn);
    return uid;
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op().timeout(timeout);
    } on SocialError {
      rethrow;
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Postgrest errors of the 0010 RPCs → [SocialError]; network-shaped → offline.
  static SocialError mapError(Object e) {
    if (e is SocialError) return e;
    if (e is PostgrestException) {
      if (e.code == '42501' || e.message.contains('not_signed_in')) return const SocialError(SocialErrorKind.notSignedIn);
      if (e.code == 'P0002' || e.message.contains('challenge_not_found')) return const SocialError(SocialErrorKind.failed, 'challenge_not_found');
      return SocialError(SocialErrorKind.failed, e.message);
    }
    if (SupabaseSyncApi.isOfflineError(e)) return SocialError(SocialErrorKind.offline, '$e');
    return SocialError(SocialErrorKind.failed, '$e');
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, Object?>.from(r),
    ];
  }
}

/// Null while the backend is unavailable — the card then hides the counts and
/// 'Mitmachen' answers with the offline toast. Override with a
/// [FakeChallengeApi] in tests.
final challengeApiProvider = Provider<ChallengeApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseChallengeApi(client);
});
