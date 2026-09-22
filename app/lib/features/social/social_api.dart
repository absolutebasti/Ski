import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_client.dart';
import '../../data/sync/sync_api.dart';
import 'social_models.dart';

/// Why a social call could not be carried out. Everything the UI has to say
/// something about gets its own kind; the rest lands in [SocialErrorKind.failed].
enum SocialErrorKind { offline, notSignedIn, codeNotFound, duelFull, alreadyMember, failed }

class SocialError implements Exception {
  const SocialError(this.kind, [this.detail]);
  final SocialErrorKind kind;
  final String? detail;

  @override
  String toString() => 'SocialError(${kind.name}${detail == null ? '' : ', $detail'})';
}

/// Every remote call of the Social tab goes through this interface, so the
/// screen can be tested without a Supabase client.
///
/// Implementations never throw raw Postgrest/network errors — they map to
/// [SocialError]. All of them are safe to call while signed out: they either
/// return an empty result or throw [SocialErrorKind.notSignedIn].
abstract class SocialApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// `profiles.share_leaderboards` of the signed-in user; false when signed out.
  Future<bool> shareLeaderboards();

  /// RPC `leaderboard(p_resort_id, p_season_key, p_metric, p_limit)`.
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query);

  /// The duel of [day] the user is a member of, null when there is none.
  Future<DuelGroup?> myDuel(DateTime day);

  /// Creates a group with a fresh code and joins it.
  Future<DuelGroup> createDuel({required String name, required DateTime day, String? resortId});

  /// Joins the group with [code]. Throws [SocialErrorKind.codeNotFound] or
  /// [SocialErrorKind.duelFull].
  Future<DuelGroup> joinDuel(String code);

  Future<void> leaveDuel(String groupId);

  /// RPC `group_board(p_group_id)`.
  Future<List<GroupMemberStats>> groupBoard(String groupId);

  /// Challenges whose `ends_on` is today or later.
  Future<List<Challenge>> openChallenges();

  /// Own `challenge_progress` values by challenge id.
  Future<Map<String, double>> myProgress();

  /// Inserts or updates the own progress row (also used to join a challenge).
  Future<void> setProgress(String challengeId, double value);
}

/// Supabase implementation. Every call has a 10 s timeout; network failures
/// become [SocialErrorKind.offline] so the UI can show an offline state
/// instead of an error.
class SupabaseSocialApi implements SocialApi {
  SupabaseSocialApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  /// No 0/O/1/I/L — a code has to survive being read out on a chairlift.
  static const String codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int codeLength = 6;
  static const int maxMembers = 3;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<bool> shareLeaderboards() => _guard(() async {
        final uid = userId;
        if (uid == null) return false;
        final row = await _client.from('profiles').select('share_leaderboards').eq('id', uid).maybeSingle();
        return (row?['share_leaderboards'] as bool?) ?? false;
      });

