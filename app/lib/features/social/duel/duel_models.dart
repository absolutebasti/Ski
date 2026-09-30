import 'package:flutter/foundation.dart';

import '../social_models.dart';

/// One row of `group_board` since migration 0009: the 0005 shape plus
/// [isLive] (the value comes from the rider's `live_days` row, no finished day
/// yet) and [updatedAtMs] (when that value was last written).
///
/// Subclass of [GroupMemberStats] so `groupBoardProvider` keeps its contract
/// (`List<GroupMemberStats>`) for the callers that only invalidate it.
@immutable
class DuelMember extends GroupMemberStats {
  const DuelMember({
    required super.userId,
    required super.displayName,
    super.runCount,
    super.dropM,
    super.skiDistanceM,
    super.maxSpeedMs,
    super.avgSkiSpeedMs,
    this.isLive = false,
    this.updatedAtMs,
    this.avatarUrl,
  });

  /// True while the rider is still on the slope — the numbers move.
  final bool isLive;

  /// Epoch ms of the last write (live upsert or finished day); null when the
  /// rider has neither.
  final int? updatedAtMs;

  /// Not delivered by `group_board` today; reserved for a later RPC shape.
  final String? avatarUrl;

  factory DuelMember.fromJson(Map<String, Object?> j) {
    final base = GroupMemberStats.fromJson(j);
    return DuelMember(
      userId: base.userId,
      displayName: base.displayName,
      runCount: base.runCount,
      dropM: base.dropM,
      skiDistanceM: base.skiDistanceM,
      maxSpeedMs: base.maxSpeedMs,
      avgSkiSpeedMs: base.avgSkiSpeedMs,
      isLive: j['is_live'] == true,
      updatedAtMs: _ms(j['updated_at']),
      avatarUrl: j['avatar_url'] as String?,
    );
  }

  /// Upgrades a 0005-shaped row (no live info) — the SocialApi fallback.
  factory DuelMember.from(GroupMemberStats m) => m is DuelMember
      ? m
      : DuelMember(
          userId: m.userId,
          displayName: m.displayName,
          runCount: m.runCount,
          dropM: m.dropM,
          skiDistanceM: m.skiDistanceM,
          maxSpeedMs: m.maxSpeedMs,
          avgSkiSpeedMs: m.avgSkiSpeedMs,
        );

  /// Minutes since [updatedAtMs] at [nowMs]; null without a timestamp.
  int? minutesAgo(int nowMs) {
    final t = updatedAtMs;
    if (t == null) return null;
    final m = (nowMs - t) ~/ 60000;
    return m < 0 ? 0 : m;
  }

  @override
  bool operator ==(Object other) => other is DuelMember && super == other && other.isLive == isLive && other.updatedAtMs == updatedAtMs;

  @override
  int get hashCode => Object.hash(super.hashCode, isLive, updatedAtMs);
}

/// One row of `my_duels(p_limit)`: the group, its member count and the board
/// as it stands (final once every member has ended the day).
@immutable
class DuelSummary {
  const DuelSummary({required this.group, required this.board, this.memberCount = 0, this.tz = 'Europe/Vienna'});

  final DuelGroup group;

  /// Sorted by Höhenmeter, best first (the server orders it; kept sorted here).
  final List<DuelMember> board;

  /// Members of the group — the '2 / 3' in the header.
  final int memberCount;

  /// IANA zone the duel day is defined in (`groups.tz`).
  final String tz;

  factory DuelSummary.fromJson(Map<String, Object?> j) {
    final raw = j['board'];
    final rows = <DuelMember>[
      if (raw is List)
        for (final r in raw)
          if (r is Map) DuelMember.fromJson(Map<String, Object?>.from(r)),
    ]..sort(compareDuelMembers);
    final count = j['member_count'];
    return DuelSummary(
      group: DuelGroup.fromJson(j),
      board: rows,
      memberCount: count is num ? count.round() : int.tryParse('$count') ?? rows.length,
      tz: (j['tz'] as String?) ?? 'Europe/Vienna',
    );
  }

  /// Local midnight of the duel day (the server `date`).
  DateTime get day => group.day;

  /// 1-based place of [userId] on the board; null when not on it.
  int? placeOf(String? userId) {
    if (userId == null) return null;
    for (var i = 0; i < board.length; i++) {
      if (board[i].userId == userId) return i + 1;
    }
    return null;
  }

