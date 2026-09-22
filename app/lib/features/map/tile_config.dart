import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/brand.dart';

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

  /// The raster layers in draw order. One shared [TileProvider] is fine: the
  /// base tile provider's `dispose` is a no-op, so two layers may share it.
  static List<Widget> layers(TileProvider provider) {
    if (usesBrandedTiles) {
      return [
        TileLayer(
          urlTemplate: kMapTileUrl,
          userAgentPackageName: kBundleId,
          tileProvider: provider,
          maxNativeZoom: maxZoom,
        ),
      ];
    }
    return [
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
    ];
  }

  static Widget attribution() => RichAttributionWidget(
        showFlutterMapAttribution: false,
        attributions: [TextSourceAttribution(attributionText)],
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
