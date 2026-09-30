import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/map/map_overlay.dart';
import 'package:slopetrack/features/map/map_region.dart';
import 'package:slopetrack/features/map/thumbnail_renderer.dart';
import 'package:slopetrack/platform/map_snapshot.dart';

import 'track_fixture.dart';

/// 5 000 zig-zag points across ~3 km — more than the channel's 500-point budget.
DayDetail longDetail({String id = 'long'}) {
  final pts = [
    for (var i = 0; i < 5000; i++)
      TrackPoint(
        ts: 1735288800000 + i * 1000,
        lat: 47.44 + i * 0.000004 + math.sin(i / 40) * 0.002,
        lon: 12.38 + i * 0.000006 + math.cos(i / 55) * 0.003,
        accepted: true,
        state: MotionState.run,
      ),
  ];
  return DayDetail(
    day: DayRecord(id: id, startedAt: pts.first.ts, endedAt: pts.last.ts, status: DayStatus.finished, stats: DayStats.empty),
    segments: const [],
    points: pts,
  );
}

DayDetail emptyDetail({String id = 'empty', String? resortId}) => DayDetail(
      day: DayRecord(id: id, startedAt: 0, endedAt: 1, status: DayStatus.finished, stats: DayStats.empty, resortId: resortId),
      segments: const [],
      points: const [],
    );

const kitz = Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.4467, lon: 12.3925, radiusKm: 3);

double mercSpan(MapRegion r) => MapGeo.mercY(r.north) - MapGeo.mercY(r.south);

bool inside(MapRegion r, double lat, double lon) => lat <= r.north && lat >= r.south && lon >= r.west && lon <= r.east;

/// The day card and the hero as a 402 pt phone shows them (default text size).
const card402 = Size(361, 176);
final hero402 = ThumbnailRenderer.heroSizeFor(402);

