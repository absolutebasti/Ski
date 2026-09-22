import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'social_api.dart';
import 'social_models.dart';

/// The Tagesduell of today the user is a member of — null when there is none.
final myDuelProvider = FutureProvider<DuelGroup?>((ref) async {
  final api = ref.watch(socialApiProvider);
  if (api == null || api.userId == null) return null;
  return api.myDuel(today());
}, retry: noRetry);

/// Live board of one duel (RPC `group_board`), sorted by Höhenmeter.
final groupBoardProvider = FutureProvider.family<List<GroupMemberStats>, String>((ref, groupId) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  return api.groupBoard(groupId);
}, retry: noRetry);

/// How often the duel board is refetched while the tab is visible.
/// Override with `null` in widget tests so no timer outlives the test.
final duelPollIntervalProvider = Provider<Duration?>((ref) => const Duration(seconds: 60));
