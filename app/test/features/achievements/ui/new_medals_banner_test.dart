import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';
import 'achievements_fixtures.dart';

void main() {
  testWidgets('banner shows at most three medals and a +n line', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final ids = ['streak-gold', 'days-bronze', 'vertical-silver', 'runs-bronze', 'points-bronze'];
    await pumpApp(
      tester,
      Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: NewMedalsBanner(ids: ids))),
      overrides: achievementsOverrides(fixtureAchievements(newMedalIds: ids)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('NEUE MEDAILLE'), findsNWidgets(3));
    expect(find.text('Sieben am Stück'), findsOneWidget);
    expect(find.text('days bronze de'), findsOneWidget);
    expect(find.text('vertical silver de'), findsOneWidget);
    expect(find.text('runs bronze de'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('a single medal renders one card without +n', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: NewMedalsBanner(ids: ['streak-gold'])),
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    await tester.pump();
    expect(find.text('NEUE MEDAILLE'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('no ids renders nothing', (tester) async {
    await pumpApp(tester, const Scaffold(body: NewMedalsBanner(ids: [])), overrides: achievementsOverrides(fixtureAchievements()));
    await tester.pump();
    expect(find.text('NEUE MEDAILLE'), findsNothing);
  });
}
