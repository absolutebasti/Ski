import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/brand.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/share/share_card.dart';
import 'package:slopetrack/features/share/share_card_renderer.dart';

import '../../support/pump.dart';
import 'synthetic_detail.dart';

void main() {
  final detail = syntheticDetail();

  testWidgets('ShareCard lays out at 1080×1350 with the hero numbers and wordmark', (tester) async {
    tester.view.physicalSize = const Size(1080, 1350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, ShareCard(detail: detail));
    final box = tester.renderObject<RenderBox>(find.byType(ShareCard));
    expect(box.size, const Size(1080, 1350));
    expect(find.text('HÖHENMETER'), findsOneWidget);
    expect(find.text('ABFAHRTEN'), findsOneWidget);
    expect(find.text('TOP-SPEED'), findsOneWidget);
    expect(find.text('SKI-KM'), findsOneWidget);
    expect(find.text('LÄNGSTE ABFAHRT'), findsOneWidget);
    expect(find.text('Kitzbühel'), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('${detail.day.stats.runCount}'), findsWidgets);
    expect(find.text(Fmt.metres(detail.day.stats.dropM, locale: 'de')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('the square variant drops the bottom stat row and still fits', (tester) async {
    tester.view.physicalSize = const Size(1080, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, ShareCard(detail: detail, format: ShareFormat.square));
    final box = tester.renderObject<RenderBox>(find.byType(ShareCard));
    expect(box.size, const Size(1080, 1080));
    expect(find.text('HÖHENMETER'), findsOneWidget);
    expect(find.text('SKI-KM'), findsNothing);
    expect(find.text('LÄNGSTE ABFAHRT'), findsNothing);
    expect(find.text(kAppName), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 1:1');
  });

  testWidgets('the story variant lays out at 1080×1920 with the wordmark above the safe area', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester, ShareCard(detail: detail, format: ShareFormat.story));
    final box = tester.renderObject<RenderBox>(find.byType(ShareCard));
    expect(box.size, const Size(1080, 1920));
    expect(find.text('HÖHENMETER'), findsOneWidget);
    expect(find.text('SKI-KM'), findsNothing);
    final wordmark = tester.getRect(find.byType(Wordmark));
    expect(1920 - wordmark.bottom, greaterThanOrEqualTo(120), reason: 'IG story safe area');
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 9:16');
  });

  test('every format carries its own size and file slug', () {
    expect(ShareFormat.portrait.size, const Size(1080, 1350));
    expect(ShareFormat.square.size, const Size(1080, 1080));
    expect(ShareFormat.story.size, const Size(1080, 1920));
    expect({for (final f in ShareFormat.values) f.slug}, hasLength(ShareFormat.values.length));
    expect(ShareCard.width, ShareFormat.portrait.width);
    expect(ShareCard.height, ShareFormat.portrait.height);
  });

  testWidgets('ShareCard renders in English with the open-terrain fallback', (tester) async {
    tester.view.physicalSize = const Size(1080, 1350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, ShareCard(detail: syntheticDetail(resortName: null)), locale: const Locale('en'));
    expect(find.text('VERTICAL'), findsOneWidget);
    expect(find.text('Open terrain'), findsOneWidget);
  });

  testWidgets('ShareCard survives an empty day', (tester) async {
    tester.view.physicalSize = const Size(1080, 1350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const empty = DayDetail(
      day: DayRecord(id: 'x', startedAt: 1700000000000, status: DayStatus.finished, stats: DayStats.empty),
      segments: [],
      points: [],
    );
    await pumpApp(tester, const ShareCard(detail: empty));
    expect(find.text('–'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShareCardRenderer produces a 1080×1350 PNG from an off-screen overlay entry', (tester) async {
    late BuildContext ctx;
    await pumpApp(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox.shrink();
    }));
    final png = await tester.runAsync(() => ShareCardRenderer.render(ctx, detail, awaitFrame: () => tester.pump()));
    expect(png, isNotNull);
    // PNG signature
    expect(png!.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    // IHDR width/height are big-endian at offsets 16..23
    int be(int o) => (png[o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
    expect(be(16), 1080);
    expect(be(20), 1350);
    // the off-screen boundary really painted: the card is not one flat colour
    final rgba = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      return frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final bytes = rgba!.buffer.asUint32List();
    expect(bytes.any((p) => p != bytes.first), isTrue, reason: 'card must not be a blank rectangle');

    await tester.pump();
    expect(find.byType(ShareCard), findsNothing, reason: 'overlay entry is removed again');
  });

  testWidgets('ShareCardRenderer honours the requested format', (tester) async {
    late BuildContext ctx;
    await pumpApp(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox.shrink();
    }));
    final png = await tester.runAsync(
      () => ShareCardRenderer.render(ctx, detail, awaitFrame: () => tester.pump(), format: ShareFormat.story),
    );
    int be(int o) => (png![o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
    expect(be(16), 1080);
    expect(be(20), 1920);
    await tester.pump();
  });
}
