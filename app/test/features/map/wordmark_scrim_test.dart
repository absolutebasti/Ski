import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/map/map_overlay.dart';

/// Alpha (0–1) of every pixel [painter] leaves on a transparent canvas of [size].
Future<double Function(Offset)> paintAlpha(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = image.width;
  image.dispose();
  return (o) => bytes.getUint8(((o.dy.floor() * w) + o.dx.floor()) * 4 + 3) / 255;
}

void main() {
  // Apple's terms: the wordmark must not be obscured. The scrims over map
  // snapshots stay ≤ 0.5 over its box, everywhere else they keep their density.
  const dense = LinearGradient(colors: [Color(0xF0000000), Color(0xF0000000)]);

  List<Offset> samples(Rect r) => [
        for (final fx in [0.02, 0.5, 0.98])
          for (final fy in [0.05, 0.5, 0.95]) Offset(r.left + r.width * fx, r.top + r.height * fy),
      ];

  test('day card: ≤ 0.5 over the wordmark, dense beside it', () async {
    const size = Size(334, 172);
    const painter = WordmarkScrim(gradient: dense, imageSize: size);
    final alpha = await paintAlpha(painter, size);
    final box = painter.wordmarkIn(size)!;
    expect(box, const Rect.fromLTWH(14, 145, 52, 17));
    for (final o in samples(box)) {
      expect(alpha(o), lessThanOrEqualTo(0.5), reason: 'scrim $o');
    }
    expect(alpha(const Offset(200, 160)), closeTo(0.94, 0.01)); // under 'Karten: © Apple'
    expect(alpha(const Offset(100, 100)), closeTo(0.94, 0.01)); // under the text
  });

  test('Tagesbilanz: the bottom fade to the page opens over the wordmark too', () async {
    const size = Size(402, 300);
    const toPage = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0xD9000000), Color(0xFF000000)],
      stops: [0, 0.6, 1],
    );
    final painter = WordmarkScrim(gradient: toPage, gradientHeight: 120, imageSize: size, veil: WordmarkScrim.defaultVeil.withValues(alpha: 0.12));
    final alpha = await paintAlpha(painter, size);
    for (final o in samples(painter.wordmarkIn(size)!)) {
      expect(alpha(o), lessThanOrEqualTo(0.5), reason: 'scrim $o');
    }
    expect(alpha(const Offset(300, 298)), greaterThan(0.95)); // the fade still reaches the page
    expect(alpha(const Offset(200, 100)), 0); // no scrim over the route area
  });

  test('without a snapshot there is no window', () async {
    const size = Size(334, 172);
    const painter = WordmarkScrim(gradient: dense);
    expect(painter.wordmarkIn(size), isNull);
    final alpha = await paintAlpha(painter, size);
    expect(alpha(const Offset(30, 155)), closeTo(0.94, 0.01));
  });

  test('a mismatched image is drawn cover, bottom-left: the wordmark corner stays whole', () {
    // An image rendered for a narrower phone on a wider card scales up and
    // loses its top, never the bottom-left corner.
    final (rect, k) = AppleWordmark.coverBottomLeft(const Size(334, 172), const Size(361, 172));
    expect(rect.left, 0);
    expect(rect.bottom, 172);
    expect(k, closeTo(361 / 334, 1e-9));
    final box = AppleWordmark.rectIn(rect, k);
    expect(box.left, greaterThan(0));
    expect(box.bottom, lessThan(172));
  });
}
