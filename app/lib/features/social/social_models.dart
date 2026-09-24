import 'package:flutter/foundation.dart';

import '../../core/season.dart' as seasons;

/// Metric a Rangliste or a Wochen-Challenge is measured in.
///
/// [wire] is the string the backend understands — the `p_metric` argument of
/// the `leaderboard` RPC and the `challenges.metric` check constraint.
enum SocialMetric {
  dropM('drop_m'),
  runCount('run_count'),
  skiDistanceM('ski_distance_m'),
  maxSpeedMs('max_speed_ms'),
  dayCount('day_count');

  const SocialMetric(this.wire);

  final String wire;

  /// Order of the metric chips on the Rangliste.
  static const List<SocialMetric> leaderboard = [dropM, runCount, skiDistanceM, maxSpeedMs, dayCount];

  /// `challenges.metric` has no `max_speed_ms`.
  static const List<SocialMetric> challenge = [dropM, runCount, skiDistanceM, dayCount];

  static SocialMetric fromWire(String? wire) => values.firstWhere((m) => m.wire == wire, orElse: () => dropM);
}

/// Window the Rangliste is ranked over — the three segmented tabs.
///
/// The RPC takes one text key (`p_season_key`); Saison sends '2025/26',
/// Monat '2026-01', Woche '2026-W03'. See the WP-16 report: the RPC still has
/// to learn the month/week keys, until then those two tabs come back empty.
enum LeaderboardPeriod {
  season,
  month,
  week;

  /// Key sent as `p_season_key` for a point in time.
  String keyFor(DateTime at) => switch (this) {
        LeaderboardPeriod.season => seasons.seasonKey(at),
        LeaderboardPeriod.month => monthKey(at),
        LeaderboardPeriod.week => isoWeekKey(at),
      };
}

/// 'YYYY-MM'.
String monthKey(DateTime at) => '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}';

