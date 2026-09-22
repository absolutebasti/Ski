import 'package:dropline/core/core.dart';
import 'package:dropline/data/sync/auth_service.dart';
import 'package:dropline/features/social/fake_social_api.dart';
import 'package:dropline/features/social/social.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

const kUser = AuthUser(id: 'u1', displayName: 'Sebastian Fackelmann');

const kResorts = [
  Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 12),
  Resort(id: 'ischgl', name: 'Ischgl', country: 'AT', lat: 47.01, lon: 10.29, radiusKm: 10),
];

/// 2026-01-15 09:00 — season 2025/26, month 2026-01, ISO week 2026-W03.
final DateTime kNow = DateTime(2026, 1, 15, 9);
final int kTs = kNow.millisecondsSinceEpoch;

/// Five rows; 'u1' sits on rank 4 so the podium and the pinned own row both
/// have something to show.
const kEntries = [
  LeaderboardEntry(rank: 1, userId: 'u9', displayName: 'Lena Bergmann', value: 24100),
  LeaderboardEntry(rank: 2, userId: 'u8', displayName: 'Paul Moser', value: 19800),
  LeaderboardEntry(rank: 3, userId: 'u7', displayName: 'Nina Aigner', value: 17400),
  LeaderboardEntry(rank: 4, userId: 'u1', displayName: 'Sebastian Fackelmann', value: 12480),
  LeaderboardEntry(rank: 5, userId: 'u6', displayName: 'Tom Huber', value: 9100),
];

DuelGroup duelGroup({String id = 'g1', String code = 'KMJ4F2'}) =>
    DuelGroup(id: id, code: code, name: 'Tagesduell', day: DateTime(2026, 1, 15), createdBy: 'u1');

const kBoard = [
  GroupMemberStats(userId: 'u2', displayName: 'Paul Moser', runCount: 11, dropM: 2410, maxSpeedMs: 19.4),
  GroupMemberStats(userId: 'u1', displayName: 'Sebastian Fackelmann', runCount: 9, dropM: 1804, maxSpeedMs: 17),
];

Challenge weeklyChallenge({double target = 10000, SocialMetric metric = SocialMetric.dropM}) => Challenge(
      id: 'c1',
      title: '10.000 hm in einer Woche',
      metric: metric,
      target: target,
      startsOn: DateTime(2026, 1, 12),
      endsOn: DateTime(2026, 1, 18),
    );

DaySummary daySummary({String id = 'd1', int? startedAt, double dropM = 1804, int runCount = 7, double skiDistanceM = 22000}) =>
    DaySummary(
      id: id,
      startedAt: startedAt ?? kTs,
      endedAt: (startedAt ?? kTs) + 5 * 3600 * 1000,
      resortName: 'Kitzbühel',
      stats: DayStats(runCount: runCount, dropM: dropM, skiDistanceM: skiDistanceM, maxSpeedMs: 17),
    );

/// Overrides on top of `screenOverrides()` — never touches Supabase.
/// [poll] defaults to null so no duel timer outlives a widget test.
List<Override> socialOverrides({FakeSocialApi? api, AuthUser? user, Duration? poll}) => [
      socialApiProvider.overrideWithValue(api),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      duelPollIntervalProvider.overrideWithValue(poll),
    ];
