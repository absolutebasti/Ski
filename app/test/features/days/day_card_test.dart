import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/features/days/day_card.dart';
import 'package:slopetrack/features/map/map_images.dart';
import 'package:slopetrack/features/map/map_overlay.dart';
import 'package:slopetrack/features/map/thumbnail_renderer.dart';

import '../../support/pump.dart';
import 'day_fixtures.dart';

/// Records [ensure] calls instead of asking MapKit.
class RecordingMapImages extends MapImages {
  RecordingMapImages(super.ref, this.ensured);
  final List<String> ensured;

  @override
  void ensure(String dayId) => ensured.add(dayId);
}

void main() {
  testWidgets('a day without a thumbnail file falls back to the placeholder', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: '/does/not/exist.png'))),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ContourPattern), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rendered map PNG is shown on the card', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('slopetrack-days-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/thumb.png');

    await tester.runAsync(() async {
      final png = await ThumbnailRenderer.renderPng(syntheticDayDetail(), width: 120, height: 80);
      await file.writeAsBytes(png, flush: true);
    });

    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: file.path))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.downhill_skiing_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('satellite map image', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('slopetrack-daymap-'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<String> write(WidgetTester tester, String name) async {
      final file = File('${tmp.path}/$name');
      await tester.runAsync(() async {
        await file.writeAsBytes(await ThumbnailRenderer.renderPng(syntheticDayDetail(), width: 60, height: 28), flush: true);
      });
      return file.path;
    }

    String? imagePath(WidgetTester tester) {
      final image = tester.widget<Image>(find.byType(Image));
      return image.image is FileImage ? (image.image as FileImage).file.path : null;
    }

    testWidgets('<id>_map.png wins: Image.file under the graphite scrim, full-width text', (tester) async {
      final base = await write(tester, 'a.png');
      final map = await write(tester, 'a_map.png');
      await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: base))));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(imagePath(tester), map);
      final scrim = tester.widget<CustomPaint>(find.byKey(DayCard.scrimKey)).painter! as WordmarkScrim;
      final gradient = scrim.gradient;
      expect(scrim.imageSize, isNotNull); // the window over the Apple wordmark is open
      expect(gradient.begin, Alignment.bottomCenter); // bottom-up: the numerals sit on the dense end
      expect(gradient.colors.first, AppColors.dark.routeGround.withValues(alpha: 0.94));
      expect(gradient.colors.first.a, greaterThan(gradient.colors.last.a));
      expect(find.byType(DayThumb), findsNothing);
      expect(find.byType(ContourPattern), findsNothing);
      expect(find.text('Karten: © Apple'), findsOneWidget);
      // No hero flight: the day detail opens on a different map.
      expect(find.byType(Hero), findsNothing);
      expect(tester.takeException(), isNull);
    });

    Future<Rect> pumpCard(WidgetTester tester, String base, {double textScale = 1}) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.topCenter, child: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, mapThumbPath: base))),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(AppCard)).width, 335);
      // The map ground inside the card's 0.5 pt hairline.
      return tester.getRect(find.descendant(of: find.byType(AppCard), matching: find.byType(LayoutBuilder)).first);
    }

    /// Band on top, text in the middle, nothing over the Apple wordmark.
    void expectCardGeometry(WidgetTester tester, Rect card, double textScale) {
      final t = TextScaler.linear(textScale);
      // The layout is exactly the size the renderer requests for this phone
      // (MapCardGeometry mirrors the text column; a drift shows up here).
      expect(card.width, MapCardGeometry.width(375));
      expect(card.height, closeTo(MapCardGeometry.height(t), 0.01));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.alignment, Alignment.bottomLeft); // the wordmark corner is never cropped
      expect(image.fit, BoxFit.cover);
      expect(tester.getRect(find.byType(Image)), card); // 1:1, no hidden strip

      final title = tester.getRect(find.textContaining('Jan'));
      expect(title.top - card.top, greaterThanOrEqualTo(MapCardGeometry.band + MapCardGeometry.bandGap - 0.01));
      final wordmark = AppleWordmark.rectIn(card, 1);
      for (final e in find.descendant(of: find.byType(DayCard), matching: find.byType(Text)).evaluate()) {
        final box = e.renderObject! as RenderBox;
        final r = box.localToGlobal(Offset.zero) & box.size;
        expect(r.overlaps(wordmark), isFalse, reason: '${(e.widget as Text).data} $r over the wordmark $wordmark');
      }
      expect(tester.getRect(find.text('ABFAHRTEN')).bottom, lessThanOrEqualTo(wordmark.top - 2));

      // The scrim's window sits exactly on the wordmark.
      final scrim = tester.widget<CustomPaint>(find.byKey(DayCard.scrimKey)).painter! as WordmarkScrim;
      expect(scrim.wordmarkIn(card.size), AppleWordmark.rectIn(Offset.zero & card.size, 1));
      expect(tester.takeException(), isNull);
    }

    testWidgets('335 pt card: 176 pt, image 1:1 bottom-left, route band on top, wordmark strip free', (tester) async {
      final base = await write(tester, 'a.png');
      await write(tester, 'a_map.png');
      final card = await pumpCard(tester, base);
      expect(card.height, MapCardGeometry.minHeight);
      expectCardGeometry(tester, card, 1);
    });

    testWidgets('larger text (app cap 1.3) grows the middle: band and wordmark strip stay free', (tester) async {
      final base = await write(tester, 'a.png');
      await write(tester, 'a_map.png');
      final card = await pumpCard(tester, base, textScale: MapCardGeometry.maxTextScale);
      expect(card.height, greaterThan(MapCardGeometry.minHeight));
      expectCardGeometry(tester, card, MapCardGeometry.maxTextScale);
    });

    testWidgets('a card without <id>_map.png asks MapImages.ensure; one with it does not', (tester) async {
      final ensured = <String>[];
      final base = await write(tester, 'b.png');
      final withMap = await write(tester, 'm.png');
      await write(tester, 'm_map.png');
      await pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: [
              DayCard(day: summary(id: 'b', startedAt: tsThisSeason, mapThumbPath: base)),
              DayCard(day: summary(id: 'm', startedAt: tsThisSeason, mapThumbPath: withMap)),
            ],
          ),
        ),
        overrides: [mapImagesProvider.overrideWith((ref) => RecordingMapImages(ref, ensured))],
      );
      await tester.pump();
      expect(ensured, ['b']);
    });

    testWidgets('a map image landing later shows after the revision bump', (tester) async {
      final base = await write(tester, 'c.png');
      await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'c', startedAt: tsThisSeason, mapThumbPath: base))));
      await tester.pump();
      expect(find.byType(DayThumb), findsOneWidget);
      expect(find.byKey(DayCard.scrimKey), findsNothing);

      final map = await write(tester, 'c_map.png');
      ProviderScope.containerOf(tester.element(find.byType(DayCard))).read(mapImageRevisionProvider.notifier).bump();
      await tester.pump();
      expect(find.byKey(DayCard.scrimKey), findsOneWidget);
      expect(imagePath(tester), map);
      expect(find.byType(DayThumb), findsNothing);
    });

    testWidgets('without the map image the path PNG shows in the thumb tile', (tester) async {
      final base = await write(tester, 'b.png');
      await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'b', startedAt: tsThisSeason, mapThumbPath: base))));
      await tester.pump();
      expect(find.byType(DayThumb), findsOneWidget);
      expect(imagePath(tester), base);
      expect(find.byKey(DayCard.scrimKey), findsNothing);
      expect(find.text('Karten: © Apple'), findsNothing);
    });

    testWidgets('neither file: the contour pattern', (tester) async {
      await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'c', startedAt: tsThisSeason, mapThumbPath: '${tmp.path}/c.png'))));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(DayCard.scrimKey), findsNothing);
      expect(find.byType(ContourPattern), findsOneWidget);
    });

    testWidgets('a map image for a day without a path PNG (no-track day) still shows', (tester) async {
      final map = await write(tester, 'd_map.png');
      await pumpApp(tester, Scaffold(body: DayCard(day: summary(id: 'd', startedAt: tsThisSeason, mapThumbPath: '${tmp.path}/d.png'))));
      await tester.pump();
      expect(imagePath(tester), map);
      expect(DayCard.mapImagePath(null), isNull);
      expect(DayCard.mapImagePath(''), isNull);
    });
  });

  testWidgets('no resort falls back to "Freies Gelände"', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: DayCard(day: summary(id: 'a', startedAt: tsThisSeason, resortName: null))),
    );
    await tester.pump();
    expect(find.text('Freies Gelände'), findsOneWidget);
  });
}