  DuelMember? rowOf(String? userId) {
    if (userId == null) return null;
    for (final m in board) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// The leader — null on an empty board or when nobody has a metre yet.
  DuelMember? get winner => board.isEmpty || board.first.dropM <= 0 ? null : board.first;

  /// True while any member's value is still a live snapshot.
  bool get anyLive => board.any((m) => m.isLive);

  /// Members shown on the board: [memberCount] when known, else the rows.
  int get participants => memberCount > 0 ? memberCount : board.length;

  @override
  bool operator ==(Object other) => other is DuelSummary && other.group == group && listEquals(other.board, board) && other.memberCount == memberCount && other.tz == tz;

  @override
  int get hashCode => Object.hash(group, Object.hashAll(board), memberCount, tz);
}

/// What the app writes to `live_days` while recording inside a duel — the
/// tiny payload of `DuelApi.upsertLive`. Nothing but the four numbers the
/// board shows plus the duel day.
@immutable
class LiveDayPayload {
  const LiveDayPayload({
    required this.day,
    this.resortId,
    this.dropM = 0,
    this.runCount = 0,
    this.skiDistanceM = 0,
    this.maxSpeedMs = 0,
  });

  /// Local date of the duel (midnight) — `groups.day`.
  final DateTime day;
  final String? resortId;
  final double dropM;
  final int runCount;
  final double skiDistanceM;
  final double maxSpeedMs;

  /// Row for the upsert; `user_id` and `updated_at` are added server-side /
  /// by the API implementation.
  Map<String, Object?> toJson() => {
        'day': formatDate(day),
        'resort_id': resortId,
        'drop_m': dropM,
        'run_count': runCount,
        'ski_distance_m': skiDistanceM,
        'max_speed_ms': maxSpeedMs,
      };

  /// True when the numbers the board shows differ — the uploader skips
  /// identical snapshots.
  bool sameNumbers(LiveDayPayload other) =>
      other.day == day && other.dropM == dropM && other.runCount == runCount && other.skiDistanceM == skiDistanceM && other.maxSpeedMs == maxSpeedMs;

  @override
  bool operator ==(Object other) => other is LiveDayPayload && sameNumbers(other) && other.resortId == resortId;

  @override
  int get hashCode => Object.hash(day, resortId, dropM, runCount, skiDistanceM, maxSpeedMs);

  @override
  String toString() => 'LiveDayPayload(${formatDate(day)}, $dropM hm, $runCount runs)';
}

/// One row of `my_duel_invites()` (migration 0017): a pending invitation into
/// somebody's Tagesduell — who sent it and the group it leads into.
@immutable
class DuelInvite {
  const DuelInvite({
    required this.id,
    required this.fromUserId,
    required this.fromName,
    required this.group,
    this.fromAvatarUrl,
    this.tz = 'Europe/Vienna',
    this.memberCount = 1,
    this.createdAtMs,
  });

  /// `duel_invites.id` — what `respondInvite` takes.
  final String id;
  final String fromUserId;

  /// Display name of the sender at fetch time.
  final String fromName;
  final String? fromAvatarUrl;

  /// The duel the invite leads into (id, code, name, day, max members).
  final DuelGroup group;

  /// IANA zone the duel day is defined in (`groups.tz`).
  final String tz;

  /// Members already in the duel — '1 / 3' next to the sender.
  final int memberCount;
  final int? createdAtMs;

  factory DuelInvite.fromJson(Map<String, Object?> j) {
    int count(Object? v, int fallback) => v is num ? v.round() : int.tryParse('$v') ?? fallback;
    final from = (j['from_user'] as String?) ?? '';
    return DuelInvite(
      id: (j['id'] as String?) ?? '',
      fromUserId: from,
      fromName: (j['from_name'] as String?) ?? '',
      fromAvatarUrl: j['from_avatar_url'] as String?,
      group: DuelGroup(
        id: (j['group_id'] as String?) ?? '',
        code: (j['code'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        day: parseDate(j['day']) ?? today(),
        createdBy: from,
        maxMembers: count(j['max_members'], 3),
      ),
      tz: (j['tz'] as String?) ?? 'Europe/Vienna',
      memberCount: count(j['member_count'], 1),
      createdAtMs: _ms(j['created_at']),
    );
  }

  /// True when the duel has no seat left — 'Annehmen' would fail with
  /// duel_full; the card says so instead.
  bool get full => memberCount >= group.maxMembers;

  @override
  bool operator ==(Object other) => other is DuelInvite && other.id == id && other.group == group && other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(id, group, memberCount);

  @override
  String toString() => 'DuelInvite($id from $fromName → ${group.code})';
}

/// ISO timestamp (or DateTime / epoch number) → epoch ms; null when absent.
int? _ms(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is num) return v.round();
  return DateTime.tryParse('$v')?.millisecondsSinceEpoch;
}
