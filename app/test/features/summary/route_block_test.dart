import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/map/map_images.dart';
import 'package:slopetrack/features/map/map_overlay.dart';
import 'package:slopetrack/features/map/map_region.dart';
import 'package:slopetrack/features/map/thumbnail_renderer.dart';
import 'package:slopetrack/features/days/day_card.dart' show ContourPattern;
import 'package:slopetrack/features/summary/route_block.dart';

import '../../support/pump.dart';
import '../days/golden_fonts.dart';
import 'summary_fixture.dart';

/// The route stays clear of the date plate (bottom-left): the painter's route
/// square is inset 34 / 34 / 130 / 34 and the golden shows the result.
/// Re-gold with `flutter test test/features/summary --update-goldens`.
/// A deterministic stand-in for an Apple satellite tile: forest, meadow and
/// rock patches on a dark green ground plus a white block where MapKit stamps
/// the Apple wordmark, so the golden shows the route on imagery and the
/// uncovered wordmark without any network.
Future<Uint8List> fakeSatellite(Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2F3B27));
  final rnd = math.Random(7);
  const tones = [Color(0xFF45563A), Color(0xFF6B6A58), Color(0xFF8A8C86), Color(0xFF243020), Color(0xFFB9BDB8)];
  for (var i = 0; i < 90; i++) {
    final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
    final r = 8 + rnd.nextDouble() * 46;
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * (0.6 + rnd.nextDouble())), Paint()..color = tones[i % tones.length].withValues(alpha: 0.55));
  }
  canvas.drawRect(Rect.fromLTWH(15, size.height - 26, 49, 15), Paint()..color = const Color(0xFFFFFFFF));
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// The hero as a 375 pt phone requests it (shown 1:1 in the golden).
final hero375 = ThumbnailRenderer.heroSizeFor(375);

