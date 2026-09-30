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
  dayCount('day_count'),

  /// Server day points (migration 0004): hm ÷ 10 + km × 10 + runs × 5 + 50,
  /// without the device-side streak bonus (docs/GAMIFICATION.md §1).
  points('points');

  const SocialMetric(this.wire);

  final String wire;

  /// Order of the metric chips on the Rangliste.
  static const List<SocialMetric> leaderboard = [dropM, points, runCount, skiDistanceM, maxSpeedMs, dayCount];

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

/// Who the Rangliste is ranked against — the scope row above the metric chips.
///
/// `friends` = accepted friends + self ('Freunde', RPC `friends_board`),
/// `country` = riders of the own team country ('Mein Land'), `resort` = one
/// ski resort ('Gebiet'), `all` = everyone ('Alle').
enum LeaderboardScope { friends, country, resort, all }

/// Points of one finished day as the server computes them
/// (`days.points`, migration 0004) — no streak bonus.
double dayPointsOf({required double dropM, required double skiDistanceM, required int runCount}) =>
    (dropM / 10 + skiDistanceM / 100 + runCount * 5 + 50).roundToDouble();

/// Key of `leaderboardProvider`; value equality so the family caches.
@immutable
class LeaderboardQuery {
  const LeaderboardQuery({
    required this.seasonKey,
    this.period = LeaderboardPeriod.season,
    this.periodKey,
    this.resortId,
    this.countryCode,
    this.metric = SocialMetric.dropM,
    this.limit = 100,
    this.offset = 0,
    this.friends = false,
  });

  /// Season/month/week key derived from [at] in one step.
  factory LeaderboardQuery.at(
    DateTime at, {
    LeaderboardPeriod period = LeaderboardPeriod.season,
    String? resortId,
    String? countryCode,
    SocialMetric metric = SocialMetric.dropM,
    int limit = 100,
    int offset = 0,
    bool friends = false,
  }) =>
      LeaderboardQuery(
        seasonKey: seasons.seasonKey(at),
        period: period,
        periodKey: period.keyFor(at),
        resortId: resortId,
        countryCode: countryCode,
        metric: metric,
        limit: limit,
        offset: offset,
        friends: friends,
      );

  /// null = 'Alle Gebiete'.
  final String? resortId;

  /// ISO alpha-2 filter (`p_country`); null = every country.
  final String? countryCode;

  /// True = the Freunde-Rangliste (RPC `friends_board`, which only reads
  /// [wireKey] and [metric]; resort, country and offset are ignored).
  final bool friends;

  /// Rows to skip (`p_offset`, migration 0013) — 'Zu mir springen' loads the
  /// window around the own rank. 0 = the top of the board with the podium.
  final int offset;

  LeaderboardScope get scope => switch ((friends, countryCode, resortId)) {
        (true, _, _) => LeaderboardScope.friends,
        (_, String(), _) => LeaderboardScope.country,
        (_, null, String()) => LeaderboardScope.resort,
        _ => LeaderboardScope.all,
      };

  /// Offset that centres [rank] in a window of [limit] rows, clamped ≥ 0.
  int offsetAround(int rank) {
    final o = rank - 1 - limit ~/ 2;
    return o < 0 ? 0 : o;
  }

  /// True when [rank] would be inside the fetched slice.
  bool covers(int rank) => rank > offset && rank <= offset + limit;

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
    String? countryCode,
    bool clearCountry = false,
    String? seasonKey,
    LeaderboardPeriod? period,
    String? periodKey,
    SocialMetric? metric,
    int? offset,
    bool? friends,
  }) =>
      LeaderboardQuery(
        resortId: clearResort ? null : (resortId ?? this.resortId),
        countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
        seasonKey: seasonKey ?? this.seasonKey,
        period: period ?? this.period,
        periodKey: periodKey ?? this.periodKey,
        metric: metric ?? this.metric,
        limit: limit,
        offset: offset ?? this.offset,
        friends: friends ?? this.friends,
      );

  @override
  bool operator ==(Object other) =>
      other is LeaderboardQuery &&
      other.resortId == resortId &&
      other.countryCode == countryCode &&
      other.seasonKey == seasonKey &&
      other.period == period &&
      other.periodKey == periodKey &&
      other.metric == metric &&
      other.limit == limit &&
      other.offset == offset &&
      other.friends == friends;

  @override
  int get hashCode => Object.hash(resortId, countryCode, seasonKey, period, periodKey, metric, limit, offset, friends);

  @override
  String toString() =>
      'LeaderboardQuery(${friends ? 'friends' : '$resortId, $countryCode'}, $wireKey, ${metric.wire}, $limit${offset > 0 ? ', +$offset' : ''})';
}

/// One row of the `country_board` RPC — a team in the Länder-Wertung.
@immutable
class CountryEntry {
  const CountryEntry({required this.countryCode, required this.riders, required this.points, this.dropM = 0});

  /// ISO-3166 alpha-2, upper case.
  final String countryCode;

  /// Distinct opted-in riders with at least one plausible day in the window.
  final int riders;

  /// Sum of `days.points`.
  final double points;
  final double dropM;

  factory CountryEntry.fromJson(Map<String, Object?> j) => CountryEntry(
        countryCode: ((j['country_code'] as String?) ?? '').toUpperCase(),
        riders: _int(j['riders']),
        points: _double(j['points']),
        dropM: _double(j['drop_m']),
      );

