import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/sync/auth_service.dart';
import '../social_api.dart' show noRetry;
import '../social_models.dart';
import 'friends_api.dart';
import 'friends_models.dart';

/// All friendship rows of the signed-in user (RPC `friends_list`).
///
/// Empty without a backend or signed out; a failed call throws [FriendsError]
/// once (no background retry — the sheet offers 'Erneut versuchen').
final friendshipsProvider = FutureProvider<List<Friend>>((ref) async {
  final api = ref.watch(friendsApiProvider);
  if (api == null) throw const FriendsError(FriendsErrorKind.offline);
  // Refetch after a sign-in / sign-out; empty while signed out.
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null && api.userId == null) return const <Friend>[];
  return api.friends();
}, retry: noRetry);

/// Accepted friends, name order.
final friendsProvider = Provider<AsyncValue<List<Friend>>>((ref) {
  return ref.watch(friendshipsProvider).whenData(
        (rows) => rows.where((f) => f.isAccepted).toList()..sort((a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase())),
      );
});

/// Requests waiting for the user's answer (pending, sent by the other side).
final pendingRequestsProvider = Provider<AsyncValue<List<Friend>>>((ref) {
  return ref.watch(friendshipsProvider).whenData((rows) => rows.where((f) => f.isIncomingRequest).toList());
});

/// Number of incoming requests waiting for an answer — the badge on the
/// Freunde chip (SOC-RANGLISTE-2). 0 while loading, offline or signed out.
final pendingRequestCountProvider = Provider<int>((ref) => ref.watch(pendingRequestsProvider).asData?.value.length ?? 0);

/// Requests the user sent that are not answered yet.
final sentRequestsProvider = Provider<AsyncValue<List<Friend>>>((ref) {
  return ref.watch(friendshipsProvider).whenData((rows) => rows.where((f) => f.isOutgoingRequest).toList());
});

/// The user's own friend code; null while signed out, offline or without a
/// profile row.
final myFriendCodeProvider = FutureProvider<String?>((ref) async {
  final api = ref.watch(friendsApiProvider);
  if (api == null) return null;
  ref.watch(authStateProvider);
  try {
    return await api.myCode();
  } on FriendsError {
    return null;
  }
}, retry: noRetry);

/// Freunde-Rangliste for one query (RPC `friends_board`): accepted friends +
/// self in the leaderboard row shape. Only [LeaderboardQuery.wireKey] and
/// [LeaderboardQuery.metric] go over the wire; resort and country are ignored.
///
/// Throws [FriendsError] — SOC-RANGLISTE renders offline/empty from it.
final friendsBoardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardQuery>((ref, query) async {
  final api = ref.watch(friendsApiProvider);
  if (api == null) throw const FriendsError(FriendsErrorKind.offline);
  ref.watch(authStateProvider);
  return api.board(query);
}, retry: noRetry);

/// Hands the invite text to the system share sheet. Overridden in tests so
/// the 'Teilen' button can be asserted without share_plus.
typedef ShareText = Future<void> Function(String text, {String? subject});

final friendsShareProvider = Provider<ShareText>(
  (ref) => (text, {subject}) async => SharePlus.instance.share(ShareParams(text: text, subject: subject)),
);

/// Drops every cached friends result — after add / accept / remove.
/// (Providers with a plain [Ref] invalidate the two providers directly.)
void invalidateFriends(WidgetRef ref) {
  ref.invalidate(friendshipsProvider);
  ref.invalidate(friendsBoardProvider);
}
