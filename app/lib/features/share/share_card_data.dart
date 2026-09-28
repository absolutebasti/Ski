import '../../core/core.dart';
import '../achievements/achievement_models.dart';

/// Which share card to render. `day` is the original route card
/// ([ShareCard]); the others are the Show-Säule cards (docs/BACKLOG.md
/// SHARE-CARDS): medal, level, season, rank and duel.
enum ShareCardKind { day, medal, level, season, rank, duel }

/// Metric shown on a rank card. SI in ([RankCardData.value]), display out.
enum ShareMetric { vertical, runs, distance, topSpeed, points, days }

/// Payload of one share card. Every subclass carries its [kind] so
/// `ShareService.shareCard(kind, data)` can assert the pair matches.
sealed class ShareCardData {
  const ShareCardData();
  ShareCardKind get kind;

  /// Short, file-name safe id of the subject ('streak-gold', 'level-4' …).
  String get slug;
}

/// The finished day — the classic route card.
class DayCardData extends ShareCardData {
  const DayCardData(this.detail);
  final DayDetail detail;

  @override
  ShareCardKind get kind => ShareCardKind.day;
  @override
  String get slug => detail.day.id.length >= 6 ? detail.day.id.substring(0, 6) : detail.day.id;
}

/// A freshly earned medal: tier ring 320, title, threshold, earned date.
class MedalCardData extends ShareCardData {
  const MedalCardData({required this.def, required this.earnedAt});
  final MedalDef def;

  /// Epoch ms of the day that earned the medal.
  final int earnedAt;

  @override
  ShareCardKind get kind => ShareCardKind.medal;
  @override
  String get slug => def.id;
}

/// The current level: ring with progress, 'Level 4 · Carver', lifetime km.
class LevelCardData extends ShareCardData {
  const LevelCardData({required this.level});
  final LevelState level;

  @override
  ShareCardKind get kind => ShareCardKind.level;
  @override
  String get slug => 'level-${level.index}';
}

/// One season: day count plus the four numerals (hm, runs, km, top speed).
class SeasonCardData extends ShareCardData {
  const SeasonCardData({
    required this.seasonKey,
    required this.dayCount,
    required this.dropM,
    required this.runCount,
    required this.skiDistanceM,
    required this.maxSpeedMs,
  });

  /// 'YYYY/YY', see `seasonKey()` in core/season.dart.
  final String seasonKey;
  final int dayCount;
  final double dropM;
  final int runCount;
  final double skiDistanceM;
  final double maxSpeedMs;

  factory SeasonCardData.fromTotals(SeasonTotals t) => SeasonCardData(
    seasonKey: t.seasonKey,
    dayCount: t.dayCount,
    dropM: t.dropM,
    runCount: t.runCount,
    skiDistanceM: t.skiDistanceM,
    maxSpeedMs: t.maxSpeedMs,
  );

  @override
  ShareCardKind get kind => ShareCardKind.season;
  @override
  String get slug => 'season-${seasonKey.replaceAll('/', '-')}';
}

/// Own place on a leaderboard: mini podium + 'Platz 3 in Kitzbühel · Saison 26/27'.
class RankCardData extends ShareCardData {
  const RankCardData({
    required this.rank,
    required this.total,
    required this.value,
    required this.metric,
    required this.seasonKey,
    this.scopeName,
    this.periodLabel,
  });

  /// 1-based place; [total] = participants on the board (0 = unknown).
  final int rank;
  final int total;

  /// Own value in the metric's SI unit (metres, m/s, count).
  final double value;
  final ShareMetric metric;

  /// 'YYYY/YY'; rendered as 'Saison 26/27' unless [periodLabel] is set.
  final String seasonKey;

  /// Resort or country name; null = the global board.
  final String? scopeName;

  /// Overrides the season label for month/week boards ('September 2026', 'KW 39').
  final String? periodLabel;

  @override
  ShareCardKind get kind => ShareCardKind.rank;
  @override
  String get slug => 'rank-$rank';
}

/// One member row of a duel card.
class DuelCardRow {
  const DuelCardRow({required this.displayName, required this.dropM, this.runCount = 0, this.maxSpeedMs = 0, this.isMe = false});
  final String displayName;
  final double dropM;
  final int runCount;
  final double maxSpeedMs;
  final bool isMe;
}

/// Final board of a Tagesduell: up to three rows, sorted by vertical, the
/// winner ringed.
class DuelCardData extends ShareCardData {
  const DuelCardData({required this.day, required this.rows, this.name, this.resortName});

  /// Epoch ms of the duel day.
  final int day;
  final List<DuelCardRow> rows;
  final String? name;
  final String? resortName;

  /// Rows by vertical, best first, at most three.
  List<DuelCardRow> get board {
    final sorted = [...rows]..sort((a, b) => b.dropM.compareTo(a.dropM));
    return sorted.take(3).toList();
  }

  /// 1-based place of the own row, null when no row is marked.
  int? get myPlace {
    final b = board;
    for (var i = 0; i < b.length; i++) {
      if (b[i].isMe) return i + 1;
    }
    return null;
  }

  @override
  ShareCardKind get kind => ShareCardKind.duel;
  @override
  String get slug => 'duel-${DateTime.fromMillisecondsSinceEpoch(day).toIso8601String().substring(0, 10)}';
}
