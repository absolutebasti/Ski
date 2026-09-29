import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/features/today/heute_screen.dart';
import 'package:slopetrack/features/today/season_goal_sheet.dart';
import 'package:slopetrack/features/today/today_strings.dart';

import '../../support/pump.dart';
import 'today_fixtures.dart';

const _season = SeasonTotals(seasonKey: '2025/26', dayCount: 6, runCount: 41, dropM: 18240, maxSpeedMs: 19);

/// Idle Heute with one season and the goal from [settings]; hands back the
/// container so the test can read what the sheet wrote.
Future<ProviderContainer> _pumpIdle(WidgetTester tester, {Settings settings = const Settings()}) async {
  await pumpApp(
    tester,
    const HeuteScreen(),
    overrides: todayOverrides(controller: FakeRecordingController(), days: [daySummary()], totals: const [_season], settings: settings),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(HeuteScreen)));
}

void main() {
  test('snap: grid of 5.000 between 5.000 and 100.000, unset → 20.000', () {
    expect(SeasonGoalSheet.snap(0), 20000);
    expect(SeasonGoalSheet.snap(-5), 20000);
    expect(SeasonGoalSheet.snap(1000), 5000);
    expect(SeasonGoalSheet.snap(12600), 15000);
    expect(SeasonGoalSheet.snap(250000), 100000);
  });

  test('emptyLine has no first person', () {
    for (final locale in AppLocale.supported) {
      final line = TodayStrings(AppLocale(locale)).emptyLine.toLowerCase();
      expect(line.contains(RegExp(r'\bich\b')), isFalse, reason: locale.languageCode);
      expect(line.contains(RegExp(r'\bi\b')), isFalse, reason: locale.languageCode);
    }
    expect(TodayStrings(const AppLocale(Locale('de'))).emptyLine, 'Noch kein Skitag. Ein Tipp auf Tag starten genügt.');
  });

  testWidgets('the goal line opens the sheet; +2 steps and Speichern write 30.000', (tester) async {
    final container = await _pumpIdle(tester);
    expect(find.text('ZIEL 20.000 HM'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('season-goal-line')));
    await tester.pumpAndSettle();
    expect(find.text('Saisonziel'), findsOneWidget);
    expect(find.text('20.000'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mehr'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Mehr'));
    await tester.pump();
    expect(find.text('30.000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('season-goal-save')));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).seasonGoalHm, 30000);
    expect(find.text('Saisonziel'), findsNothing, reason: 'the sheet closed');
    expect(find.text('ZIEL 30.000 HM'), findsOneWidget);
  });

  testWidgets('Kein Ziel writes 0 and hides the goal line', (tester) async {
    final container = await _pumpIdle(tester);
    await tester.tap(find.byKey(const ValueKey('season-goal-line')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('season-goal-none')));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).seasonGoalHm, 0);
    expect(find.byKey(const ValueKey('season-goal-line')), findsNothing);
    expect(find.textContaining('ZIEL'), findsNothing);
  });

  testWidgets('no goal set → no goal line on the card', (tester) async {
    await _pumpIdle(tester, settings: const Settings(seasonGoalHm: 0));
    expect(find.byKey(const ValueKey('season-goal-line')), findsNothing);
    expect(find.text('SAISON 2025/26'), findsOneWidget);
  });

  testWidgets('the stepper stops at the range ends', (tester) async {
    await _pumpIdle(tester, settings: const Settings(seasonGoalHm: 100000));
    await tester.tap(find.byKey(const ValueKey('season-goal-line')));
    await tester.pumpAndSettle();
    expect(find.text('100.000'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Mehr'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('100.000'), findsOneWidget, reason: 'max is 100.000');
  });
}
