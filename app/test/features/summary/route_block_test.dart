import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/summary/route_block.dart';

import '../../support/pump.dart';
import '../days/golden_fonts.dart';
import 'summary_fixture.dart';

/// The route stays clear of the date plate (bottom-left): the painter's route
/// square is inset 34 / 34 / 110 / 34 and the golden shows the result.
/// Re-gold with `flutter test test/features/summary --update-goldens`.
void main() {
  setUpAll(loadInterFonts);

  testWidgets('no route pixel lies inside the date plate', (tester) async {
    tester.view.physicalSize = const Size(390, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final detail = summaryDetail(points: trackPoints());
    await pumpApp(
      tester,
      Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('route'),
          child: RouteBlock(detail: detail, title: 'Tagesbilanz', date: '15. Januar 2026', resort: 'Kitzbühel', noTrackLabel: 'Ohne Track', animate: false),
        ),
      ),
    );
    await tester.pump();

    final paintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RoutePainter);
    expect(paintFinder, findsOneWidget);
    final painter = tester.widget<CustomPaint>(paintFinder).painter! as RoutePainter;
    final canvas = tester.getRect(paintFinder);
    expect(painter.inset, RoutePainter.defaultInset);
    expect(painter.t, 1);

    // The square every route point maps into, in screen coordinates, padded
    // by the widest stroke (glow = 2.8 × stroke width) so edges count too.
    final route = painter.routeRect(canvas.size).shift(canvas.topLeft).inflate(painter.strokeWidth * 2.8 / 2);
    final plate = tester.getRect(find.ancestor(of: find.text('TAGESBILANZ'), matching: find.byType(Container)).first);
    expect(plate.bottom, lessThanOrEqualTo(canvas.bottom - 18));
    expect(route.overlaps(plate), isFalse, reason: 'route $route vs plate $plate');
    expect(route.bottom, lessThanOrEqualTo(canvas.bottom - 110 + painter.strokeWidth * 1.4));

    // Sample the geometry: every mapped point sits inside the route square.
    final square = painter.routeRect(canvas.size).shift(canvas.topLeft);
    for (final s in painter.geometry.strokes) {
      for (final p in s.points) {
        final o = Offset(square.left + p.dx * square.width, square.top + p.dy * square.height);
        expect(square.inflate(0.01).contains(o), isTrue, reason: '$o outside $square');
      }
    }
    expect(tester.takeException(), isNull);

    await expectLater(find.byKey(const ValueKey('route')), matchesGoldenFile('goldens/route_block_plate.png'));
  });

  test('routeRect honours an asymmetric inset', () {
    final geo = RouteGeometry.fromDetail(summaryDetail(points: trackPoints()))!;
    const painter = RoutePainter(t: 1, geometry: RouteGeometry([], Offset.zero, Offset.zero), run: Colors.white, lift: Colors.grey);
    final r = painter.routeRect(const Size(390, 300));
    expect(r.top, greaterThanOrEqualTo(34));
    expect(r.bottom, lessThanOrEqualTo(300 - 110));
    expect(r.width, r.height);
    expect(geo.hasRun, isTrue);
  });
}
