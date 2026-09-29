import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/achievements_providers.dart';
import 'package:slopetrack/features/achievements/medal_catalog.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../../support/pump.dart';
import '../../days/golden_fonts.dart';

/// The Medaillen sheet with the real catalogue: every title is the same fixed
/// size, no tile repeats its title as the threshold line, and the banner
/// captions a new medal with its hint ('3 Skitage in Folge'), never a bare
/// number. Re-gold with `flutter test test/features/achievements --update-goldens`.
Achievements _real({List<String> newMedalIds = const []}) => Achievements(
      points: 1234,
      level: const LevelState(index: 4, titleDe: 'Carver', titleEn: 'Carver', distanceM: 162000, nextAtM: 200000, progress: 0.62),
      streak: const StreakState(current: 3, longest: 5, lastDayMs: 1766790000000),
      medals: [
        for (final (i, def) in medalCatalog.indexed)
          MedalState(def: def, earnedAt: def.tier == MedalTier.bronze ? 1766790000000 - i * 86400000 : null, progress: def.tier == MedalTier.bronze ? 1 : 0.4),
      ],
      dayCount: 12,
      distanceM: 312000,
      dropM: 48000,
      topSpeedMs: 22,
      avgSpeedMs: 9,
      newMedalIds: newMedalIds,
    );

List<Override> _overrides(Achievements a) => [achievementsProvider.overrideWithValue(a)];

void main() {
  setUpAll(loadInterFonts);

  testWidgets('sheet: uniform 11.5 pt titles, no title repeated as threshold, banner shows the hint', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final a = _real(newMedalIds: const ['streak-bronze']);
    await pumpApp(
      tester,
      Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('medals'),
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: NewMedalsBanner(ids: ['streak-bronze'])),
              const Expanded(child: MedalsSheetBody()),
            ],
          ),
        ),
      ),
      overrides: _overrides(a),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Banner: title + hint caption, no bare '3'.
    expect(find.text('NEUE MEDAILLE'), findsOneWidget);
    expect(find.text('Drei am Stück'), findsWidgets);
    expect(find.text('3 Skitage in Folge'), findsOneWidget);
    expect(find.descendant(of: find.byType(NewMedalsBanner), matching: find.text('3')), findsNothing);
    expect(find.descendant(of: find.byType(NewMedalsBanner), matching: find.byType(Text)), findsNWidgets(3));

    final tiles = find.byType(MedalTile);
    expect(tiles, findsNWidgets(48));
    for (final e in tiles.evaluate()) {
      final tile = e.widget as MedalTile;
      final tileFinder = find.byWidget(tile);
      final texts = tester.widgetList<Text>(find.descendant(of: tileFinder, matching: find.byType(Text))).toList();
      final title = texts.firstWhere((t) => t.data == tile.state.def.titleDe, orElse: () => throw StateError('no title for ${tile.state.def.id}'));
      expect(title.style?.fontSize, MedalTile.titleSize, reason: tile.state.def.id);
      expect(title.style?.fontWeight, FontWeight.w600, reason: tile.state.def.id);
      expect(title.overflow, TextOverflow.ellipsis, reason: tile.state.def.id);
      expect(find.ancestor(of: find.byWidget(title), matching: find.byType(FittedBox)), findsNothing, reason: 'title must not scale');
      final strings = [for (final t in texts) t.data].whereType<String>().toList();
      expect(strings.toSet().length, strings.length, reason: '${tile.state.def.id} repeats a string: $strings');
    }
    // Every SERIE title shares one size.
    final serie = medalsOf(AchievementMetric.streak);
    final sizes = {for (final d in serie) tester.widget<Text>(find.text(d.titleDe).last).style?.fontSize};
    expect(sizes, {MedalTile.titleSize});

    await expectLater(find.byKey(const ValueKey('medals')), matchesGoldenFile('goldens/medals_sheet_real.png'));
  });

  testWidgets('a tile whose threshold equals its title drops the threshold row', (tester) async {
    const def = MedalDef(id: 'days-silver', metric: AchievementMetric.days, tier: MedalTier.silver, threshold: 10, titleDe: '10', titleEn: '10', hintDe: 'h', hintEn: 'h');
    await pumpApp(
      tester,
      const Scaffold(body: SizedBox(width: 90, child: MedalTile(state: MedalState(def: def, earnedAt: null, progress: 0.2)))),
      overrides: _overrides(_real()),
    );
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
  });
}
