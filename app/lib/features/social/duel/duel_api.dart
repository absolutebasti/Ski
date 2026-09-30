import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../social_api.dart';
import '../social_models.dart';
import 'duel_models.dart';

/// Every remote call of the Tagesduell goes through this interface so the
/// card, the uploader, the history and the Tagesbilanz card can be tested
/// without Supabase ([FakeDuelApi] in fake_duel_api.dart).
///
/// Failures are [SocialError]s. Calls are safe while signed out: they return
/// an empty result or throw [SocialErrorKind.notSignedIn].
abstract class DuelApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// True when the backend behind this api knows in-app invites (the 0017
  /// RPCs). False only for [SocialApiDuelAdapter]; 'Herausfordern' then
  /// falls back to sharing the duel code.
  bool get supportsInvites;

  /// The duel of [day] the user is a member of, null when there is none.
  Future<DuelGroup?> myDuel(DateTime day);

  /// RPC `create_duel(p_name, p_day, p_tz, p_resort_id)` (migration 0014):
  /// group + creator membership in one transaction, code generated
  /// server-side. [tz] is the creator's IANA zone — the server matches days
  /// by that zone's local date. [resortId] is informational only
  /// (group_board has no resort filter since 0009).
  Future<DuelGroup> createDuel({required String name, required DateTime day, required String tz, String? resortId});

  /// RPC `join_group(p_code)`. Throws [SocialErrorKind.codeNotFound],
  /// [SocialErrorKind.duelFull] or [SocialErrorKind.duelExpired].
  Future<DuelGroup> joinDuel(String code);

  Future<void> leaveDuel(String groupId);

  /// RPC `group_board(p_group_id)` — every member, Höhenmeter desc, live rows
  /// flagged. Throws [SocialErrorKind.notAMember].
  Future<List<DuelMember>> groupBoard(String groupId);

  /// Upserts the own `live_days` row. Idempotent; the server stamps
  /// `updated_at`.
  Future<void> upsertLive(LiveDayPayload payload);

  /// RPC `my_duels(p_limit)` — the caller's duels, newest day first, each
  /// with its board.
  Future<List<DuelSummary>> myDuels({int limit = 20});

  /// RPC `invite_to_duel(p_user_id, p_group_id)` (migration 0017): invites
  /// [userId] into the caller's duel [groupId]; a pending invite of the pair
  /// is returned as is. Throws [SocialErrorKind.notAMember] (caller not in
  /// the group), [SocialErrorKind.riderNotFound] (unknown / blocked),
  /// [SocialErrorKind.alreadyMember], [SocialErrorKind.duelFull],
  /// [SocialErrorKind.duelExpired], [SocialErrorKind.rateLimited].
  Future<DuelInvite> inviteToDuel({required String userId, required String groupId});

  /// RPC `respond_duel_invite(p_id, p_accept)`. Accept joins the duel and
  /// returns it (throws [SocialErrorKind.duelFull] / [SocialErrorKind.duelExpired]
  /// and leaves the invite pending); decline returns null. An invite that is
  /// no longer pending throws [SocialErrorKind.riderNotFound] with the detail
  /// [inviteNotFound].
  Future<DuelGroup?> respondInvite(String inviteId, {required bool accept});

  /// RPC `my_duel_invites()` — pending invites addressed to the caller for
  /// duels that are not over, newest first. Empty while signed out.
  Future<List<DuelInvite>> myInvites();
}

/// [SocialError.detail] of an invite that is no longer pending (answered,
/// withdrawn with the duel, or not addressed to the caller).
const String inviteNotFound = 'invite_not_found';

/// Runs [op]; when it fails with a unique violation (23505 — two riders drew
/// the same six-character code) it runs [op] once more with a fresh code.
/// Anything else, and a second collision, propagate. Since 0014 the code is
/// generated server-side (`create_duel`); kept for callers that still insert
/// codes themselves.
Future<T> retryOnceOnCodeCollision<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on PostgrestException catch (e) {
    if (e.code != '23505') rethrow;
    return await op();
  }
}

/// Supabase implementation. 10 s timeout per call; network failures become
/// [SocialErrorKind.offline]; Postgrest messages map like [SupabaseSocialApi].
class SupabaseDuelApi implements DuelApi {
  SupabaseDuelApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get supportsInvites => true;

  @override
  Future<DuelGroup?> myDuel(DateTime day) => _guard(() async {
        final uid = userId;
        if (uid == null) return null;
        final rows = await _client
            .from('group_members')
            .select('group_id, groups!inner(id, code, name, day, resort_id, created_by, max_members, tz)')
            .eq('user_id', uid)
            .eq('groups.day', formatDate(day));
        for (final row in _rows(rows)) {
          final group = row['groups'];
          if (group is! Map) continue;
          final parsed = DuelGroup.fromJson(Map<String, Object?>.from(group));
          if (parsed.day == DateTime(day.year, day.month, day.day)) return parsed;
        }
        return null;
      });

  @override
  Future<DuelGroup> createDuel({required String name, required DateTime day, required String tz, String? resortId}) => _guard(() async {
        _requireUser();
        final raw = await _client.rpc<dynamic>('create_duel', params: {
          'p_name': name,
          'p_day': formatDate(day),
          'p_tz': tz,
          'p_resort_id': resortId,
        });
        final rows = _rows(raw);
        if (rows.isEmpty) throw const SocialError(SocialErrorKind.failed, 'create_duel returned no row');
        return DuelGroup.fromJson(rows.first);
      });

