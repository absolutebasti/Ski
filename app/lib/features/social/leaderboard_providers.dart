import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/auth_service.dart';
import 'social_api.dart';
import 'social_models.dart';

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

/// `profiles.share_leaderboards`.
///
/// `null` means "not known" (no backend, signed out, or the call failed) —
/// the screen only shows the opt-in explainer for a hard `false`, so an
/// offline tab never claims the user is opted out.
final shareLeaderboardsProvider = FutureProvider<bool?>((ref) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) return null;
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
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
