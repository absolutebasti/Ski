import 'social_api.dart';
import 'social_models.dart';

/// In-memory [SocialApi] for widget tests, previews and the demo mode.
/// Every call is recorded so a test can assert what the screen asked for.
class FakeSocialApi implements SocialApi {
  FakeSocialApi({
    this.userId,
    this.optedIn = true,
    this.entries = const [],
    this.duel,
    this.board = const [],
    this.challenges = const [],
    Map<String, double>? progress,
    this.failWith,
    this.entriesFor,
  }) : progress = {...?progress};

  @override
  final String? userId;

  /// `profiles.share_leaderboards`.
  bool optedIn;

  /// Rows returned for every query unless [entriesFor] answers first.
  List<LeaderboardEntry> entries;

  /// Per-query rows; return null to fall back to [entries].
  final List<LeaderboardEntry>? Function(LeaderboardQuery query)? entriesFor;

  DuelGroup? duel;
  List<GroupMemberStats> board;
  List<Challenge> challenges;
  final Map<String, double> progress;

  /// When set, every call throws it — used for the offline state.
  SocialError? failWith;

  final List<LeaderboardQuery> queries = [];
  final List<String> boardCalls = [];
  final List<String> created = [];
  final List<String> joined = [];
  final List<String> left = [];
  final List<(String, double)> progressWrites = [];

  void _guard() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<bool> shareLeaderboards() async {
    _guard();
    return userId != null && optedIn;
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query) async {
    _guard();
    queries.add(query);
    return entriesFor?.call(query) ?? entries;
  }

  @override
  Future<DuelGroup?> myDuel(DateTime day) async {
    _guard();
    return duel;
  }

  @override
  Future<DuelGroup> createDuel({required String name, required DateTime day, String? resortId}) async {
    _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    created.add(name);
    final group = DuelGroup(
      id: 'group-${created.length}',
      code: 'KMJ4F2',
      name: name,
      day: DateTime(day.year, day.month, day.day),
      resortId: resortId,
      createdBy: userId!,
    );
    duel = group;
    board = [GroupMemberStats(userId: userId!, displayName: 'Du')];
    return group;
  }

  @override
  Future<DuelGroup> joinDuel(String code) async {
    _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    final normalised = SupabaseSocialApi.normaliseCode(code);
    if (!SupabaseSocialApi.isValidCode(normalised)) throw const SocialError(SocialErrorKind.codeNotFound);
    joined.add(normalised);
    final group = duel ??
        DuelGroup(id: 'group-joined', code: normalised, name: 'Tagesduell', day: today(), createdBy: 'other-user');
    duel = group;
    return group;
  }

  @override
  Future<void> leaveDuel(String groupId) async {
    _guard();
    left.add(groupId);
    duel = null;
    board = const [];
  }

  @override
  Future<List<GroupMemberStats>> groupBoard(String groupId) async {
    _guard();
    boardCalls.add(groupId);
    return [...board]..sort(compareDuelMembers);
  }

  @override
  Future<List<Challenge>> openChallenges() async {
    _guard();
    return challenges;
  }

  @override
  Future<Map<String, double>> myProgress() async {
    _guard();
    return {...progress};
  }

  @override
  Future<void> setProgress(String challengeId, double value) async {
    _guard();
    if (userId == null) throw const SocialError(SocialErrorKind.notSignedIn);
    progressWrites.add((challengeId, value));
    progress[challengeId] = value;
  }
}
