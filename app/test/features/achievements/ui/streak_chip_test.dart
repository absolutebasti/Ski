import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';

void main() {
  testWidgets('streak chip is hidden below two days', (tester) async {
    await pumpApp(tester, const Scaffold(body: StreakChip(streak: StreakState(current: 1, longest: 4, lastDayMs: 0))));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('streak chip shows the run length from two days on', (tester) async {
    await pumpApp(tester, const Scaffold(body: StreakChip(streak: StreakState(current: 2, longest: 4, lastDayMs: 0))));
    expect(find.text('2 Tage am Stück'), findsOneWidget);
  });

  testWidgets('compact chip is 26 pt tall and English copy reads in a row', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: Align(alignment: Alignment.topLeft, child: StreakChip(streak: StreakState(current: 5, longest: 5, lastDayMs: 0), compact: true))),
      locale: const Locale('en'),
    );
    expect(find.text('5 days in a row'), findsOneWidget);
    expect(tester.getSize(find.byType(StreakChip)).height, 26);
  });
}
