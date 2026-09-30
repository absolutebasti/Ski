import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/features/onboarding/onboarding.dart';

import '../../support/fakes.dart';
import '../../support/pump.dart';
import '../../support/screen_overrides.dart';
import '../days/golden_fonts.dart';

/// Onboarding P1 layout (docs/BACKLOG-2.md UX-ONBOARDING-A11Y): the rider stands
/// 160–200 pt tall over the hook card, the block is centred between pager and
/// dock with no dead band > 60 pt, and under reduced motion the route and the
/// numerals are final on the first frame.
/// Re-gold with `flutter test test/features/onboarding --update-goldens`.
Future<void> _pumpFlow(WidgetTester tester, {Size size = const Size(393, 852)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const RepaintBoundary(key: ValueKey('p1'), child: OnboardingFlow(deviceCountry: 'AT')),
    overrides: [
      ...screenOverrides(permissions: FakePermissionService()),
      onboardingSignInProvider.overrideWithValue(() async => null),
    ],
  );
}

RoutePainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.descendant(of: find.byType(RouteHook), matching: find.byType(CustomPaint))).painter! as RoutePainter;

void main() {
  setUpAll(loadInterFonts);

  testWidgets('P1 at 393×852: rider ≥ 160 pt over the card, no dead band > 60 pt above the dock', (tester) async {
    await _pumpFlow(tester);
    await tester.runAsync(() => precacheImage(const AssetImage('assets/mascot/rider-hero.png'), tester.element(find.byType(Rider))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final rider = tester.getRect(find.byType(Rider));
    final card = tester.getRect(find.byType(SurfaceCard).first);
    final dock = tester.getRect(find.byType(BottomDock));
    final page = tester.getRect(find.byType(PageView));
    expect(rider.height, greaterThanOrEqualTo(HookPage.riderMin));
    expect(rider.height, lessThanOrEqualTo(HookPage.riderMax));
    expect(card.top, closeTo(rider.bottom - HookPage.riderOverlap, 0.5), reason: 'rider stands 24 pt into the card');
    expect(dock.top - card.bottom, lessThanOrEqualTo(60), reason: 'dead band card→dock');
    expect(dock.top - card.bottom, greaterThanOrEqualTo(24), reason: 'card keeps its bottom margin');
    // Centred inside the page area (header row above, dock below): the free
    // space above the headline mirrors the space under the card (± the fixed 12/24 page padding).
    expect(page.bottom, closeTo(dock.top, 0.5));
    final headline = tester.getRect(find.text('Fahren. Zählen. Gewinnen.'));
    final above = headline.top - page.top, below = page.bottom - card.bottom;
    expect((above - 12) - (below - 24), closeTo(0, 2), reason: 'above=$above below=$below');
    expect(find.byType(ListView), findsNothing, reason: 'P1 is a Column, not a ListView');
    expect(_painter(tester).t, 1);

    await expectLater(find.byKey(const ValueKey('p1')), matchesGoldenFile('goldens/hook_page_393.png'));
  });

  testWidgets('small phone at 1.3× text falls back to scrolling without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpFlow(tester, size: const Size(375, 667));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rider = tester.getRect(find.byType(Rider));
    expect(rider.height, HookPage.riderMin);
    expect(find.text('4.120'), findsOneWidget);
    // The card ends below the dock → the page scrolls.
    final card = tester.getRect(find.byType(SurfaceCard).first);
    final dock = tester.getRect(find.byType(BottomDock));
    expect(card.bottom, greaterThan(dock.top));
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SurfaceCard).first).bottom, lessThan(card.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: route fully drawn and numerals final on the first frame', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpFlow(tester);
    // No extra pump: this is the first frame.
    expect(_painter(tester).t, 1);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4.120'), findsOneWidget);
    expect(find.text('68'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).t, 1);
    expect(find.text('4.120'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal motion: route and numerals start at zero and land on their targets', (tester) async {
    await _pumpFlow(tester);
    expect(_painter(tester).t, 0);
    expect(find.text('4.120'), findsNothing);
    await tester.pumpAndSettle();
    expect(_painter(tester).t, 1);
    expect(find.text('4.120'), findsOneWidget);
  });

  testWidgets('RouteHook(animate: false) is complete at once', (tester) async {
    await pumpApp(tester, const Scaffold(body: RouteHook(animate: false)));
    expect(_painter(tester).t, 1);
  });
}
