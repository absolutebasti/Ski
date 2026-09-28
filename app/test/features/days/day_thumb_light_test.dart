import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/theme/theme.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/features/days/day_card.dart';
import 'package:slopetrack/features/map/route_colors.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';
import 'golden_fonts.dart';

Future<void> pumpLight(WidgetTester tester, Widget child) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
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

Color thumbColor(WidgetTester tester) {
  final box = tester.widget<Container>(find.descendant(of: find.byType(DayThumb), matching: find.byType(Container)).first);
  return (box.decoration! as ShapeDecoration).color!;
}

/// Light theme: the route ground is warm paper (#EDEAE2), not the dark graphite.
/// Re-gold with `flutter test test/features/days --update-goldens`.
void main() {
  setUpAll(loadInterFonts);

  test('routeGround: graphite in the dark, paper in the light', () {
    expect(AppColors.dark.routeGround, RouteColors.darkGround);
    expect(AppColors.light.routeGround, RouteColors.lightGround);
    expect(RouteColors.isNearBlack(AppColors.dark.routeGround), isTrue);
    expect(RouteColors.isNearBlack(AppColors.light.routeGround), isFalse);
    // The light route is the darker champagne, readable on paper.
    expect(AppColors.light.run.computeLuminance(), lessThan(AppColors.light.routeGround.computeLuminance()));
  });

  testWidgets('light theme: the day thumbnail background is not near-black', (tester) async {
    tester.view.physicalSize = const Size(375, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpLight(
      tester,
      Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('card'),
          child: Padding(padding: const EdgeInsets.all(16), child: DayCard(day: summary(id: 'a', startedAt: tsThisSeason))),
        ),
      ),
    );
    await tester.pump();

    final ground = thumbColor(tester);
    expect(ground, RouteColors.lightGround);
    expect(RouteColors.isNearBlack(ground), isFalse);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('card')), matchesGoldenFile('goldens/day_card_light.png'));
  });

  testWidgets('dark theme keeps the graphite ground', (tester) async {
    await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason))));
    await tester.pump();
    expect(thumbColor(tester), RouteColors.darkGround);
  });
}
