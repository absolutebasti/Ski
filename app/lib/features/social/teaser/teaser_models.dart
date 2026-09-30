import 'package:flutter/foundation.dart';

import '../../account/profile_service.dart' show Profile;
import '../social_models.dart';

/// One row of the `public_board_teaser` RPC (migration 0016): the signed-out
/// preview of the top 10. Deliberately without a user id — nothing on a
/// teaser row can open a profile before the rider signs in.
@immutable
class TeaserEntry {
  const TeaserEntry({required this.rank, required this.displayName, required this.value, this.avatarUrl});

  final int rank;
  final String displayName;

  /// Season points (`days.points`, docs/GAMIFICATION.md §1).
  final double value;
  final String? avatarUrl;

  /// A blank name falls back to the server column default
  /// ([Profile.fallbackName]); SOC-NAME-FALLBACK localises it later.
  factory TeaserEntry.fromJson(Map<String, Object?> j) {
    final name = j['display_name'];
    final avatar = j['avatar_url'];
    return TeaserEntry(
      rank: _int(j['rank']),
      displayName: name is String && name.trim().isNotEmpty ? name.trim() : Profile.fallbackName,
      value: _double(j['value']),
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
    );
  }

  /// The board row shape, so the teaser reuses `LeaderboardRows` read-only.
  /// `userId` is empty on purpose: the row never opens a rider.
  LeaderboardEntry toEntry() => LeaderboardEntry(rank: rank, userId: '', displayName: displayName, value: value, avatarUrl: avatarUrl);

  @override
  bool operator ==(Object other) =>
      other is TeaserEntry && other.rank == rank && other.displayName == displayName && other.value == value && other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(rank, displayName, value, avatarUrl);

  @override
  String toString() => 'TeaserEntry($rank $displayName $value)';
}

/// Key of `teaserProvider`; value equality so the family caches.
@immutable
class TeaserQuery {
  const TeaserQuery({required this.seasonKey, this.resortId});

  /// Season / month / week key as `p_season_key` ('2025/26', '2026-01', '2026-W03').
  final String seasonKey;

  /// null = every resort.
  final String? resortId;

  @override
  bool operator ==(Object other) => other is TeaserQuery && other.seasonKey == seasonKey && other.resortId == resortId;

  @override
  int get hashCode => Object.hash(seasonKey, resortId);

  @override
  String toString() => 'TeaserQuery($resortId, $seasonKey)';
}

/// The RPC payload → at most [kTeaserLimit] rows in rank order. Anything that
/// is not a list of maps yields an empty board (the screen then shows ghost
/// rows), never an exception.
List<TeaserEntry> parseTeaserRows(Object? raw) {
  if (raw is! List) return const [];
  final rows = [
    for (final r in raw)
      if (r is Map) TeaserEntry.fromJson(Map<String, Object?>.from(r)),
  ]..sort((a, b) => a.rank.compareTo(b.rank));
  return rows.length > kTeaserLimit ? rows.sublist(0, kTeaserLimit) : rows;
}

/// The server caps the teaser at ten rows; the client never shows more.
const int kTeaserLimit = 10;

int _int(Object? v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);

double _double(Object? v) => v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