  @override
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query) => _guard(() async {
        final rows = await _client.rpc<dynamic>('leaderboard', params: {
          'p_resort_id': query.resortId,
          'p_season_key': query.wireKey,
          'p_metric': query.metric.wire,
          'p_limit': query.limit,
        });
        return _rows(rows).map(LeaderboardEntry.fromJson).toList();
      });

  @override
  Future<DuelGroup?> myDuel(DateTime day) => _guard(() async {
        final uid = userId;
        if (uid == null) return null;
        final rows = await _client
            .from('group_members')
            .select('group_id, groups!inner(id, code, name, day, resort_id, created_by, max_members)')
            .eq('user_id', uid);
        for (final row in _rows(rows)) {
          final group = row['groups'];
          if (group is! Map) continue;
          final parsed = DuelGroup.fromJson(Map<String, Object?>.from(group));
          if (parsed.day == DateTime(day.year, day.month, day.day)) return parsed;
        }
        return null;
      });

  @override
  Future<DuelGroup> createDuel({required String name, required DateTime day, String? resortId}) => _guard(() async {
        final uid = _requireUser();
        final row = await _client
            .from('groups')
            .insert({
              'code': newCode(),
              'name': name,
              'day': formatDate(day),
              'resort_id': resortId,
              'created_by': uid,
              'max_members': maxMembers,
            })
            .select()
            .single();
        final group = DuelGroup.fromJson(Map<String, Object?>.from(row));
        await _client.from('group_members').insert({'group_id': group.id, 'user_id': uid});
        return group;
      });

  @override
  Future<DuelGroup> joinDuel(String code) => _guard(() async {
        final uid = _requireUser();
        final normalised = normaliseCode(code);
        if (!isValidCode(normalised)) throw const SocialError(SocialErrorKind.codeNotFound);
        // TODO(WP-16): `groups` is only readable by members or the creator, so
        // this select returns null for everyone who was invited. Joining needs a
        // security-definer RPC `join_group(p_code text)` — see the report.
        final row = await _client.from('groups').select().eq('code', normalised).maybeSingle();
        if (row == null) throw const SocialError(SocialErrorKind.codeNotFound);
        final group = DuelGroup.fromJson(Map<String, Object?>.from(row));
        final members = _rows(await _client.from('group_members').select('user_id').eq('group_id', group.id));
        if (members.any((m) => m['user_id'] == uid)) return group;
        // Client-side cap only; the server has no check yet (see the report).
        if (members.length >= group.maxMembers) throw const SocialError(SocialErrorKind.duelFull);
        await _client.from('group_members').insert({'group_id': group.id, 'user_id': uid});
        return group;
      });

  @override
  Future<void> leaveDuel(String groupId) => _guard(() async {
        final uid = _requireUser();
        await _client.from('group_members').delete().eq('group_id', groupId).eq('user_id', uid);
      });

  @override
  Future<List<GroupMemberStats>> groupBoard(String groupId) => _guard(() async {
        final rows = await _client.rpc<dynamic>('group_board', params: {'p_group_id': groupId});
        return _rows(rows).map(GroupMemberStats.fromJson).toList()..sort(compareDuelMembers);
      });

  @override
  Future<List<Challenge>> openChallenges() => _guard(() async {
        final rows = await _client.from('challenges').select().gte('ends_on', formatDate(today())).order('ends_on');
        return _rows(rows).map(Challenge.fromJson).toList();
      });

  @override
  Future<Map<String, double>> myProgress() => _guard(() async {
        final uid = userId;
        if (uid == null) return const <String, double>{};
        final rows = await _client.from('challenge_progress').select('challenge_id, value').eq('user_id', uid);
        return {
          for (final r in _rows(rows))
            if (r['challenge_id'] is String) r['challenge_id'] as String: ((r['value'] as num?) ?? 0).toDouble(),
        };
      });

  @override
  Future<void> setProgress(String challengeId, double value) => _guard(() async {
        final uid = _requireUser();
        await _client.from('challenge_progress').upsert({
          'challenge_id': challengeId,
          'user_id': uid,
          'value': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'challenge_id,user_id');
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
      if (SupabaseSyncApi.isOfflineError(e)) throw SocialError(SocialErrorKind.offline, '$e');
      throw SocialError(SocialErrorKind.failed, '$e');
    }
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, Object?>.from(r),
    ];
  }

  /// Uppercase, spaces and dashes stripped. No character folding: the
  /// alphabet already leaves out every ambiguous glyph (0/O/1/I/L), so a code
  /// that still contains one was mistyped and must not be silently rewritten.
  static String normaliseCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Six characters, all from [codeAlphabet].
  static bool isValidCode(String code) =>
      code.length == codeLength && code.split('').every(codeAlphabet.contains);

  static String newCode([Random? random]) {
    final r = random ?? Random.secure();
    return String.fromCharCodes(
      List<int>.generate(codeLength, (_) => codeAlphabet.codeUnitAt(r.nextInt(codeAlphabet.length))),
    );
  }
}

/// Riverpod 3 retries a failed provider on its own; the Rangliste does not
/// want that (a dead connection on a chairlift would poll in the background).
/// Every social provider fails once, shows the offline state and waits for the
/// user's 'Erneut versuchen'.
Duration? noRetry(int retryCount, Object error) => null;

/// Null while the backend is unavailable — the Social tab then shows its
/// signed-out explainer and nothing else.
final socialApiProvider = Provider<SocialApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseSocialApi(client);
});
