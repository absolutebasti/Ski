import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/account/account.dart';
import 'package:slopetrack/features/achievements/ui/ui.dart';

import '../../support/pump.dart';
import '../achievements/ui/achievements_fixtures.dart';
import '../days/golden_fonts.dart';

/// The signed-out profile page at iPhone size: rider line, three benefits,
/// Apple button, 'Ohne Konto weiter', then the device level card and the
/// season goal — the page scrolls, nothing below the fold is empty.
/// Re-gold with `flutter test test/features/account --update-goldens`.
List<Override> _overrides() => [
      accountAvailableProvider.overrideWithValue(true),
      authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(null)),
      profileApiProvider.overrideWithValue(null),
      accountSignInProvider.overrideWithValue(() async => null),
      settingsProvider.overrideWith(() => SettingsNotifier(null, initial: const Settings(onboardingDone: true, countryCode: 'AT', seasonGoalHm: 25000))),
      ...achievementsOverrides(fixtureAchievements()),
    ];

/// The Apple glyph and the benefit icons are Material icons; without the font
/// the golden shows boxes. `flutter test` sets FLUTTER_ROOT.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

void main() {
  setUpAll(() async {
    await loadInterFonts();
    await _loadMaterialIcons();
  });

  testWidgets('signed-out profile page golden (390×844, dark)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, const RepaintBoundary(key: ValueKey('page'), child: ProfilePage()), overrides: _overrides());
    // The rider PNG decodes off the fake-async zone; cache it, then pump.
    await tester.runAsync(() => precacheImage(const AssetImage('assets/mascot/rider-look.png'), tester.element(find.byType(ProfilePage))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('account-signed-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-benefit-backup')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-level')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-season-goal')), findsOneWidget);
    expect(find.byType(LevelRing), findsOneWidget);

    // No empty lower half: the content runs past the viewport.
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent, greaterThan(0));

    await expectLater(find.byKey(const ValueKey('page')), matchesGoldenFile('goldens/profile_page_signed_out.png'));
  });

  for (final locale in const [Locale('de'), Locale('en')]) {
    testWidgets('signed-out page fits an iPhone SE at the 1.3 text-scale cap (${locale.languageCode})', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        const MediaQuery(data: MediaQueryData(size: Size(375, 667), textScaler: TextScaler.linear(1.3)), child: ProfilePage()),
        overrides: _overrides(),
        locale: locale,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no row may overflow');
      expect(find.byKey(const ValueKey('account-continue')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-season-goal')), findsOneWidget);
    });
  }
}
