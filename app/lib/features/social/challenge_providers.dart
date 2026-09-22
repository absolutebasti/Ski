import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import 'social_api.dart';
import 'social_models.dart';

/// Challenges whose window has not ended yet, earliest end first.
final openChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final api = ref.watch(socialApiProvider);
  if (api == null) return const <Challenge>[];
  return api.openChallenges();
}, retry: noRetry);

/// Own `challenge_progress` values by challenge id — empty while signed out.
final challengeProgressProvider = FutureProvider<Map<String, double>>((ref) async {
  final api = ref.watch(socialApiProvider);
  if (api == null || api.userId == null) return const <String, double>{};
  return api.myProgress();
}, retry: noRetry);

/// The challenge the card shows: running today, soonest deadline.
Challenge? currentChallenge(List<Challenge> open, DateTime now) {
  final ms = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final running = open.where((c) => c.containsMs(ms)).toList()..sort((a, b) => a.windowEndMs.compareTo(b.windowEndMs));
  return running.firstOrNull ?? (open.toList()..sort((a, b) => a.windowStartMs.compareTo(b.windowStartMs))).firstOrNull;
}

/// Own progress computed locally from the finished days inside the window —
/// works offline and needs no server round trip.
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
    };
    if (c.metric == SocialMetric.maxSpeedMs) sum = sum < d.stats.maxSpeedMs ? d.stats.maxSpeedMs : sum;
  }
  return sum;
}
