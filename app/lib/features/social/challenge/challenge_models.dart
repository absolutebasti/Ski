import 'package:flutter/foundation.dart';

import '../social_models.dart';

/// A `challenges` row with both title columns (migration 0010). Extends
/// [Challenge] so everything that already handles the base type — the social
/// screen, `currentChallenge`, `localProgress` — keeps working; the card picks
/// [titleDe] / [titleEn] by locale and falls back to a title derived from
/// metric + target (ChallengeStrings.titleOf) when a column is missing.
@immutable
class WeeklyChallenge extends Challenge {
  const WeeklyChallenge({
    required super.id,
    required super.title,
    required super.metric,
    required super.target,
    required super.startsOn,
    required super.endsOn,
    this.titleDe,
    this.titleEn,
  });

  /// `challenges.title_de` / `title_en`; null or empty = not provided.
  final String? titleDe;
  final String? titleEn;

  factory WeeklyChallenge.fromJson(Map<String, Object?> j) {
    final base = Challenge.fromJson(j);
    return WeeklyChallenge(
      id: base.id,
      title: base.title,
      metric: base.metric,
      target: base.target,
      startsOn: base.startsOn,
      endsOn: base.endsOn,
      titleDe: _text(j['title_de']),
      titleEn: _text(j['title_en']),
    );
  }

  /// Whether the window has closed before [now] (local calendar day).
  bool isEnded(DateTime now) => daysLeft(now) < 0;
}

/// One row of the `challenge_board` RPC: a participant with the value the
/// server computed from their days inside the window. [participants] and
/// [doneCount] are window counts — identical on every row of one board.
@immutable
class ChallengeBoardEntry {
  const ChallengeBoardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.value,
    this.avatarUrl,
    this.countryCode,
    this.done = false,
    this.participants = 0,
    this.doneCount = 0,
  });

  final int rank;
  final String userId;

  /// As delivered, blank folded to null; render via `riderName`.
  final String? displayName;
  final String? avatarUrl;

  /// ISO-3166 alpha-2, upper case; null when the rider never chose a team.
  final String? countryCode;

  /// SI, same unit as the challenge metric.
  final double value;

  /// value ≥ target.
  final bool done;
  final int participants;
  final int doneCount;

  factory ChallengeBoardEntry.fromJson(Map<String, Object?> j) => ChallengeBoardEntry(
        rank: _int(j['rank']),
        userId: (j['user_id'] as String?) ?? '',
        displayName: parseDisplayName(j['display_name']),
        avatarUrl: j['avatar_url'] as String?,
        countryCode: (j['country_code'] as String?)?.toUpperCase(),
        value: _double(j['value']),
        done: j['done'] == true,
        participants: _int(j['participants']),
        doneCount: _int(j['done_count']),
      );

  @override
  bool operator ==(Object other) =>
      other is ChallengeBoardEntry &&
      other.rank == rank &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.countryCode == countryCode &&
      other.value == value &&
      other.done == done &&
      other.participants == participants &&
      other.doneCount == doneCount;

  @override
  int get hashCode => Object.hash(rank, userId, displayName, avatarUrl, countryCode, value, done, participants, doneCount);
}

/// 'n dabei · m geschafft' — taken from any row (window counts); (0, 0) for
/// an empty board.
(int participants, int done) boardCounts(List<ChallengeBoardEntry> rows) =>
    rows.isEmpty ? (0, 0) : (rows.first.participants, rows.first.doneCount);

/// One row of `my_challenge_history`: an ended challenge the user joined with
/// the final result.
@immutable
class ChallengeHistoryEntry {
  const ChallengeHistoryEntry({
    required this.challenge,
    required this.value,
    required this.done,
    required this.rank,
    required this.participants,
    this.doneCount = 0,
  });

  final WeeklyChallenge challenge;

  /// Final value, SI in the challenge metric.
  final double value;
  final bool done;
  final int rank;
  final int participants;
  final int doneCount;

  factory ChallengeHistoryEntry.fromJson(Map<String, Object?> j) => ChallengeHistoryEntry(
        challenge: WeeklyChallenge.fromJson({...j, 'id': j['challenge_id'] ?? j['id']}),
        value: _double(j['value']),
        done: j['done'] == true,
        rank: _int(j['rank']),
        participants: _int(j['participants']),
        doneCount: _int(j['done_count']),
      );

  @override
  bool operator ==(Object other) =>
      other is ChallengeHistoryEntry &&
      other.challenge == challenge &&
      other.value == value &&
      other.done == done &&
      other.rank == rank &&
      other.participants == participants &&
      other.doneCount == doneCount;

  @override
  int get hashCode => Object.hash(challenge, value, done, rank, participants, doneCount);
}

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int _int(Object? v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);

double _double(Object? v) => v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
