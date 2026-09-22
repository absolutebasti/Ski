import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/brand.dart';
import '../../app/theme/tokens.dart';

/// Map strategy (docs/PLAN.md §10): one branded raster source via `MAP_TILE_URL`,
/// otherwise OpenTopoMap + OpenSnowMap piste overlay (no key, dev/TestFlight only).
class TileConfig {
  const TileConfig._();

  static const String openTopoUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
  static const List<String> openTopoSubdomains = ['a', 'b', 'c'];
  static const String openSnowUrl = 'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png';
  static const String fallbackAttribution = 'OpenStreetMap, OpenTopoMap, OpenSnowMap (ODbL)';
  static const Duration maxStale = Duration(days: 30);
  static const int maxZoom = 17;

  static bool get usesBrandedTiles => kMapTileUrl.isNotEmpty;

  static String get attributionText {
    if (!usesBrandedTiles) return fallbackAttribution;
    return kMapTileUrl.contains('mapbox') ? 'Mapbox, © OpenStreetMap' : 'OpenStreetMap';
  }

  /// Desaturate (35 %) + darken (58 %) with a faint blue lift, so the beige
  /// OpenTopoMap raster reads as graphite inside the dark shell
  /// (docs/DESIGN.md §0.9). Branded tiles are assumed dark already.
  static const List<double> darkenMatrix = <double>[
    0.2833, 0.2696, 0.0271, 0, 0, //
    0.0803, 0.4726, 0.0271, 0, 0, //
    0.0803, 0.2696, 0.2301, 0, 4, //
    0, 0, 0, 1, 0, //
  ];

  /// Ink veil between the raster and the track — the route must be the
  /// brightest thing on the map.
  static const double veilOpacity = 0.45;
  static const double brandedVeilOpacity = 0.20;

  /// The raster layers in draw order. One shared [TileProvider] is fine: the
  /// base tile provider's `dispose` is a no-op, so two layers may share it.
  ///
  /// [dark] applies the desaturate/darken matrix and the veil; pass `false`
  /// only where the raw raster is wanted (never in the app today).
  static List<Widget> layers(TileProvider provider, {bool dark = true}) {
    final raster = <Widget>[
      if (usesBrandedTiles)
        TileLayer(
          urlTemplate: kMapTileUrl,
          userAgentPackageName: kBundleId,
          tileProvider: provider,
          maxNativeZoom: maxZoom,
        )
      else ...[
        TileLayer(
          urlTemplate: openTopoUrl,
          subdomains: openTopoSubdomains,
          userAgentPackageName: kBundleId,
          tileProvider: provider,
          maxNativeZoom: maxZoom,
        ),
        TileLayer(
          urlTemplate: openSnowUrl,
          userAgentPackageName: kBundleId,
          tileProvider: provider,
          maxNativeZoom: maxZoom,
          // The piste overlay is transparent; do not paint a background behind it.
          tileDisplay: const TileDisplay.instantaneous(),
        ),
      ],
    ];
    if (!dark) return raster;
    return [
      for (final layer in raster)
        if (usesBrandedTiles) layer else ColorFiltered(colorFilter: const ColorFilter.matrix(darkenMatrix), child: layer),
      TileVeil(opacity: usesBrandedTiles ? brandedVeilOpacity : veilOpacity),
    ];
  }

  static Widget attribution() => RichAttributionWidget(
        showFlutterMapAttribution: false,
        attributions: [TextSourceAttribution(attributionText)],
      );
}

/// Ink veil drawn over the raster and under the track (a direct child of the
/// [FlutterMap] stack, so it fills the whole camera).
class TileVeil extends StatelessWidget {
  const TileVeil({super.key, this.opacity = TileConfig.veilOpacity});
  final double opacity;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(child: ColoredBox(color: AppColors.of(context).ink.withValues(alpha: opacity))),
      );
}

/// Disk-cached tile provider (30 days stale-if-error). Screens await it once.
final tileProviderProvider = FutureProvider<TileProvider>((ref) async {
  final tmp = await getTemporaryDirectory();
  final store = FileCacheStore('${tmp.path}/tiles');
  return CachedTileProvider(
    store: store,
    cachePolicy: CachePolicy.request,
    maxStale: TileConfig.maxStale,
    hitCacheOnNetworkFailure: true,
  );
});
