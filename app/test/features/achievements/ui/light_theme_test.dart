import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/theme/theme.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import 'achievements_fixtures.dart';

/// The light theme must stay correct (docs/DESIGN.md §1): the numeral in the
/// level ring has to be visible on its disc and the medal grid has to line up.
Future<void> pumpThemed(WidgetTester tester, Widget child, {required Brightness brightness, List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildTheme(brightness),
        locale: const Locale('de'),
        supportedLocales: AppLocale.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  await tester.pump();
}

BoxDecoration _disc(WidgetTester tester) => tester
    .widget<Container>(
      find.descendant(
        of: find.byType(LevelRing),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle),
      ),
    )
    .decoration! as BoxDecoration;

Color? _numeral(WidgetTester tester) => tester.widget<Text>(find.descendant(of: find.byType(LevelRing), matching: find.text('4'))).style?.color;

void main() {
  testWidgets('light: the level numeral is not drawn in the disc colour', (tester) async {
    await pumpThemed(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      brightness: Brightness.light,
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    final c = AppColors.of(tester.element(find.byType(LevelRing)));
    expect(c.isDark, isFalse);
    final disc = _disc(tester).color;
    expect(disc, c.surfaceRaised);
    expect(disc, isNot(c.ink));
    expect(_numeral(tester), isNotNull);
    expect(_numeral(tester), isNot(disc));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark: the disc stays ink and the numeral differs from it', (tester) async {
    await pumpThemed(
      tester,
      const Scaffold(body: SafeArea(child: AchievementsHeader())),
      brightness: Brightness.dark,
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    final c = AppColors.of(tester.element(find.byType(LevelRing)));
    expect(c.isDark, isTrue);
    expect(_disc(tester).color, c.ink);
    expect(_numeral(tester), isNot(_disc(tester).color));
  });

  testWidgets('light: medal tiles in a row share one height', (tester) async {
    await pumpThemed(
      tester,
      const Scaffold(body: MedalsSheetBody()),
      brightness: Brightness.light,
      overrides: achievementsOverrides(fixtureAchievements()),
    );
    expect(tester.takeException(), isNull);
    final byRow = <double, Set<double>>{};
    for (final e in find.byType(MedalTile).evaluate()) {
      final rect = tester.getRect(find.byWidget(e.widget));
      byRow.putIfAbsent(rect.top, () => {}).add(rect.height);
    }
    expect(byRow, isNotEmpty);
    for (final heights in byRow.values) {
      expect(heights.length, 1);
      expect(heights.single, MedalTile.height);
    }
  });
}
