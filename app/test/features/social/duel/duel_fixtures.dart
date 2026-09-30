import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../social_fixtures.dart';

/// 2026-01-15 09:00 — the clock every duel test renders against.
final DateTime kDuelNow = kNow;
final int kTwoMinutesAgo = kDuelNow.millisecondsSinceEpoch - 2 * 60000;

/// Two members: Paul finished (2.410 hm), 'u1' still on the slope (1.804 hm,
/// written two minutes before [kDuelNow]).
final List<DuelMember> kLiveBoard = [
  const DuelMember(userId: 'u2', displayName: 'Paul Moser', runCount: 11, dropM: 2410, maxSpeedMs: 19.4),
  DuelMember(userId: 'u1', displayName: 'Sebastian Fackelmann', runCount: 9, dropM: 1804, maxSpeedMs: 17, isLive: true, updatedAtMs: kTwoMinutesAgo),
];

/// Two finished members: Paul 2.410 hm, 'u1' 1.804 hm.
const List<DuelMember> kTwoBoard = [
  DuelMember(userId: 'u2', displayName: 'Paul Moser', runCount: 11, dropM: 2410, maxSpeedMs: 19.4),
  DuelMember(userId: 'u1', displayName: 'Sebastian Fackelmann', runCount: 9, dropM: 1804, maxSpeedMs: 17),
];

/// The board of a finished duel: Paul first, 'u1' second, Anna third.
const List<DuelMember> kFinalBoard = [
  DuelMember(userId: 'u2', displayName: 'Paul Moser', runCount: 12, dropM: 2210, maxSpeedMs: 19.4),
  DuelMember(userId: 'u1', displayName: 'Sebastian Fackelmann', runCount: 11, dropM: 1849, maxSpeedMs: 17.2),
  DuelMember(userId: 'u3', displayName: 'Anna', runCount: 9, dropM: 1520, maxSpeedMs: 15.1),
];

DuelSummary duelSummary({
  String id = 'g-past',
  String code = 'PAST01',
  String name = 'Tagesduell',
  required DateTime day,
  List<DuelMember> board = kFinalBoard,
  int? memberCount,
}) =>
    DuelSummary(
      group: DuelGroup(id: id, code: code, name: name, day: day, createdBy: 'u2'),
      board: board,
      memberCount: memberCount ?? board.length,
    );

/// Three past duels: yesterday, the day before, five days ago.
List<DuelSummary> pastDuels() => [
      duelSummary(id: 'g-1', code: 'PAST01', day: DateTime(2026, 1, 14)),
      duelSummary(id: 'g-2', code: 'PAST02', name: 'Hahnenkamm-Crew', day: DateTime(2026, 1, 13), board: kTwoBoard),
      duelSummary(id: 'g-3', code: 'PAST03', day: DateTime(2026, 1, 10), board: kFinalBoard.take(2).toList()),
    ];

/// A pending invite from Lena ('u9') into her 'Hahnenkamm-Crew' duel of
/// 2026-01-15 (the day of [kDuelNow]), one member so far.
DuelInvite duelInvite({
  String id = 'inv-1',
  String fromUserId = 'u9',
  String fromName = 'Lena',
  String groupId = 'g-lena',
  String code = 'PQRS23',
  String name = 'Hahnenkamm-Crew',
  DateTime? day,
  int memberCount = 1,
  int maxMembers = 3,
}) =>
    DuelInvite(
      id: id,
      fromUserId: fromUserId,
      fromName: fromName,
      group: DuelGroup(id: groupId, code: code, name: name, day: day ?? DateTime(2026, 1, 15), createdBy: fromUserId, maxMembers: maxMembers),
      memberCount: memberCount,
    );

/// Overrides on top of `screenOverrides()` — never touches Supabase.
/// [poll] defaults to null so no duel timer outlives a widget test.
List<Override> duelOverrides({FakeDuelApi? api, FakeSocialApi? social, AuthUser? user = kUser, Duration? poll}) => [
      duelApiProvider.overrideWithValue(api),
      socialApiProvider.overrideWithValue(social),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      duelPollIntervalProvider.overrideWithValue(poll),
    ];
