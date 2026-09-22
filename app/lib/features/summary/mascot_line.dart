import '../../core/core.dart';
import 'summary_strings.dart';

/// One rule-based sentence from Toni under the numbers (docs/PLAN.md §13).
/// First day wins, then a personal best, then the size of the day.
String mascotLineFor({
  required DayRecord day,
  required SummaryStrings s,
  required bool isFirstDay,
  required bool isPb,
  required String dropMFormatted,
}) {
  final st = day.stats;
  if (isFirstDay) return s.mascotFirstDay;
  if (isPb) return s.mascotRecord;
  if (st.dropM > 2000) return s.mascotBigVertical(dropMFormatted);
  if (st.runCount > 10) return s.mascotManyRuns(st.runCount);
  if (st.runCount <= 2 || st.elapsedMs < const Duration(hours: 2).inMilliseconds) return s.mascotShortDay;
  return s.mascotDefault;
}
