import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/glyphs.dart';

void main() {
  test('the wave-1 glyph wishes exist', () {
    expect(
      Glyph.values.map((g) => g.name),
      containsAll(['friends', 'sun', 'check', 'search', 'person', 'bell', 'lock', 'battery', 'walk', 'pause', 'satellite']),
    );
  });

  for (final size in const [16.0, 24.0, 32.0]) {
    testWidgets('every glyph paints at ${size.toInt()} pt', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Wrap(children: [for (final g in Glyph.values) GlyphIcon(g, size: size, color: const Color(0xFFF6F4EE))]),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GlyphIcon), findsNWidgets(Glyph.values.length));
      for (final e in tester.widgetList<GlyphIcon>(find.byType(GlyphIcon))) {
        expect(tester.getSize(find.byWidget(e)), Size.square(size));
      }
    });

    test('every glyph draws something and balances save/restore at ${size.toInt()} pt', () {
      for (final g in Glyph.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final before = canvas.getSaveCount();
        GlyphPainter(g, const Color(0xFFF6F4EE), size / 24 * 1.75).paint(canvas, Size.square(size));
        expect(canvas.getSaveCount(), before, reason: '$g leaves the canvas transformed');
        final picture = recorder.endRecording();
        expect(picture.approximateBytesUsed, greaterThan(0), reason: '$g');
        picture.dispose();
      }
    });
  }

  testWidgets('new glyphs put ink inside the 24 grid and take their colour from the parameter', (tester) async {
    const added = [Glyph.friends, Glyph.sun, Glyph.check, Glyph.search, Glyph.person, Glyph.bell, Glyph.lock, Glyph.battery, Glyph.walk, Glyph.pause, Glyph.satellite];
    const colour = Color(0xFFE3C88C);
    await tester.runAsync(() async {
      for (final g in added) {
        final recorder = ui.PictureRecorder();
        // 8 px margin around a 48 px glyph: nothing may be drawn outside the glyph box.
        final canvas = Canvas(recorder)..translate(8, 8);
        GlyphPainter(g, colour, 48 / 24 * 1.75).paint(canvas, const Size.square(48));
        final image = await recorder.endRecording().toImage(64, 64);
        final data = (await image.toByteData())!;
        var inside = 0, outside = 0, offColour = 0;
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final i = (y * 64 + x) * 4;
            final a = data.getUint8(i + 3);
            if (a == 0) continue;
            final inBox = x >= 8 && x < 56 && y >= 8 && y < 56;
            inBox ? inside++ : outside++;
            // Fully opaque pixels carry the requested colour exactly.
            if (a == 255 && (data.getUint8(i) != 0xE3 || data.getUint8(i + 1) != 0xC8 || data.getUint8(i + 2) != 0x8C)) offColour++;
          }
        }
        image.dispose();
        expect(inside, greaterThan(60), reason: '$g draws too little');
        expect(outside, 0, reason: '$g draws outside its box');
        expect(offColour, 0, reason: '$g uses a colour other than the parameter');
      }
    });
  });
}
