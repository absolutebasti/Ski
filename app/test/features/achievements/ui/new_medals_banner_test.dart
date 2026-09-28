import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
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

  testWidgets('a single medal renders one solid card without +n', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: NewMedalsBanner(ids: ['streak-gold'])),
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    await tester.pump();
    expect(find.text('NEUE MEDAILLE'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
    final accent = AppColors.of(tester.element(find.byType(NewMedalsBanner))).accent;
    expect(tester.widgetList<SurfaceCard>(find.byType(SurfaceCard)).where((w) => w.fill == accent).length, 1);
  });

  testWidgets('solid: false renders accent-wash cards and no solid champagne', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: NewMedalsBanner(ids: ['streak-gold', 'days-bronze'], solid: false)),
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('NEUE MEDAILLE'), findsNWidgets(2));
    final accent = AppColors.of(tester.element(find.byType(NewMedalsBanner))).accent;
    expect(tester.widgetList<SurfaceCard>(find.byType(SurfaceCard)).where((w) => w.fill == accent), isEmpty);
    expect(find.byWidgetPredicate((w) => w is AppCard && w.tone == CardTone.accent), findsNWidgets(2));
    for (final e in find.byType(AppCard).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, 76);
    }
  });

  testWidgets('no ids renders nothing', (tester) async {
    await pumpApp(tester, const Scaffold(body: NewMedalsBanner(ids: [])), overrides: achievementsOverrides(fixtureAchievements()));
    await tester.pump();
    expect(find.text('NEUE MEDAILLE'), findsNothing);
  });
}
