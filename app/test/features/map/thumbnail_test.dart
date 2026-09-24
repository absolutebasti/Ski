import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/map/thumbnail_renderer.dart';

import '../../support/pump.dart';
import 'track_fixture.dart';

void main() {
  test('TrackThumbnailPainter defaults follow the design spec', () {
    final p = TrackThumbnailPainter(points: fixtureTrack());
    expect(p.background, const Color(0xFF101216)); // graphite base
    expect(p.runWidth, 2.5);
    expect(p.liftWidth, 1.5);
    expect(p.glowWidth, 0); // the route is crisp, not glowing
    expect(p.hatch, isTrue);
    expect(p.vignette, isTrue);
    expect(TrackThumbnailPainter.vignetteOpacity, 0.12);
    expect(TrackThumbnailPainter.hatchOpacity, 0.06);
  });

  test('TrackThumbnailPainter paints the contour fallback for a day without points', () {
    final recorder = ui.PictureRecorder();
    TrackThumbnailPainter(points: const []).paint(Canvas(recorder), const Size(600, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('TrackThumbnailPainter paints a full track without throwing', () {
    final detail = fixtureDetail();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    TrackThumbnailPainter(points: detail.points, segments: detail.segments).paint(canvas, const Size(600, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('TrackThumbnailPainter tolerates empty, single-point and straight tracks', () {
    for (final pts in [
      <TrackPoint>[],
      fixtureTrack().take(1).toList(),
      [for (var i = 0; i < 5; i++) TrackPoint(ts: i * 1000, lat: 47.0 + i * 0.001, lon: 12.0, accepted: true, state: MotionState.run)],
    ]) {
      final recorder = ui.PictureRecorder();
      TrackThumbnailPainter(points: pts).paint(Canvas(recorder), const Size(600, 400));
      recorder.endRecording();
    }
  });

  test('ThumbnailRenderer.renderPng returns a PNG of 600×400', () async {
    final bytes = await ThumbnailRenderer.renderPng(fixtureDetail());
    expect(bytes.length, greaterThan(100));
    // PNG signature
    expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, ThumbnailRenderer.width);
    expect(frame.image.height, ThumbnailRenderer.height);
  });

  test('ThumbnailRenderer.render writes thumbs/<dayId>.png and returns the path', () async {
    final dir = await Directory.systemTemp.createTemp('slopetrack_thumbs_');
    try {
      final path = await ThumbnailRenderer.render(fixtureDetail(dayId: 'abc'), dir: dir);
      expect(path, '${dir.path}/thumbs/abc.png');
      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(100));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  testWidgets('TrackThumbnail widget builds inside a card', (tester) async {
    final detail = fixtureDetail();
    await pumpApp(tester, Scaffold(body: SizedBox(width: 300, child: TrackThumbnail(points: detail.points, segments: detail.segments))));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