/// A finished day whose `<id>_hero.png` + frame sit in [dir], framed exactly
/// as ThumbnailRenderer.renderMap frames them.
DayDetail detailWithHero(Directory dir, Uint8List png, {List<TrackPoint>? points}) {
  final base = summaryDetail(points: points ?? trackPoints());
  final path = '${dir.path}/day-1.png';
  final region = MapGeo.fit(ThumbnailRenderer.mapBounds(base, resort: const Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 3))!, hero375, inset: ThumbnailRenderer.heroInset);
  File(ThumbnailRenderer.heroPathFor(path)).writeAsBytesSync(png);
  File(ThumbnailRenderer.heroFramePathFor(path)).writeAsStringSync(MapFrame(region: region, size: hero375).encode());
  final d = base.day;
  return DayDetail(
    day: DayRecord(
      id: d.id, startedAt: d.startedAt, endedAt: d.endedAt, status: d.status, resortId: d.resortId,
      resortName: d.resortName, lastFixAt: d.lastFixAt, stats: d.stats, mapThumbPath: path,
    ),
    segments: base.segments,
    points: base.points,
  );
}

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
    expect(plate.bottom, lessThanOrEqualTo(canvas.bottom - RouteBlock.plateBottom));
    expect(route.overlaps(plate), isFalse, reason: 'route $route vs plate $plate');
    expect(route.bottom, lessThanOrEqualTo(canvas.bottom - 130 + painter.strokeWidth * 1.4));

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

  group('satellite ground', () {
    late Directory dir;
    late Uint8List png;
    setUpAll(() async => png = await fakeSatellite(hero375));
    setUp(() => dir = Directory.systemTemp.createTempSync('slopetrack_hero_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> pumpBlock(WidgetTester tester, DayDetail detail) async {
      // Decode into the image cache before the widget asks for it: a load
      // started inside the fake-async zone would never finish.
      final file = File(ThumbnailRenderer.heroPathFor(detail.day.mapThumbPath!));
      await tester.runAsync(() async {
        final done = Completer<void>();
        FileImage(file).resolve(ImageConfiguration.empty).addListener(ImageStreamListener((_, _) => done.complete(), onError: (e, _) => done.completeError(e)));
        await done.future;
      });
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
    }

    testWidgets('satellite image under the projected route at 375 pt (golden)', (tester) async {
      tester.view.physicalSize = const Size(375, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final detail = detailWithHero(dir, png);
      await pumpBlock(tester, detail);

      final image = tester.widget<Image>(find.descendant(of: find.byType(RouteBlock), matching: find.byType(Image)));
      expect((image.image as FileImage).file.path, endsWith('day-1_hero.png'));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.bottomLeft); // the wordmark corner is never cropped
      expect(find.text('Karten: © Apple'), findsOneWidget);

      final paintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RoutePainter);
      final painter = tester.widget<CustomPaint>(paintFinder).painter! as RoutePainter;
      final canvas = tester.getRect(paintFinder);
      expect(painter.imageSize, hero375);
      // Rendered for this 375 pt screen: the image is shown 1:1, exactly like
      // Image(fit: BoxFit.cover, alignment: bottomLeft) lays it out.
      final cover = painter.routeRect(canvas.size);
      expect(cover, Offset.zero & canvas.size);

      // Every route point lands where the image shows it, clear of the date plate.
      final plate = tester.getRect(find.ancestor(of: find.text('TAGESBILANZ'), matching: find.byType(Container)).first);
      final frame = ThumbnailRenderer.heroFrameFor(detail.day.mapThumbPath)!;
      for (final p in detail.points) {
        final u = frame.region.project(p.lat!, p.lon!);
        final o = Offset(cover.left + u.dx * cover.width, cover.top + u.dy * cover.height) + canvas.topLeft;
        expect(canvas.contains(o), isTrue);
        expect(plate.inflate(2).contains(o), isFalse, reason: '$o inside plate $plate');
        expect(o.dy, lessThanOrEqualTo(canvas.bottom - 130 + 0.01));
      }

      // The Apple wordmark (bottom-left) is whole and uncovered: the plate and
      // every text end above it, the scrim opens its window exactly there.
      final wordmark = AppleWordmark.rectIn(canvas, 1);
      expect(wordmark.left, greaterThanOrEqualTo(canvas.left));
      expect(plate.bottom, lessThanOrEqualTo(wordmark.top - 4));
      for (final e in find.descendant(of: find.byType(RouteBlock), matching: find.byType(Text)).evaluate()) {
        final box = e.renderObject! as RenderBox;
        final r = box.localToGlobal(Offset.zero) & box.size;
        expect(r.overlaps(wordmark), isFalse, reason: '${(e.widget as Text).data} $r over the wordmark $wordmark');
      }
      final scrim = tester.widget<CustomPaint>(find.byKey(RouteBlock.scrimKey)).painter! as WordmarkScrim;
      expect(scrim.wordmarkIn(canvas.size), AppleWordmark.rectIn(Offset.zero & canvas.size, 1));
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('route')), matchesGoldenFile('goldens/route_block_satellite.png'));
    });

    testWidgets('a frame without its image falls back to the ink ground', (tester) async {
      final detail = detailWithHero(dir, png);
      File(ThumbnailRenderer.heroPathFor(detail.day.mapThumbPath!)).deleteSync();
      await pumpApp(tester, Scaffold(body: RouteBlock(detail: detail, title: 'Tagesbilanz', date: 'x', noTrackLabel: 'Ohne Track', animate: false)));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      final painter = tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RoutePainter)).painter! as RoutePainter;
      expect(painter.imageSize, isNull);
      expect(painter.inset, RoutePainter.defaultInset);
      expect(find.text('Karten: © Apple'), findsNothing);
    });

    testWidgets('the satellite ground replaces the ink when the snapshot lands later (revision bump)', (tester) async {
      final detail = detailWithHero(dir, png);
      final hero = File(ThumbnailRenderer.heroPathFor(detail.day.mapThumbPath!));
      final frame = File(ThumbnailRenderer.heroFramePathFor(detail.day.mapThumbPath!));
      // Opened right after End: nothing on disk yet.
      final heroBytes = hero.readAsBytesSync(), frameJson = frame.readAsStringSync();
      hero.deleteSync();
      frame.deleteSync();
      await pumpApp(tester, Scaffold(body: RouteBlock(detail: detail, title: 'Tagesbilanz', date: 'x', noTrackLabel: 'Ohne Track', animate: false)));
      await tester.pump();
      RoutePainter painter() => tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RoutePainter)).painter! as RoutePainter;
      expect(find.byType(Image), findsNothing);
      expect(painter().imageSize, isNull);

      // MapImages writes the files a few seconds later and bumps the revision.
      hero.writeAsBytesSync(heroBytes);
      frame.writeAsStringSync(frameJson);
      await tester.runAsync(() async {
        final done = Completer<void>();
        FileImage(hero).resolve(ImageConfiguration.empty).addListener(ImageStreamListener((_, _) => done.complete(), onError: (e, _) => done.completeError(e)));
        await done.future;
      });
      ProviderScope.containerOf(tester.element(find.byType(RouteBlock))).read(mapImageRevisionProvider.notifier).bump();
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(painter().imageSize, hero375);
      expect(find.text('Karten: © Apple'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no track but a resort snapshot: imagery + the no-track line', (tester) async {
      final detail = detailWithHero(dir, png, points: const []);
      await pumpBlock(tester, detail);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ContourPattern), findsNothing);
      expect(find.text('OHNE TRACK'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is RoutePainter), findsNothing);
    });
  });
}
