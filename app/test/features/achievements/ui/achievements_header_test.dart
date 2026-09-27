import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';
import 'achievements_fixtures.dart';

void main() {
  testWidgets('header renders level, points, streak and medal count', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(find.text('PUNKTE'), findsOneWidget);
    expect(find.text('1.234'), findsOneWidget);
    expect(find.text('3 Tage am Stück'), findsOneWidget);
    expect(find.text('312 km'), findsOneWidget);
    expect(find.text('7 / 48 Medaillen'), findsOneWidget);
    expect(find.textContaining('Punkte = hm ÷ 10'), findsOneWidget);
    expect(find.byType(LevelRing), findsOneWidget);
  });

  testWidgets('tapping the header opens the medals sheet', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    await tester.pump();
    await tester.tap(find.byType(AchievementsHeader));
    await tester.pumpAndSettle();

    expect(find.text('Medaillen'), findsOneWidget);
    expect(find.byType(MedalsSheetBody), findsOneWidget);
  });

  testWidgets('streak chip stays hidden in the header below two days', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      overrides: achievementsOverrides(fixtureAchievements(streak: 1)),
    );
    await tester.pump();
    expect(find.textContaining('am Stück'), findsNothing);
  });
}
