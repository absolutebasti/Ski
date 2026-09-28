import 'dart:async';

import '../social_api.dart';
import '../social_models.dart';
import 'duel_api.dart';
import 'duel_models.dart';

/// In-memory [DuelApi] for widget tests, previews and the demo mode. Every
/// call is recorded so a test can assert what the card / uploader asked for.
class FakeDuelApi implements DuelApi {
  FakeDuelApi({
    this.userId,
    this.duel,
    this.board = const [],
    this.duels = const [],
    this.failWith,
    this.gate,
    this.code = 'KMJ4F2',
  });

  @override
  final String? userId;

  /// Answer of `myDuel`; set by `createDuel` / `joinDuel`, cleared by `leaveDuel`.
  DuelGroup? duel;

  /// Rows of `groupBoard`, returned sorted by Höhenmeter.
  List<DuelMember> board;

  /// Rows of `myDuels`, newest first.
  List<DuelSummary> duels;

  /// When set, every call throws it — used for the offline state.
  SocialError? failWith;

  /// When set, every call waits for it first — lets a test look at the
  /// loading state before completing the future.
  Completer<void>? gate;

  /// Code handed out by `createDuel`.
  String code;

  /// Names handed to `createDuel`.
  final List<String> created = [];

  /// Time zones handed to `createDuel`, parallel to [created].
  final List<String> createdTz = [];
  final List<String> joined = [];
  final List<String> left = [];
  final List<String> boardCalls = [];

  /// Every `upsertLive` payload in order.
  final List<LiveDayPayload> liveWrites = [];
  int myDuelsCalls = 0;

  Future<void> _guard() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
  }

  String _requireUser() {
    final uid = userId;
    if (uid == null) throw const SocialError(SocialErrorKind.notSignedIn);
    return uid;
  }

  @override
  Future<DuelGroup?> myDuel(DateTime day) async {
    await _guard();
    return duel;
  }

  @override
  Future<DuelGroup> createDuel({required String name, required DateTime day, required String tz, String? resortId}) async {
    await _guard();
    final uid = _requireUser();
    created.add(name);
    createdTz.add(tz);
    final group = DuelGroup(
      id: 'group-${created.length}',
      code: code,
      name: name,
      day: DateTime(day.year, day.month, day.day),
      resortId: resortId,
      createdBy: uid,
    );
    duel = group;
    board = [DuelMember(userId: uid, displayName: 'Du')];
    return group;
  }

  @override
  Future<DuelGroup> joinDuel(String code) async {
    await _guard();
    _requireUser();
    final normalised = SupabaseSocialApi.normaliseCode(code);
    if (!SupabaseSocialApi.isValidCode(normalised)) throw const SocialError(SocialErrorKind.codeNotFound);
    joined.add(normalised);
    final group = duel ?? DuelGroup(id: 'group-joined', code: normalised, name: 'Tagesduell', day: today(), createdBy: 'other-user');
    duel = group;
    return group;
  }

  @override
  Future<void> leaveDuel(String groupId) async {
    await _guard();
    left.add(groupId);
    duel = null;
    board = const [];
  }

  @override
  Future<List<DuelMember>> groupBoard(String groupId) async {
    await _guard();
    boardCalls.add(groupId);
    return [...board]..sort(compareDuelMembers);
  }

  @override
  Future<void> upsertLive(LiveDayPayload payload) async {
    await _guard();
    _requireUser();
    liveWrites.add(payload);
  }

  @override
  Future<List<DuelSummary>> myDuels({int limit = 20}) async {
    await _guard();
    if (userId == null) return const [];
    myDuelsCalls++;
    return duels.take(limit).toList();
  }
}
