import '../../core/core.dart';

/// All days of one season, newest first.
class SeasonGroup {
  const SeasonGroup(this.seasonKey, this.days);
  final String seasonKey;
  final List<DaySummary> days;
}

/// Splits the (already newest-first) day list into seasons, keeping the order.
/// Season boundaries come from `seasonKeyFromMs` (1 July – 30 June).
List<SeasonGroup> groupBySeason(List<DaySummary> days) {
  final out = <SeasonGroup>[];
  for (final d in days) {
    final key = seasonKeyFromMs(d.startedAt);
    if (out.isNotEmpty && out.last.seasonKey == key) {
      out.last.days.add(d);
    } else {
      out.add(SeasonGroup(key, [d]));
    }
  }
  return out;
}

/// The season totals row for [key], or null when the list has none.
SeasonTotals? totalsFor(List<SeasonTotals> totals, String key) {
  for (final t in totals) {
    if (t.seasonKey == key) return t;
  }
  return null;
}
