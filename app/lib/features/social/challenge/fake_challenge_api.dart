import 'dart:async';

import '../social_api.dart';
import '../social_models.dart';
import 'challenge_api.dart';
import 'challenge_models.dart';

/// In-memory [ChallengeApi] for widget tests, previews and the demo mode.
/// Every call is recorded so a test can assert what the card asked for. There
/// is deliberately no way to record a value — joining records the id only.
class FakeChallengeApi implements ChallengeApi {
  FakeChallengeApi({
    this.userId,
    this.challenges = const [],
    Set<String>? joined,
    Map<String, List<ChallengeBoardEntry>>? boards,
    this.historyRows = const [],
    this.failWith,
    this.gate,
  })  : joined = {...?joined},
        boards = {...?boards};

  @override
  final String? userId;

  /// Rows of `openChallenges`.
  List<Challenge> challenges;

  /// Challenge ids the user is in.
  final Set<String> joined;

  /// Board rows per challenge id; a missing id answers an empty board.
  final Map<String, List<ChallengeBoardEntry>> boards;

  /// Rows answered by `history()`.
  List<ChallengeHistoryEntry> historyRows;

  /// When set, every call throws it — used for the offline state.
  SocialError? failWith;

  /// When set, every call waits for it first — lets a test look at the
  /// loading state before completing the future.
  Completer<void>? gate;

  final List<String> joins = [];
  final List<String> leaves = [];
  final List<String> boardCalls = [];
  int historyCalls = 0;

  Future<void> _guard() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<List<Challenge>> openChallenges() async {
    await _guard();
    return challenges;
  }

  @override
  Future<Set<String>> myChallengeIds() async {
    await _guard();
    return userId == null ? const {} : {...joined};
  }

  @override
  Future<void> join(String challengeId) async {
    await _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    joins.add(challengeId);
    joined.add(challengeId);
  }

  @override
  Future<void> leave(String challengeId) async {
    await _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    leaves.add(challengeId);
    joined.remove(challengeId);
  }

  @override
  Future<List<ChallengeBoardEntry>> board(String challengeId) async {
    await _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    boardCalls.add(challengeId);
    return boards[challengeId] ?? const [];
  }

  @override
  Future<List<ChallengeHistoryEntry>> history({int limit = 20}) async {
    await _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    historyCalls++;
    return historyRows.take(limit).toList();
  }
}
