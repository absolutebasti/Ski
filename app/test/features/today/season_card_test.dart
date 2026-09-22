import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/today/season_card.dart';

import '../../support/pump.dart';

void main() {
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