/// ISO-8601 week key, 'YYYY-Www' (the year is the ISO week-year).
String isoWeekKey(DateTime at) {
  final date = DateTime.utc(at.year, at.month, at.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstJan = DateTime.utc(thursday.year, 1, 1);
  final week = thursday.difference(firstJan).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Key of `leaderboardProvider`; value equality so the family caches.
@immutable
class LeaderboardQuery {
  const LeaderboardQuery({
    required this.seasonKey,
    this.period = LeaderboardPeriod.season,
    this.periodKey,
    this.resortId,
    this.metric = SocialMetric.dropM,
    this.limit = 100,
  });

  /// Season/month/week key derived from [at] in one step.
  factory LeaderboardQuery.at(
    DateTime at, {
    LeaderboardPeriod period = LeaderboardPeriod.season,
    String? resortId,
    SocialMetric metric = SocialMetric.dropM,
    int limit = 100,
  }) =>
      LeaderboardQuery(
        seasonKey: seasons.seasonKey(at),
        period: period,
        periodKey: period.keyFor(at),
        resortId: resortId,
        metric: metric,
        limit: limit,
      );

  /// null = 'Alle Gebiete'.
  final String? resortId;

  /// Always the season the query was built in — used for the caption.
  final String seasonKey;
  final LeaderboardPeriod period;

  /// Key for [period]; null falls back to [seasonKey].
  final String? periodKey;
  final SocialMetric metric;
  final int limit;

  /// What goes over the wire as `p_season_key`.
  String get wireKey => period == LeaderboardPeriod.season ? seasonKey : (periodKey ?? seasonKey);

  LeaderboardQuery copyWith({
    String? resortId,
    bool clearResort = false,
    String? seasonKey,
    LeaderboardPeriod? period,
    String? periodKey,
    SocialMetric? metric,
  }) =>
      LeaderboardQuery(
        resortId: clearResort ? null : (resortId ?? this.resortId),
        seasonKey: seasonKey ?? this.seasonKey,
        period: period ?? this.period,
        periodKey: periodKey ?? this.periodKey,
        metric: metric ?? this.metric,
        limit: limit,
      );

  @override
  bool operator ==(Object other) =>
      other is LeaderboardQuery &&
      other.resortId == resortId &&
      other.seasonKey == seasonKey &&
      other.period == period &&
      other.periodKey == periodKey &&
      other.metric == metric &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(resortId, seasonKey, period, periodKey, metric, limit);

  @override
  String toString() => 'LeaderboardQuery($resortId, $wireKey, ${metric.wire}, $limit)';
}

/// One row of the `leaderboard` RPC.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.value,
    this.avatarUrl,
    this.total = 0,
  });

  final int rank;
  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// Participant count of the whole board (server window count); 0 = unknown.
  final int total;

  /// SI — metres, m/s or a plain count, depending on the query metric.
  final double value;

  factory LeaderboardEntry.fromJson(Map<String, Object?> j) => LeaderboardEntry(
        rank: _int(j['rank']),
        userId: (j['user_id'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? 'Skifahrer',
        avatarUrl: j['avatar_url'] as String?,
        value: _double(j['value']),
        total: _int(j['total']),
      );

  @override
  bool operator ==(Object other) =>
      other is LeaderboardEntry &&
      other.rank == rank &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.value == value;

  @override
  int get hashCode => Object.hash(rank, userId, displayName, avatarUrl, value);
}

/// Where the signed-in user stands in the fetched slice of the Rangliste.
@immutable
class MyRank {
  const MyRank({required this.rank, required this.total, required this.value});
  final int rank;

  /// Participants on the board: the server-side count when the RPC provides
  /// it (migration 0003), otherwise the size of the fetched slice.
  final int total;

  /// The user's own value, same unit as the query metric.
  final double value;

  @override
  bool operator ==(Object other) => other is MyRank && other.rank == rank && other.total == total && other.value == value;

  @override
  int get hashCode => Object.hash(rank, total, value);
}

/// Finds the signed-in user in a leaderboard slice; null when not in it.
MyRank? myRankOf(List<LeaderboardEntry> entries, String? userId) {
  if (userId == null) return null;
  for (final e in entries) {
    if (e.userId == userId) return MyRank(rank: e.rank, total: e.total > 0 ? e.total : entries.length, value: e.value);
  }
  return null;
}

/// Initials for an avatar circle: 'Lena Bergmann' → 'LB'.
String initialsOf(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = _firstRune(parts.first);
  if (parts.length == 1) return first.toUpperCase();
  return '$first${_firstRune(parts.last)}'.toUpperCase();
}

String _firstRune(String s) => s.isEmpty ? '' : String.fromCharCodes(s.runes.take(1));

/// A Tagesduell — one `groups` row.
@immutable
class DuelGroup {
  const DuelGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.day,
    required this.createdBy,
    this.resortId,
    this.maxMembers = 3,
  });

  final String id;

  /// Six characters, unambiguous alphabet.
  final String code;
  final String name;

  /// Local date of the duel (midnight).
  final DateTime day;
  final String? resortId;
  final String createdBy;
  final int maxMembers;

  factory DuelGroup.fromJson(Map<String, Object?> j) => DuelGroup(
        id: (j['id'] as String?) ?? '',
        code: (j['code'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        day: parseDate(j['day']) ?? DateTime.now(),
        resortId: j['resort_id'] as String?,
        createdBy: (j['created_by'] as String?) ?? '',
        maxMembers: j['max_members'] == null ? 3 : _int(j['max_members']),
      );

  @override
  bool operator ==(Object other) => other is DuelGroup && other.id == id && other.code == code;

  @override
  int get hashCode => Object.hash(id, code);
}

/// One row of the `group_board` RPC.
@immutable
class GroupMemberStats {
  const GroupMemberStats({
    required this.userId,
    required this.displayName,
    this.runCount = 0,
    this.dropM = 0,
    this.skiDistanceM = 0,
    this.maxSpeedMs = 0,
    this.avgSkiSpeedMs = 0,
  });

  final String userId;
  final String displayName;
  final int runCount;
  final double dropM;
  final double skiDistanceM;
  final double maxSpeedMs;
  final double avgSkiSpeedMs;

  factory GroupMemberStats.fromJson(Map<String, Object?> j) => GroupMemberStats(
        userId: (j['user_id'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? 'Skifahrer',
        runCount: _int(j['run_count']),
        dropM: _double(j['drop_m']),
        skiDistanceM: _double(j['ski_distance_m']),
        maxSpeedMs: _double(j['max_speed_ms']),
        avgSkiSpeedMs: _double(j['avg_ski_speed_ms']),
      );

  @override
  bool operator ==(Object other) =>
      other is GroupMemberStats &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.runCount == runCount &&
      other.dropM == dropM &&
      other.skiDistanceM == skiDistanceM &&
      other.maxSpeedMs == maxSpeedMs &&
      other.avgSkiSpeedMs == avgSkiSpeedMs;

  @override
  int get hashCode => Object.hash(userId, displayName, runCount, dropM, skiDistanceM, maxSpeedMs, avgSkiSpeedMs);
}

/// Höhenmeter lead the duel board — the same order the board is sorted in.
int compareDuelMembers(GroupMemberStats a, GroupMemberStats b) => b.dropM.compareTo(a.dropM);

/// One `challenges` row.
@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.startsOn,
    required this.endsOn,
  });

  final String id;
  final String title;
  final SocialMetric metric;

  /// SI, same unit as [metric].
  final double target;
  final DateTime startsOn;
  final DateTime endsOn;

  factory Challenge.fromJson(Map<String, Object?> j) => Challenge(
        id: (j['id'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        metric: SocialMetric.fromWire(j['metric'] as String?),
        target: _double(j['target']),
        startsOn: parseDate(j['starts_on']) ?? DateTime.now(),
        endsOn: parseDate(j['ends_on']) ?? DateTime.now(),
      );

  /// Inclusive end of the window in ms epoch, so a day started on [endsOn]
  /// still counts.
  int get windowStartMs => DateTime(startsOn.year, startsOn.month, startsOn.day).millisecondsSinceEpoch;
  int get windowEndMs => DateTime(endsOn.year, endsOn.month, endsOn.day + 1).millisecondsSinceEpoch;

  bool containsMs(int ts) => ts >= windowStartMs && ts < windowEndMs;

  /// Whole days left including today; 0 on the last day.
  int daysLeft(DateTime now) => DateTime(endsOn.year, endsOn.month, endsOn.day).difference(DateTime(now.year, now.month, now.day)).inDays;

  @override
  bool operator ==(Object other) => other is Challenge && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 'YYYY-MM-DD' (Postgres `date`) or an ISO timestamp, as a local midnight.
DateTime? parseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  final parsed = DateTime.tryParse('$v');
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// Postgres `date` literal.
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

int _int(Object? v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);

double _double(Object? v) => v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
