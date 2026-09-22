import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/features/map/tile_config.dart';

void main() {
  test('without a branded URL the raster is OpenTopoMap + the piste overlay', () {
    expect(TileConfig.usesBrandedTiles, isFalse, reason: 'MAP_TILE_URL is unset in the default build');
    final raw = TileConfig.layers(NetworkTileProvider(), dark: false);
    expect(raw.length, 2);
    expect(raw.every((w) => w is TileLayer), isTrue);
  });

  test('dark tiles: every raster layer is colour-filtered and a veil sits on top', () {
    final layers = TileConfig.layers(NetworkTileProvider());
    expect(layers.whereType<ColorFiltered>().length, 2);
    expect(layers.last, isA<TileVeil>());
    // The veil is the last child, so it covers the raster but not the track:
    // TrackMap adds the polylines after TileConfig.layers().
    expect(layers.indexWhere((w) => w is TileVeil), layers.length - 1);
  });

  test('the matrix desaturates and darkens: white becomes a graphite grey', () {
    double row(int i) => TileConfig.darkenMatrix[i * 5] + TileConfig.darkenMatrix[i * 5 + 1] + TileConfig.darkenMatrix[i * 5 + 2];
    expect(TileConfig.darkenMatrix.length, 20);
    // white (1,1,1) → 58 % on every channel, i.e. no colour cast and much darker
    expect(row(0), closeTo(0.58, 0.01));
    expect(row(1), closeTo(0.58, 0.01));
    expect(row(2), closeTo(0.58, 0.01));
    // alpha is untouched, so the transparent piste overlay stays transparent
    expect(TileConfig.darkenMatrix.sublist(15), [0, 0, 0, 1, 0]);
  });

  testWidgets('TileVeil paints ink over the full camera', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 200, height: 100, child: Stack(children: [TileVeil()]))),
      ),
    );
    expect(tester.getSize(find.byType(ColoredBox)), const Size(200, 100));
  });
}
