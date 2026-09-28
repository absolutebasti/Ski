import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/today/season_card.dart';

import '../../support/pump.dart';

DaySummary _day(String id, int dayOfMonth, double dropM) => DaySummary(
      id: id,
      startedAt: DateTime(2026, 1, dayOfMonth, 9).millisecondsSinceEpoch,
      stats: DayStats(runCount: 5, dropM: dropM, maxSpeedMs: 15),
    );

void main() {
  test('sparkValues pads a short season to 14 slots, newest day before the padding', () {
    final v = SeasonCard.sparkValues([_day('c', 20, 900), _day('a', 5, 1200), _day('b', 12, 1500)]);
    expect(v.length, SeasonCard.minSlots);
    expect(v.sublist(0, 3), [1200, 1500, 900]); // date order, not list order
    expect(v.sublist(3).every((x) => x == 0), isTrue);
    // A long season is not cut.
    expect(SeasonCard.sparkValues([for (var i = 1; i <= 20; i++) _day('$i', i, 100.0 * i)]).length, 20);
  });

  testWidgets('a 3-day season renders a 14-slot sparkline — never three fat blocks', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: SeasonCard(
          totals: const SeasonTotals(seasonKey: '2025/26', dayCount: 3, runCount: 15, dropM: 3600, maxSpeedMs: 15),
          days: [_day('a', 5, 1200), _day('b', 12, 1500), _day('c', 20, 900)],
        ),
      ),
    );
    await tester.pump();
    final spark = tester.widget<Sparkline>(find.byType(Sparkline));
    expect(spark.values.length, 14);
    expect(spark.bars, isTrue);
    // Footer labels are real overlines, ready for the overline-first flip.
    expect(find.text('ABFAHRTEN'), findsOneWidget);
    expect(find.text('TOP-SPEED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no days → no sparkline', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SeasonCard(totals: SeasonTotals(seasonKey: '2025/26'), days: [])),
    );
    await tester.pump();
    expect(find.byType(Sparkline), findsNothing);
  });

  testWidgets('a five-digit season with a delta line fits a 393 pt phone', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SeasonCard(
            totals: SeasonTotals(seasonKey: '2026/27', dayCount: 14, runCount: 212, dropM: 118240, maxSpeedMs: 24.1),
            previous: SeasonTotals(seasonKey: '2025/26', dropM: 100000),
            days: [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('118.240'), findsOneWidget);
    expect(find.textContaining('zur Vorsaison'), findsOneWidget);
  });
}
