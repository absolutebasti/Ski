import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';
import 'achievements_fixtures.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, {int streak = 3, Locale locale = const Locale('de')}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      overrides: achievementsOverrides(fixtureAchievements(streak: streak)),
      locale: locale,
    );
    await tester.pump();
  }

  testWidgets('header renders level, next-level line, points and the three columns', (tester) async {
    await pumpHeader(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(find.text('noch 38 km bis Level 5'), findsOneWidget);
    expect(find.text('PUNKTE'), findsOneWidget);
    expect(find.text('1.234'), findsOneWidget);
    expect(find.text('Level nach km · Punkte für die Rangliste'), findsOneWidget);
    expect(find.byType(LevelRing), findsOneWidget);

    // SERIE · KM · MEDAILLEN as a fixed three-column row, overline above numeral.
    expect(find.text('SERIE'), findsOneWidget);
    expect(find.text('KM'), findsOneWidget);
    expect(find.text('MEDAILLEN'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tage'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('7 / 48'), findsOneWidget);
    final serie = tester.getTopLeft(find.text('SERIE'));
    final km = tester.getTopLeft(find.text('KM'));
    final medals = tester.getTopLeft(find.text('MEDAILLEN'));
    expect(serie.dy, km.dy);
    expect(km.dy, medals.dy);
    expect(serie.dx, lessThan(km.dx));
    expect(km.dx, lessThan(medals.dx));
  });

  testWidgets('header has no Wrap, no chips and no formula caption', (tester) async {
    await pumpHeader(tester);
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(StreakChip), findsNothing);
    expect(find.textContaining('Punkte = hm'), findsNothing);
    expect(find.textContaining('am Stück'), findsNothing);
  });

  testWidgets('a broken streak shows a dash, one day the singular', (tester) async {
    await pumpHeader(tester, streak: 0);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('Tage'), findsNothing);
    expect(find.text('Tag'), findsNothing);
  });

  testWidgets('one streak day uses the singular unit', (tester) async {
    await pumpHeader(tester, streak: 1);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Tag'), findsOneWidget);
  });

  testWidgets('English copy', (tester) async {
    await pumpHeader(tester, locale: const Locale('en'));
    expect(find.text('LEVEL 4 · CARVER'), findsOneWidget);
    expect(find.text('38 km to level 5'), findsOneWidget);
    expect(find.text('Level by km · points for the leaderboard'), findsOneWidget);
    expect(find.text('STREAK'), findsOneWidget);
    expect(find.text('MEDALS'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
  });

  testWidgets('tapping the header opens the medals sheet with the formula', (tester) async {
    await pumpHeader(tester);
    await tester.tap(find.byType(AchievementsHeader));
    await tester.pumpAndSettle();

    expect(find.text('Medaillen'), findsOneWidget);
    expect(find.byType(MedalsSheetBody), findsOneWidget);
    expect(find.textContaining('Punkte = hm ÷ 10'), findsOneWidget);
  });

  testWidgets('the level ring announces level, title and progress', (tester) async {
    // Standalone: exact label. In the header the card is one button, so the
    // ring's label merges into the card node.
    await pumpApp(tester, Scaffold(body: LevelRing(level: fixtureAchievements().level)));
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.byType(LevelRing)).label, 'Level 4 Carver, 62 % bis Level 5');
    handle.dispose();
  });

  testWidgets('the header card node carries the ring label', (tester) async {
    await pumpHeader(tester);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(r'Level 4 Carver, 62 % bis Level 5')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Medaillen öffnen')), findsOneWidget);
    handle.dispose();
  });
}
