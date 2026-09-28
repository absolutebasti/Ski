import 'moderation_api.dart';

/// In-memory [ModerationApi] for widget tests, previews and the demo mode.
/// Every call is recorded so a test can assert what the sheets asked for.
class FakeModerationApi implements ModerationApi {
  FakeModerationApi({this.userId, Set<String> blocked = const {}, this.failWith}) : blocked = {...blocked};

  @override
  final String? userId;

  /// Current blocks of the signed-in user.
  final Set<String> blocked;

  /// When set, every call throws it.
  ModerationError? failWith;

  /// (targetUserId, reason) in call order.
  final List<(String, String)> reports = [];
  final List<String> blockCalls = [];
  final List<String> unblockCalls = [];
  int blockedIdsCalls = 0;

  void _guard() {
    final f = failWith;
    if (f != null) throw f;
    if (userId == null) throw const ModerationError(ModerationErrorKind.notSignedIn);
  }

  @override
  Future<void> report({required String targetUserId, required String reason}) async {
    _guard();
    reports.add((targetUserId, reason));
  }

  @override
  Future<void> block(String userId) async {
    _guard();
    blockCalls.add(userId);
    blocked.add(userId);
  }

  @override
  Future<void> unblock(String userId) async {
    _guard();
    unblockCalls.add(userId);
    blocked.remove(userId);
  }

  @override
  Future<Set<String>> blockedIds() async {
    blockedIdsCalls++;
    final f = failWith;
    if (f != null) throw f;
    return userId == null ? const {} : {...blocked};
  }
}