  @override
  bool operator ==(Object other) =>
      other is CountryEntry &&
      other.countryCode == countryCode &&
      other.riders == riders &&
      other.points == points &&
      other.dropM == dropM;

  @override
  int get hashCode => Object.hash(countryCode, riders, points, dropM);
}

/// Points lead the country board — the same order the RPC returns.
int compareCountries(CountryEntry a, CountryEntry b) => b.points.compareTo(a.points);

/// 'AT' → 🇦🇹 (two regional-indicator symbols); '' for anything that is not
/// two ASCII letters.
String flagEmoji(String? countryCode) {
  final c = countryCode?.trim().toUpperCase();
  if (c == null || c.length != 2) return '';
  final a = c.codeUnitAt(0), b = c.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
  return String.fromCharCodes([0x1F1E6 + a - 0x41, 0x1F1E6 + b - 0x41]);
}

/// One row of the `leaderboard` / `friends_board` RPCs (migration 0005 shape:
/// rank, user_id, display_name, avatar_url, country_code, value, total,
/// last_day, day_count).
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.value,
    this.avatarUrl,
    this.total = 0,
    this.countryCode,
    this.lastDayMs,
    this.dayCount = 0,
  });

  final int rank;
  final String userId;

  /// As delivered, blank folded to null; render via `riderName`.
  final String? displayName;
  final String? avatarUrl;

  /// Participant count of the whole board (server window count); 0 = unknown.
  final int total;

  /// SI — metres, m/s or a plain count, depending on the query metric.
  final double value;

  /// Team country (ISO-3166 alpha-2, upper case) or null.
  final String? countryCode;

  /// Start of the rider's most recent day in the window, epoch ms; null when
  /// the RPC did not say (or the rider has no day, friends board).
  final int? lastDayMs;

  /// Plausible days in the window; 0 = unknown or none.
  final int dayCount;

  factory LeaderboardEntry.fromJson(Map<String, Object?> j) => LeaderboardEntry(
        rank: _int(j['rank']),
        userId: (j['user_id'] as String?) ?? '',
        displayName: parseDisplayName(j['display_name']),
        avatarUrl: j['avatar_url'] as String?,
        value: _double(j['value']),
        total: _int(j['total']),
        countryCode: _country(j['country_code']),
        lastDayMs: _ms(j['last_day']),
        dayCount: _int(j['day_count']),
      );

  @override
  bool operator ==(Object other) =>
      other is LeaderboardEntry &&
      other.rank == rank &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.value == value &&
      other.countryCode == countryCode &&
      other.lastDayMs == lastDayMs &&
      other.dayCount == dayCount;

  @override
  int get hashCode => Object.hash(rank, userId, displayName, avatarUrl, value, countryCode, lastDayMs, dayCount);
}

/// How far [entry] trails the leader of its board; 0 for the leader itself
/// and for an empty board. Same unit as the query metric.
double deltaToLeader(LeaderboardEntry entry, List<LeaderboardEntry> entries) {
  if (entries.isEmpty) return 0;
  final lead = entries.first.value;
  final d = lead - entry.value;
  return d < 0 ? 0 : d;
}

/// Where the signed-in user stands on the Rangliste — from the RPC `my_rank`
/// (the whole ranked set, migration 0005) or from the fetched slice.
@immutable
class MyRank {
  const MyRank({required this.rank, required this.total, required this.value});
  final int rank;

  /// Participants on the board: the server-side count when the RPC provides
  /// it (migration 0003), otherwise the size of the fetched slice.
  final int total;

  /// The user's own value, same unit as the query metric.
  final double value;

  /// One row of `my_rank(...)`.
  factory MyRank.fromJson(Map<String, Object?> j) => MyRank(rank: _int(j['rank']), total: _int(j['total']), value: _double(j['value']));

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

/// `display_name` as every model keeps it: trimmed, null when absent or
/// blank. No fallback here — the UI resolves it per locale (`riderName`,
/// rider_name.dart; SOC-NAME-FALLBACK).
String? parseDisplayName(Object? raw) {
  if (raw is! String) return null;
  final name = raw.trim();
  return name.isEmpty ? null : name;
}

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

  /// Trimmed name; '' when the rider has none — render via `riderName`,
  /// which treats '' like null. Still a non-null String because the duel
  /// widgets (another session) read it directly; flip to `String?` once they
  /// call `riderName` (SOC-NAME-FALLBACK).
  final String displayName;
  final int runCount;
  final double dropM;
  final double skiDistanceM;
  final double maxSpeedMs;
  final double avgSkiSpeedMs;

  factory GroupMemberStats.fromJson(Map<String, Object?> j) => GroupMemberStats(
        userId: (j['user_id'] as String?) ?? '',
        displayName: parseDisplayName(j['display_name']) ?? '',
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

/// Upper-case alpha-2 or null.
String? _country(Object? v) {
  final c = (v as String?)?.trim().toUpperCase();
  return c == null || c.length != 2 ? null : c;
}

/// ISO timestamp (or DateTime) → epoch ms; null when absent or unparsable.
int? _ms(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is num) return v.round();
  return DateTime.tryParse('$v')?.millisecondsSinceEpoch;
}
