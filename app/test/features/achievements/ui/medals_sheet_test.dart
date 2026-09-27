import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';
import 'achievements_fixtures.dart';

void main() {
  testWidgets('sheet lists every medal, dims locked ones and shows the next level', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final a = fixtureAchievements();
    await pumpApp(
      tester,
      Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => MedalsSheet.show(ctx), child: const Text('open')))),
      overrides: achievementsOverrides(a),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Medaillen'), findsOneWidget);
    expect(find.text('Carver'), findsOneWidget);
    expect(find.text('Noch 38 km bis Level 5'), findsOneWidget);
    // The points formula moved here from the Rangliste header.
    expect(find.textContaining('Punkte = hm ÷ 10 + km × 10 + Abfahrten × 5 + 50 pro Tag'), findsOneWidget);
    expect(find.byType(MedalTile), findsNWidgets(a.medals.length));
    for (final m in a.medals) {
      expect(find.text(m.def.titleDe), findsOneWidget, reason: m.def.id);
    }
    final dimmed = tester.widgetList<Opacity>(find.byWidgetPredicate((w) => w is Opacity && w.opacity == MedalsSheet.lockedOpacity));
    expect(dimmed.length, a.medals.where((m) => !m.earned).length);
    // Earned tiles show a date, locked ones do not.
    expect(find.textContaining('Dez.'), findsNWidgets(a.earned.length));
    // Section overlines and thresholds with units.
    expect(find.text('SKITAGE'), findsOneWidget);
    expect(find.text('TOP-SPEED'), findsOneWidget);
    expect(find.text('km/h'), findsNWidgets(8));
    expect(find.text('hm'), findsNWidgets(8));
    expect(find.text('500.000'), findsOneWidget);
  });

  testWidgets('every tile has the fixed height and titles stay on one line', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(tester, const Scaffold(body: MedalsSheetBody()), overrides: achievementsOverrides(fixtureAchievements()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final tiles = find.byType(MedalTile);
    final byRow = <double, List<double>>{};
    for (final e in tiles.evaluate()) {
      final rect = tester.getRect(find.byWidget(e.widget));
      expect(rect.height, MedalTile.height);
      byRow.putIfAbsent(rect.top, () => []).add(rect.height);
    }
    for (final heights in byRow.values) {
      expect(heights.toSet().length, 1);
    }
    for (final t in tester.widgetList<Text>(find.descendant(of: tiles, matching: find.byType(Text)))) {
      expect(t.maxLines ?? 1, 1, reason: t.data);
    }
  });

  testWidgets('tiles carry a screen-reader label with threshold and state', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final a = fixtureAchievements();
    await pumpApp(tester, const Scaffold(body: MedalsSheetBody()), overrides: achievementsOverrides(a));
    await tester.pump();
    final handle = tester.ensureSemantics();

    final earned = tester.getSemantics(find.byKey(const ValueKey('medal-days-bronze'))).label;
    expect(earned, startsWith('days bronze de, 1, '));
    expect(earned, contains('Dez.'));

    final locked = a.medals.firstWhere((m) => !m.earned);
    final lockedLabel = tester.getSemantics(find.byKey(ValueKey('medal-${locked.def.id}'))).label;
    expect(lockedLabel, endsWith('offen, 40 %'));

    final speed = tester.getSemantics(find.byKey(const ValueKey('medal-topSpeed-black'))).label;
    expect(speed, contains('120 km/h'));
    handle.dispose();
  });

  testWidgets('top level shows no next-level line', (tester) async {
    final base = fixtureAchievements();
    final a = Achievements(
      points: base.points,
      level: const LevelState(index: 14, titleDe: 'Black', titleEn: 'Black', distanceM: 12000000, nextAtM: null, progress: 1),
      streak: base.streak,
      medals: base.medals,
      dayCount: base.dayCount,
      distanceM: base.distanceM,
      dropM: base.dropM,
      topSpeedMs: base.topSpeedMs,
      avgSpeedMs: base.avgSpeedMs,
      newMedalIds: const [],
    );
    await pumpApp(tester, const Scaffold(body: MedalsSheetBody()), overrides: achievementsOverrides(a));
    await tester.pump();
    expect(find.text('Höchstes Level'), findsOneWidget);
    expect(find.textContaining('bis Level'), findsNothing);
  });
}