void main() {
  late Directory dir;
  late Uint8List png;

  setUpAll(() async {
    png = await ThumbnailRenderer.renderPng(fixtureDetail(), width: 8, height: 4);
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('slopetrack_map_'));
  tearDown(() => dir.deleteSync(recursive: true));

  MapRegion regionOf(MapSnapshotRequest r) =>
      MapRegion(north: r.lat + r.latSpan / 2, south: r.lat - r.latSpan / 2, west: r.lon - r.lonSpan / 2, east: r.lon + r.lonSpan / 2);

  test('renderMap writes <id>_map.png, the hero image and its frame', () async {
    final fake = FakeMapSnapshotSource(bytes: png);
    final path = await ThumbnailRenderer.renderMap(fixtureDetail(dayId: 'abc'), source: fake, dir: dir, cardSize: card402, heroSize: hero402);
    expect(path, '${dir.path}/thumbs/abc_map.png');
    expect(File(path!).readAsBytesSync(), png);
    expect(File('${dir.path}/thumbs/abc_hero.png').existsSync(), isTrue);
    final frame = ThumbnailRenderer.heroFrameFor('${dir.path}/thumbs/abc.png');
    expect(frame, isNotNull);
    expect(frame!.size, hero402);
    expect(ThumbnailRenderer.basePathForMap(path), '${dir.path}/thumbs/abc.png');

    expect(fake.requests, hasLength(2));
    final card = fake.requests.firstWhere((r) => r.route.isNotEmpty);
    final hero = fake.requests.firstWhere((r) => r.route.isEmpty);
    // Exactly the card as shown on a 402 pt phone (362 − 2 × 0.5 hairline) × 176, at 2×.
    expect((card.width, card.height, card.scale), (361.0, 176.0, 2.0));
    expect((hero.width, hero.height), (402.0, 300.0));
    expect(card.style, MapSnapshotStyle.satellite);
    expect(card.routeColor, 0xFFE3C88C);
    // The stored frame is exactly the region the hero was requested for.
    expect(frame.region.lat, closeTo(hero.lat, 1e-9));
    expect(frame.region.lonSpan, closeTo(hero.lonSpan, 1e-9));
  });

  test('the card region contains the track bbox padded 20 % and hugs it on one axis', () async {
    final detail = longDetail();
    final fake = FakeMapSnapshotSource(bytes: png);
    await ThumbnailRenderer.renderMap(detail, source: fake, dir: dir, cardSize: card402, heroSize: hero402);
    final card = fake.requests.firstWhere((r) => r.route.isNotEmpty);
    final region = regionOf(card);

    final raw = MapGeo.trackBounds(detail.points)!;
    final padded = MapGeo.pad(raw);
    // 20 % of the span on every side.
    expect(padded.east - padded.west, closeTo((raw.east - raw.west) * 1.4, 1e-9));
    expect(padded.north - padded.south, closeTo((raw.north - raw.south) * 1.4, 1e-9));
    for (final (lat, lon) in [(padded.north, padded.west), (padded.south, padded.east)]) {
      expect(inside(region, lat, lon), isTrue, reason: '($lat, $lon) outside $region');
    }

    // Mercator aspect == image aspect: MapKit renders the region unchanged.
    const size = card402;
    expect(card.lonSpan / mercSpan(region), closeTo(size.width / size.height, 1e-6));

    // The padded bbox fills the inset rectangle on at least one axis.
    final inset = MapCardGeometry.routeInset(size);
    final fx = (padded.east - padded.west) / region.lonSpan;
    final fy = (MapGeo.mercY(padded.north) - MapGeo.mercY(padded.south)) / mercSpan(region);
    final tightX = (fx - (size.width - inset.horizontal) / size.width).abs() < 1e-6;
    final tightY = (fy - (size.height - inset.vertical) / size.height).abs() < 1e-6;
    expect(tightX || tightY, isTrue, reason: 'fx $fx fy $fy');
  });

  test('card geometry: route band on top, text below it, the Apple wordmark strip left free', () async {
    for (final scale in [1.0, 1.3]) {
      final t = TextScaler.linear(scale);
      final size = MapCardGeometry.imageSize(screenWidth: 375, textScaler: t);
      expect(size.width, 334); // 375 − 2 × 20 − 2 × 0.5
      final inset = MapCardGeometry.routeInset(size);
      // The route area ends where the text may begin; the text ends above the
      // wordmark box (whose top is 27 pt above the image bottom).
      expect(size.height - inset.bottom, MapCardGeometry.band);
      const pad = MapCardGeometry.textPadding;
      expect(pad.top, greaterThan(MapCardGeometry.band));
      expect(pad.bottom, greaterThanOrEqualTo(AppleWordmark.bottom + AppleWordmark.height + 3));
      expect(size.height, greaterThanOrEqualTo(pad.vertical + MapCardGeometry.textHeight(t)));
      if (scale == 1) expect(size.height, MapCardGeometry.minHeight);
      if (scale > 1) expect(size.height, greaterThan(MapCardGeometry.minHeight));

      // Every track point projects into the band, never into the wordmark box.
      final detail = longDetail();
      final fake = FakeMapSnapshotSource(bytes: png);
      await ThumbnailRenderer.renderMap(detail, source: fake, dir: dir, cardSize: size, heroSize: ThumbnailRenderer.heroSizeFor(375));
      final region = regionOf(fake.requests.firstWhere((r) => r.route.isNotEmpty));
      final wordmark = AppleWordmark.rectIn(Offset.zero & size, 1);
      for (final p in detail.points) {
        final u = region.project(p.lat!, p.lon!);
        final o = Offset(u.dx * size.width, u.dy * size.height);
        expect(o.dy, inInclusiveRange(inset.top - 1e-4, MapCardGeometry.band + 1e-4));
        expect(o.dx, inInclusiveRange(inset.left - 1e-4, size.width - inset.right + 1e-4));
        expect(wordmark.contains(o), isFalse);
      }
    }
  });

  test('hero: the plate and the route stay clear of the Apple wordmark', () {
    final hero = ThumbnailRenderer.heroSizeFor(375);
    final wordmark = AppleWordmark.rectIn(Offset.zero & hero, 1);
    // Route area bottom (300 − 130 = 170) and the plate (bottom 38 pt above the
    // image bottom) both end above the wordmark box (273–290).
    expect(hero.height - ThumbnailRenderer.heroInset.bottom, lessThan(wordmark.top));
    expect(wordmark.top, greaterThanOrEqualTo(hero.height - AppleWordmark.clearance));
  });

  test('the route reaches the channel simplified to at most 500 points', () async {
    final detail = longDetail();
    final fake = FakeMapSnapshotSource(bytes: png);
    await ThumbnailRenderer.renderMap(detail, source: fake, dir: dir);
    final route = fake.requests.firstWhere((r) => r.route.isNotEmpty).route;
    expect(route.length, lessThanOrEqualTo(500));
    expect(route.length, greaterThan(20));
    expect(route.first, (detail.points.first.lat!, detail.points.first.lon!));
    expect(route.last, (detail.points.last.lat!, detail.points.last.lon!));
    expect(route, MapGeo.simplifiedRoute(detail.points));
  });

  test('a short track still shows at least 1.5 km of terrain on both axes', () async {
    final pts = [
      for (var i = 0; i < 20; i++) TrackPoint(ts: i * 1000, lat: 47.44 + i * 0.00001, lon: 12.39, accepted: true, state: MotionState.run),
    ];
    final detail = DayDetail(
      day: DayRecord(id: 'short', startedAt: 0, endedAt: 20000, status: DayStatus.finished, stats: DayStats.empty),
      segments: const [],
      points: pts,
    );
    final padded = ThumbnailRenderer.mapBounds(detail)!;
    expect((padded.north - padded.south) * MapGeo.metresPerDegLat, closeTo(1500, 1));
    expect((padded.east - padded.west) * MapGeo.metresPerDegLon(47.44), closeTo(1500, 1));

    final fake = FakeMapSnapshotSource(bytes: png);
    await ThumbnailRenderer.renderMap(detail, source: fake, dir: dir);
    expect(fake.requests, hasLength(2));
    for (final r in fake.requests) {
      final region = regionOf(r);
      expect(region.widthM, greaterThanOrEqualTo(1499));
      expect(region.heightM, greaterThanOrEqualTo(1499));
    }
  });

  test('no track: the resort centre ± radius, route empty', () async {
    final fake = FakeMapSnapshotSource(bytes: png);
    final path = await ThumbnailRenderer.renderMap(emptyDetail(resortId: 'kitzbuehel'), resort: kitz, source: fake, dir: dir);
    expect(path, isNotNull);
    for (final r in fake.requests) {
      expect(r.route, isEmpty);
      expect(inside(regionOf(r), kitz.lat, kitz.lon), isTrue);
      expect(regionOf(r).heightM, greaterThanOrEqualTo(6000 - 1)); // 2 × 3 km
    }
  });

  test('no track and no resort: nothing requested, nothing written', () async {
    final fake = FakeMapSnapshotSource(bytes: png);
    expect(await ThumbnailRenderer.renderMap(emptyDetail(), source: fake, dir: dir), isNull);
    expect(fake.requests, isEmpty);
    expect(Directory('${dir.path}/thumbs').existsSync(), isFalse);
  });

  test('a null answer leaves only the path PNGs', () async {
    final detail = fixtureDetail(dayId: 'off');
    final base = await ThumbnailRenderer.renderBoth(detail, dir: dir);
    final fake = FakeMapSnapshotSource(); // offline: null
    expect(await ThumbnailRenderer.renderMap(detail, source: fake, dir: dir), isNull);
    expect(fake.requests, hasLength(2));
    final files = Directory('${dir.path}/thumbs').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, {'off.png', 'off_light.png'});
    expect(File(ThumbnailRenderer.mapPathFor(base)).existsSync(), isFalse);
    expect(ThumbnailRenderer.heroFrameFor(base), isNull);
  });

  test('a throwing source is swallowed', () async {
    final fake = FakeMapSnapshotSource()..bytesFor = (_) => throw StateError('native');
    expect(await ThumbnailRenderer.renderMap(fixtureDetail(), source: fake, dir: dir), isNull);
  });

  group('MapGeo', () {
    test('fit: the region aspect equals the image aspect and the content sits in the inset', () {
      const b = (south: 47.40, west: 12.30, north: 47.42, east: 12.36);
      const size = Size(390, 300);
      const inset = EdgeInsets.fromLTRB(34, 34, 34, 110);
      final r = MapGeo.fit(b, size, inset: inset);
      expect(r.lonSpan / mercSpan(r), closeTo(390 / 300, 1e-9));
      final sw = r.project(b.south, b.west), ne = r.project(b.north, b.east);
      final rect = Rect.fromPoints(Offset(sw.dx * 390, sw.dy * 300), Offset(ne.dx * 390, ne.dy * 300));
      final avail = Rect.fromLTRB(34, 34, 390 - 34, 300 - 110);
      expect(avail.inflate(1e-6).contains(rect.topLeft) && avail.inflate(1e-6).contains(rect.bottomRight), isTrue, reason: '$rect in $avail');
      expect(rect.center.dx, closeTo(avail.center.dx, 1e-6));
      expect(rect.center.dy, closeTo(avail.center.dy, 1e-6));
    });

    test('project: corners map to the unit square, north up', () {
      const r = MapRegion(north: 47.5, south: 47.4, west: 12.3, east: 12.5);
      expect(r.project(47.5, 12.3), const Offset(0, 0));
      final se = r.project(47.4, 12.5);
      expect(se.dx, closeTo(1, 1e-12));
      expect(se.dy, closeTo(1, 1e-12));
      expect(r.project(47.45, 12.4).dy, greaterThan(0.5)); // Mercator stretches north: the midpoint latitude sits a hair below centre
    });

    test('mercY round-trips', () {
      for (final lat in [-60.0, 0.0, 12.5, 47.44, 70.0]) {
        expect(MapGeo.latFromMercY(MapGeo.mercY(lat)), closeTo(lat, 1e-9));
      }
    });

    test('MapFrame encodes and decodes; garbage decodes to null', () {
      const f = MapFrame(region: MapRegion(north: 1, south: 0, west: 0, east: 2), size: Size(390, 300));
      final back = MapFrame.decode(f.encode())!;
      expect(back.region.east, 2);
      expect(back.size, const Size(390, 300));
      expect(MapFrame.decode('nope'), isNull);
      expect(MapFrame.decode('{"region":{"north":0,"south":1,"west":0,"east":1},"width":1,"height":1}'), isNull);
    });

    test('simplifiedRoute keeps short routes untouched and drops rejected points', () {
      final pts = fixtureTrack();
      final withRejected = [...pts, TrackPoint(ts: 9e12.toInt(), lat: 0, lon: 0, accepted: false)];
      final route = MapGeo.simplifiedRoute(withRejected);
      expect(route.length, pts.length);
      expect(route.contains((0.0, 0.0)), isFalse);
    });
  });
}
