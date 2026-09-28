import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/days/tage_screen.dart';

import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import 'day_fixtures.dart';
import 'golden_fonts.dart';

const _bests = PersonalBests(
  topSpeedMs: 17,
  topSpeedDayId: 'a',
  biggestDayDropM: 1804,
  biggestDayId: 'a',
  longestRunDropM: 312,
  longestRunDayId: 'a',
);

/// The PB strip on Tage at 375 pt (iPhone SE / mini width). With the short
/// overlines ('LÄNGSTE', 'BESTER TAG') all three labels stay on one line, so
/// the three numerals share one baseline. Re-gold with
/// `flutter test test/features/days --update-goldens`.
void main() {
  setUpAll(loadInterFonts);

  testWidgets('PB tiles share one baseline at 375 pt', (tester) async {
    tester.view.physicalSize = const Size(375, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const RepaintBoundary(key: ValueKey('pb'), child: TageScreen()),
      overrides: screenOverrides(
        days: [summary(id: 'a', startedAt: tsThisSeason, isTopSpeedPb: true, isBiggestDayPb: true)],
        seasons: const [SeasonTotals(seasonKey: '2025/26', dayCount: 1, runCount: 7, dropM: 1804)],
        bests: _bests,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PbTile), findsNWidgets(3));
    expect(find.text('TOP-SPEED'), findsWidgets);
    expect(find.text('BESTER TAG'), findsOneWidget);
    expect(find.text('LÄNGSTE'), findsOneWidget);

    // Every label is a single line …
    for (final label in ['BESTER TAG', 'LÄNGSTE']) {
      expect(tester.getSize(find.text(label)).height, lessThan(20), reason: '$label must not wrap');
    }
    // … so the three numerals sit on one baseline.
    final tiles = find.byType(PbTile);
    final baselines = <double>[
      for (var i = 0; i < 3; i++) tester.getBottomLeft(find.descendant(of: tiles.at(i), matching: find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 22))).dy,
    ];
    expect(baselines.toSet().length, 1, reason: 'numeral bottoms $baselines');
    expect(tester.takeException(), isNull);

    await expectLater(find.byKey(const ValueKey('pb')), matchesGoldenFile('goldens/pb_tiles_375.png'));
  });
}
