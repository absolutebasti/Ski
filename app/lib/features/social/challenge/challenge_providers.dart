import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/sync/auth_service.dart';
import '../social_api.dart';
import '../social_models.dart';
import 'challenge_api.dart';
import 'challenge_models.dart';

/// Challenges whose window has not ended yet, earliest end first.
///
/// Source is the [ChallengeApi] (rows carry both titles). Without one — no
/// backend, or a test that only wires a FakeSocialApi — the legacy
/// `SocialApi.openChallenges()` answers, so the social screen keeps rendering
/// the card in both setups.
final openChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final api = ref.watch(challengeApiProvider);
  if (api != null) return api.openChallenges();
  final social = ref.watch(socialApiProvider);
  return social == null ? const <Challenge>[] : social.openChallenges();
}, retry: noRetry);

/// Ids of the challenges the signed-in user joined — empty while signed out or
/// without a backend. Refetches after a sign-in / sign-out.
final myChallengeIdsProvider = FutureProvider<Set<String>>((ref) async {
  final api = ref.watch(challengeApiProvider);
  if (api == null) return const <String>{};
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null && api.userId == null) return const <String>{};
  return api.myChallengeIds();
}, retry: noRetry);

/// Board of one challenge (RPC `challenge_board`): participants ranked, with
/// the window counts on every row. Throws [SocialError]; the card hides the
/// counts, the sheet renders offline / error from it. autoDispose: a board
/// changes with every synced day, so each opening fetches fresh.
final challengeBoardProvider = FutureProvider.autoDispose.family<List<ChallengeBoardEntry>, String>((ref, challengeId) async {
  final api = ref.watch(challengeApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  ref.watch(authStateProvider);
  return api.board(challengeId);
}, retry: noRetry);

/// Ended challenges the signed-in user joined, newest first (RPC
/// `my_challenge_history`). Empty while signed out or without a backend.
final challengeHistoryProvider = FutureProvider<List<ChallengeHistoryEntry>>((ref) async {
  final api = ref.watch(challengeApiProvider);
  if (api == null) return const <ChallengeHistoryEntry>[];
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null && api.userId == null) return const <ChallengeHistoryEntry>[];
  return api.history();
}, retry: noRetry);

/// Drops every cached challenge result — after join / leave.
void invalidateChallenges(WidgetRef ref) {
  ref.invalidate(myChallengeIdsProvider);
  ref.invalidate(challengeBoardProvider);
  ref.invalidate(challengeHistoryProvider);
}

/// The challenge the card shows: running today, soonest deadline.
Challenge? currentChallenge(List<Challenge> open, DateTime now) {
  final ms = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final running = open.where((c) => c.containsMs(ms)).toList()..sort((a, b) => a.windowEndMs.compareTo(b.windowEndMs));
  return running.firstOrNull ?? (open.toList()..sort((a, b) => a.windowStartMs.compareTo(b.windowStartMs))).firstOrNull;
}

/// Own progress computed locally from the finished days inside the window —
/// works offline and needs no server round trip. The server computes the same
/// figure from the synced days for the board (private.challenge_values).
double localProgress(List<DaySummary> days, Challenge c) {
  var sum = 0.0;
  for (final d in days) {
    if (!c.containsMs(d.startedAt)) continue;
    sum += switch (c.metric) {
      SocialMetric.dropM => d.stats.dropM,
      SocialMetric.runCount => d.stats.runCount.toDouble(),
      SocialMetric.skiDistanceM => d.stats.skiDistanceM,
      SocialMetric.dayCount => 1,
      SocialMetric.maxSpeedMs => 0,
      SocialMetric.points => dayPointsOf(dropM: d.stats.dropM, skiDistanceM: d.stats.skiDistanceM, runCount: d.stats.runCount),
    };
    if (c.metric == SocialMetric.maxSpeedMs) sum = sum < d.stats.maxSpeedMs ? d.stats.maxSpeedMs : sum;
  }
  return sum;
}
