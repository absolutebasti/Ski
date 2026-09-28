import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/widgets/toast.dart';
import '../../data/sync/auth_service.dart';
import '../account/profile_service.dart';
import 'friends/friends_api.dart';
import 'friends/friends_providers.dart';
import 'social_api.dart';
import 'social_models.dart';
import 'social_strings.dart';

/// Gebiets-Rangliste for one query (RPC `leaderboard`).
///
/// Throws a [SocialError]; the screen renders offline/empty from it and never
/// blocks on the network — without a backend the tab shows its signed-out face.
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardQuery>((ref, query) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  // Refetch after a sign-in / sign-out.
  ref.watch(authStateProvider);
  return api.leaderboard(query);
}, retry: noRetry);

/// The board the screen shows for [query]: the Freunde-Rangliste when
/// [LeaderboardQuery.friends] is set (SOC-FRIENDS' `friendsBoardProvider`,
/// its [FriendsError] translated), otherwise [leaderboardProvider].
final boardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardQuery>((ref, query) async {
  if (!query.friends) return ref.watch(leaderboardProvider(query).future);
  try {
    return await ref.watch(friendsBoardProvider(query).future);
  } on FriendsError catch (e) {
    throw socialErrorOf(e);
  }
}, retry: noRetry);

/// [FriendsError] → [SocialError] so one copy table serves both boards.
SocialError socialErrorOf(Object e) {
  if (e is SocialError) return e;
  if (e is FriendsError) {
    return switch (e.kind) {
      FriendsErrorKind.offline => SocialError(SocialErrorKind.offline, e.detail),
      FriendsErrorKind.notSignedIn => const SocialError(SocialErrorKind.notSignedIn),
      FriendsErrorKind.codeNotFound => const SocialError(SocialErrorKind.codeNotFound),
      FriendsErrorKind.alreadyFriends || FriendsErrorKind.self => const SocialError(SocialErrorKind.alreadyFriends),
      FriendsErrorKind.requestNotFound => const SocialError(SocialErrorKind.riderNotFound),
      FriendsErrorKind.failed => SocialError(SocialErrorKind.failed, e.detail),
    };
  }
  return SocialError(SocialErrorKind.failed, '$e');
}

/// The caller's own place on the board of [query] — RPC `my_rank` (the whole
/// ranked set, migration 0005), or, for the Freunde-Rangliste, the own row of
/// `friends_board` (self is always in it). Null = not ranked.
final myRankProvider = FutureProvider.family<MyRank?, LeaderboardQuery>((ref, query) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  ref.watch(authStateProvider);
  if (query.friends) {
    final entries = await ref.watch(boardProvider(query).future);
    return myRankOf(entries, ref.watch(socialUserIdProvider));
  }
  return api.myRank(query);
}, retry: noRetry);

/// Länder-Wertung for one season/month/week key (RPC `country_board`).
/// Same failure contract as [leaderboardProvider].
final countryBoardProvider = FutureProvider.family<List<CountryEntry>, String>((ref, seasonKey) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  ref.watch(authStateProvider);
  return api.countryBoard(seasonKey);
}, retry: noRetry);

/// `profiles.share_leaderboards`.
///
/// `null` means "not known" (no backend, signed out, or the call failed) —
/// the screen only shows the opt-in explainer for a hard `false`, so an
/// offline tab never claims the user is opted out.
///
/// Local-first: when the Konto's [ProfileService] already holds the user's
/// row with the opt-in set (the inline 'Rangliste freischalten' writes it
/// there first), that wins without a round-trip.
final shareLeaderboardsProvider = FutureProvider<bool?>((ref) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) return null;
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final cached = ref.watch(profileServiceProvider).cached;
  if (cached != null && cached.id == user.id && cached.shareLeaderboards) return true;
  try {
    return await api.shareLeaderboards();
  } on SocialError {
    return null;
  }
}, retry: noRetry);

/// Id of the signed-in Konto, null when signed out.
final socialUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return user?.id ?? ref.watch(socialApiProvider)?.userId;
});

/// Drops every cached board — after a sync finished pushing days, on tab
/// re-entry after a while, on pull-to-refresh and on 'Erneut versuchen'.
void refreshBoards(WidgetRef ref) {
  ref.invalidate(leaderboardProvider);
  ref.invalidate(friendsBoardProvider);
  ref.invalidate(boardProvider);
  ref.invalidate(myRankProvider);
  ref.invalidate(countryBoardProvider);
  ref.invalidate(shareLeaderboardsProvider);
}

/// Switches `profiles.share_leaderboards` on from the explainer — the Konto
/// sheet stays the place to switch it off. Local first (never throws), then
/// every board is refetched.
Future<void> optIntoLeaderboards(WidgetRef ref, {String? userId}) async {
  await ref.read(profileServiceProvider).update(shareLeaderboards: true, userId: userId);
  refreshBoards(ref);
}

/// 'Freund hinzufügen' on a rider's profile — RPC `add_friend_by_id`
/// (migration 0013) via [SocialApi]; the result lands in a toast and the
/// friends providers refetch. Default handler of `riderActionsProvider`.
Future<void> addFriendFromRider(Ref ref, BuildContext context, String userId) async {
  final s = SocialStrings.of(context);
  final api = ref.read(socialApiProvider);
  if (api == null) {
    showToast(context, s.error(SocialErrorKind.offline));
    return;
  }
  if (api.userId == null) {
    showToast(context, s.signInFirst);
    return;
  }
  try {
    final accepted = await api.addFriendById(userId);
    ref.invalidate(friendshipsProvider);
    ref.invalidate(friendsBoardProvider);
    ref.invalidate(boardProvider);
    ref.invalidate(myRankProvider);
    if (context.mounted) showToast(context, accepted ? s.nowFriends : s.friendRequestSent);
  } on SocialError catch (e) {
    if (context.mounted) showToast(context, s.error(e.kind));
  }
}