  @override
  Future<DuelGroup> joinDuel(String code) => _guard(() async {
        _requireUser();
        final normalised = SupabaseSocialApi.normaliseCode(code);
        if (!SupabaseSocialApi.isValidCode(normalised)) throw const SocialError(SocialErrorKind.codeNotFound);
        final raw = await _client.rpc<dynamic>('join_group', params: {'p_code': normalised});
        final rows = _rows(raw);
        if (rows.isEmpty) throw const SocialError(SocialErrorKind.codeNotFound);
        return DuelGroup.fromJson(rows.first);
      });

  @override
  Future<void> leaveDuel(String groupId) => _guard(() async {
        final uid = _requireUser();
        await _client.from('group_members').delete().eq('group_id', groupId).eq('user_id', uid);
      });

  @override
  Future<List<DuelMember>> groupBoard(String groupId) => _guard(() async {
        final rows = await _client.rpc<dynamic>('group_board', params: {'p_group_id': groupId});
        return _rows(rows).map(DuelMember.fromJson).toList()..sort(compareDuelMembers);
      });

  @override
  Future<void> upsertLive(LiveDayPayload payload) => _guard(() async {
        final uid = _requireUser();
        await _client.from('live_days').upsert({'user_id': uid, ...payload.toJson()}, onConflict: 'user_id');
      });

  @override
  Future<List<DuelSummary>> myDuels({int limit = 20}) => _guard(() async {
        if (userId == null) return const <DuelSummary>[];
        final rows = await _client.rpc<dynamic>('my_duels', params: {'p_limit': limit});
        return _rows(rows).map(DuelSummary.fromJson).toList();
      });

  @override
  Future<DuelInvite> inviteToDuel({required String userId, required String groupId}) => _guard(() async {
        _requireUser();
        final raw = await _client.rpc<dynamic>('invite_to_duel', params: {'p_user_id': userId, 'p_group_id': groupId});
        final rows = _rows(raw);
        if (rows.isEmpty) throw const SocialError(SocialErrorKind.failed, 'invite_to_duel returned no row');
        // The RPC returns the bare duel_invites row (no names, no group
        // columns) — callers only need to know it went out.
        final row = rows.first;
        final from = (row['from_user'] as String?) ?? '';
        return DuelInvite(
          id: (row['id'] as String?) ?? '',
          fromUserId: from,
          fromName: '',
          group: DuelGroup(id: groupId, code: '', name: '', day: parseDate(row['day']) ?? today(), createdBy: from),
        );
      });

  @override
  Future<DuelGroup?> respondInvite(String inviteId, {required bool accept}) => _guard(() async {
        _requireUser();
        final raw = await _client.rpc<dynamic>('respond_duel_invite', params: {'p_id': inviteId, 'p_accept': accept});
        final rows = _rows(raw);
        if (!accept) return null;
        if (rows.isEmpty) throw const SocialError(SocialErrorKind.failed, 'respond_duel_invite returned no row');
        return DuelGroup.fromJson(rows.first);
      });

  @override
  Future<List<DuelInvite>> myInvites() => _guard(() async {
        if (userId == null) return const <DuelInvite>[];
        final rows = await _client.rpc<dynamic>('my_duel_invites');
        return _rows(rows).map(DuelInvite.fromJson).toList();
      });

  /// The 0017 messages [SupabaseSocialApi.mapError] does not know, then the
  /// shared mapping.
  static SocialError mapError(Object e) {
    if (e is PostgrestException) {
      final m = e.message;
      if (m.contains('already_member')) return const SocialError(SocialErrorKind.alreadyMember);
      if (m.contains(inviteNotFound)) return const SocialError(SocialErrorKind.riderNotFound, inviteNotFound);
    }
    return SupabaseSocialApi.mapError(e);
  }

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

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map) Map<String, Object?>.from(r),
    ];
  }
}

/// [DuelApi] on top of a [SocialApi] — no live rows, no history. Keeps every
/// existing test and preview that only wires a `FakeSocialApi` working; the
/// real app always has the Supabase implementation.
class SocialApiDuelAdapter implements DuelApi {
  const SocialApiDuelAdapter(this._social);
  final SocialApi _social;

  @override
  String? get userId => _social.userId;

  @override
  bool get supportsInvites => false;

  @override
  Future<DuelGroup?> myDuel(DateTime day) => _social.myDuel(day);

  @override
  Future<DuelGroup> createDuel({required String name, required DateTime day, required String tz, String? resortId}) =>
      _social.createDuel(name: name, day: day, resortId: resortId);

  @override
  Future<DuelGroup> joinDuel(String code) => _social.joinDuel(code);

  @override
  Future<void> leaveDuel(String groupId) => _social.leaveDuel(groupId);

  @override
  Future<List<DuelMember>> groupBoard(String groupId) async => (await _social.groupBoard(groupId)).map(DuelMember.from).toList();

  @override
  Future<void> upsertLive(LiveDayPayload payload) async {}

  @override
  Future<List<DuelSummary>> myDuels({int limit = 20}) async => const [];

  // Invites exist only in the 0017 RPCs — the adapter has no backend for them.
  @override
  Future<DuelInvite> inviteToDuel({required String userId, required String groupId}) async =>
      throw const SocialError(SocialErrorKind.failed, 'duel invites need the Supabase DuelApi');

  @override
  Future<DuelGroup?> respondInvite(String inviteId, {required bool accept}) async =>
      throw const SocialError(SocialErrorKind.failed, 'duel invites need the Supabase DuelApi');

  @override
  Future<List<DuelInvite>> myInvites() async => const [];
}

/// Null while the backend is unavailable — the card then shows its offline
/// toast, the uploader stays idle. Falls back to the [SocialApi] adapter when
/// only that one is wired (tests). Override with a [FakeDuelApi] in tests.
final duelApiProvider = Provider<DuelApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client != null) return SupabaseDuelApi(client);
  final social = ref.watch(socialApiProvider);
  return social == null ? null : SocialApiDuelAdapter(social);
});
