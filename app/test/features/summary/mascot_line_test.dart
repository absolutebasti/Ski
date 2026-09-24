import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/summary/count_up.dart';
import 'package:slopetrack/features/summary/mascot_line.dart';
import 'package:slopetrack/features/summary/summary_strings.dart';
import 'package:flutter/widgets.dart' show Locale;

const _de = SummaryStrings(AppLocale(Locale('de')));

DayRecord _day(DayStats stats) => DayRecord(id: 'x', startedAt: 0, status: DayStatus.finished, stats: stats);

String _line(DayStats stats, {bool isFirstDay = false, bool isPb = false}) => mascotLineFor(
      day: _day(stats),
      s: _de,
      isFirstDay: isFirstDay,
      isPb: isPb,
      dropMFormatted: Fmt.metres(stats.dropM, locale: 'de'),
    );

void main() {
  test('first day beats every other rule', () {
    expect(_line(const DayStats(dropM: 2400, runCount: 12), isFirstDay: true, isPb: true), _de.mascotFirstDay);
  });

  test('a record comes before the size of the day', () {
    expect(_line(const DayStats(dropM: 2400, runCount: 12), isPb: true), _de.mascotRecord);
  });

  test('more than 2000 hm gets the vertical line', () {
    expect(_line(const DayStats(dropM: 2480, runCount: 9, elapsedMs: 18000000)), _de.mascotBigVertical('2.480'));
  });

  test('more than ten runs gets the runs line', () {
    expect(_line(const DayStats(dropM: 1500, runCount: 12, elapsedMs: 18000000)), _de.mascotManyRuns(12));
  });

  test('a short day says so', () {
    expect(_line(const DayStats(dropM: 300, runCount: 2, elapsedMs: 1800000)), _de.mascotShortDay);
  });

  test('everything else gets the default line', () {
    expect(_line(const DayStats(dropM: 900, runCount: 6, elapsedMs: 4 * 3600 * 1000)), _de.mascotDefault);
  });

  test('the count-up stagger is 90 ms with a 400 ms ramp', () {
    expect(countUpTotal(4), const Duration(milliseconds: 670));
    expect(countUpTotal(1), const Duration(milliseconds: 400));
  });
}
