import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:slopetrack/features/social/social.dart';

/// The running challenge as 0010 delivers it: both title columns filled, the
/// legacy `title` = title_de. Window 12.–18. Jan 2026 (kNow = 15. Jan).
WeeklyChallenge weekly({
  String id = 'c1',
  SocialMetric metric = SocialMetric.dropM,
  double target = 5000,
  String? titleDe = 'Wochen-Challenge: 5.000 Höhenmeter',
  String? titleEn = 'Weekly challenge: 5,000 m vertical',
  DateTime? startsOn,
  DateTime? endsOn,
}) =>
    WeeklyChallenge(
      id: id,
      title: titleDe ?? '',
      metric: metric,
      target: target,
      startsOn: startsOn ?? DateTime(2026, 1, 12),
      endsOn: endsOn ?? DateTime(2026, 1, 18),
      titleDe: titleDe,
      titleEn: titleEn,
    );

/// An ended challenge (5.–11. Jan) with 20 runs as the target.
WeeklyChallenge endedWeekly({String id = 'c0'}) => weekly(
      id: id,
      metric: SocialMetric.runCount,
      target: 20,
      titleDe: 'Wochen-Challenge: 20 Abfahrten',
      titleEn: 'Weekly challenge: 20 runs',
      startsOn: DateTime(2026, 1, 5),
      endsOn: DateTime(2026, 1, 11),
    );

/// The board of `weekly()`: Lena done, u1 (own) at 4.000, Tom at 0 — window
/// counts 3 dabei · 1 geschafft on every row, as the RPC sends them.
const kChallengeBoard = [
  ChallengeBoardEntry(rank: 1, userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT', value: 6200, done: true, participants: 3, doneCount: 1),
  ChallengeBoardEntry(rank: 2, userId: 'u1', displayName: 'Sebastian Fackelmann', countryCode: 'AT', value: 4000, participants: 3, doneCount: 1),
  ChallengeBoardEntry(rank: 3, userId: 'u6', displayName: 'Tom Huber', countryCode: 'DE', value: 0, participants: 3, doneCount: 1),
];

/// Two ended challenges: one made (rank 2 of 12), one missed (rank 5 of 8).
final kChallengeHistory = [
  ChallengeHistoryEntry(challenge: endedWeekly(id: 'c0'), value: 23, done: true, rank: 2, participants: 12, doneCount: 4),
  ChallengeHistoryEntry(
    challenge: weekly(
      id: 'c-1',
      titleDe: 'Wochen-Challenge: 3 Skitage',
      titleEn: 'Weekly challenge: 3 ski days',
      metric: SocialMetric.dayCount,
      target: 3,
      startsOn: DateTime(2025, 12, 29),
      endsOn: DateTime(2026, 1, 4),
    ),
    value: 1,
    done: false,
    rank: 5,
    participants: 8,
    doneCount: 2,
  ),
];

/// Override for the challenge API alone; combine with socialOverrides() for
/// the auth state and screenOverrides() for the local days.
List<Override> challengeOverrides(ChallengeApi? api) => [challengeApiProvider.overrideWithValue(api)];
