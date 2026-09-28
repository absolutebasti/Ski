import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../data/sync/auth_service.dart';
import '../friends/friends_api.dart';
import '../friends/friends_providers.dart';
import '../group_providers.dart';
import '../leaderboard_providers.dart';
import '../social_api.dart' show noRetry;
import 'moderation_api.dart';

/// Ids the signed-in user has blocked (`public.blocks`). Empty without a
/// backend, signed out or when the call fails — the set only decides whether a
/// profile shows 'Blockiert'; the boards exclude blocked riders server-side.
final blockedIdsProvider = FutureProvider<Set<String>>((ref) async {
  final api = ref.watch(moderationApiProvider);
  if (api == null) return const {};
  ref.watch(authStateProvider);
  try {
    return await api.blockedIds();
  } on ModerationError {
    return const {};
  }
}, retry: noRetry);

/// Providers dropped after a block / unblock so every board refetches without
/// the blocked rider. Leaderboard, duel board and friends are here; a later
/// package appends its own (e.g. `myRankProvider` from SOC-RANGLISTE):
///
///   blockRefreshTargetsProvider.overrideWith((ref) => [...kBlockRefreshTargets, myRankProvider])
final blockRefreshTargetsProvider = Provider<List<ProviderOrFamily>>((ref) => kBlockRefreshTargets);

/// Default refresh set of [blockRefreshTargetsProvider].
final List<ProviderOrFamily> kBlockRefreshTargets = [leaderboardProvider, groupBoardProvider, friendshipsProvider, friendsBoardProvider];

/// Melden / Blockieren with the follow-up work the UI must never forget:
/// a block also ends the friendship client-side (friends_board does not
/// filter blocks yet) and refreshes every board.
class ModerationService {
  ModerationService(this._ref);
  final Ref _ref;

  ModerationApi _api() {
    final api = _ref.read(moderationApiProvider);
    if (api == null) throw const ModerationError(ModerationErrorKind.offline);
    return api;
  }

  /// Insert into `reports`; [reason] via [ReportReason.encode].
  Future<void> report({required String targetUserId, required String reason}) => _api().report(targetUserId: targetUserId, reason: reason);

  /// Block [userId], remove the friendship (errors there are ignored — the
  /// block is what matters) and refresh the boards.
  Future<void> block(String userId) async {
    await _api().block(userId);
    final friends = _ref.read(friendsApiProvider);
    if (friends != null) {
      try {
        await friends.removeFriend(userId);
      } on FriendsError {
        // Not friends / offline — the server hides the rider anyway.
      }
    }
    refresh();
  }

  Future<void> unblock(String userId) async {
    await _api().unblock(userId);
    refresh();
  }

  /// Drop [blockedIdsProvider] and every [blockRefreshTargetsProvider] entry.
  void refresh() {
    _ref.invalidate(blockedIdsProvider);
    for (final p in _ref.read(blockRefreshTargetsProvider)) {
      _ref.invalidate(p);
    }
  }
}

final moderationServiceProvider = Provider<ModerationService>(ModerationService.new);
