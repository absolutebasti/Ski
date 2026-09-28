import '../social_models.dart';
import 'friends_api.dart';
import 'friends_models.dart';

/// In-memory [FriendsApi] for widget tests, previews and the demo mode.
/// Every call is recorded so a test can assert what the sheet asked for.
class FakeFriendsApi implements FriendsApi {
  FakeFriendsApi({
    this.userId,
    this.code = 'KMJ4F2',
    List<Friend> friends = const [],
    this.entries = const [],
    this.failWith,
    Map<String, Friend>? byCode,
  })  : friendships = [...friends],
        byCode = {...?byCode};

  @override
  final String? userId;

  /// Own friend code; null = profile row not there yet.
  String? code;

  /// Every friendship row, both directions.
  final List<Friend> friendships;

  /// Rows of `friends_board` for every query.
  List<LeaderboardEntry> entries;

  /// Codes `addFriendByCode` resolves; unknown codes → codeNotFound.
  final Map<String, Friend> byCode;

  /// When set, every call throws it — used for the offline state.
  FriendsError? failWith;

  final List<String> added = [];
  final List<String> accepted = [];
  final List<String> removed = [];
  final List<LeaderboardQuery> boardQueries = [];
  int listCalls = 0;

  void _guard() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<String?> myCode() async {
    _guard();
    return userId == null ? null : code;
  }

  @override
  Future<List<Friend>> friends() async {
    _guard();
    listCalls++;
    return userId == null ? const [] : [...friendships];
  }

  @override
  Future<Friend> addFriendByCode(String code) async {
    _guard();
    if (userId == null) throw const FriendsError(FriendsErrorKind.notSignedIn);
    final normalised = FriendCode.normalise(code);
    if (!FriendCode.isValid(normalised)) throw const FriendsError(FriendsErrorKind.codeNotFound);
    added.add(normalised);
    if (normalised == this.code) throw const FriendsError(FriendsErrorKind.self);
    final target = byCode[normalised];
    if (target == null) throw const FriendsError(FriendsErrorKind.codeNotFound);
    final i = friendships.indexWhere((f) => f.userId == target.userId);
    if (i >= 0) {
      final existing = friendships[i];
      if (existing.isIncomingRequest) {
        final acceptedRow = existing.copyWith(status: FriendshipStatus.accepted);
        friendships[i] = acceptedRow;
        return acceptedRow;
      }
      throw const FriendsError(FriendsErrorKind.alreadyFriends);
    }
    final pending = target.copyWith(status: FriendshipStatus.pending, incoming: false);
    friendships.add(pending);
    return pending;
  }

  @override
  Future<void> acceptFriend(String userId) async {
    _guard();
    if (this.userId == null) throw const FriendsError(FriendsErrorKind.notSignedIn);
    accepted.add(userId);
    final i = friendships.indexWhere((f) => f.userId == userId && f.isIncomingRequest);
    if (i < 0) throw const FriendsError(FriendsErrorKind.requestNotFound);
    friendships[i] = friendships[i].copyWith(status: FriendshipStatus.accepted);
  }

  @override
  Future<void> removeFriend(String userId) async {
    _guard();
    if (this.userId == null) throw const FriendsError(FriendsErrorKind.notSignedIn);
    removed.add(userId);
    friendships.removeWhere((f) => f.userId == userId);
  }

  @override
  Future<List<LeaderboardEntry>> board(LeaderboardQuery query) async {
    _guard();
    if (userId == null) throw const FriendsError(FriendsErrorKind.notSignedIn);
    boardQueries.add(query);
    return entries;
  }
}
