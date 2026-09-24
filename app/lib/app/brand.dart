/// The only place the product name lives. Renaming = change here + bundle id.
const String kAppName = 'SlopeTrack';
const String kBundleId = 'de.torchtechnology.slopetrack';
const String kSupportEmail = 'hello@torchtechnology.de';
const String kPrivacyUrl = 'https://slopetrack.torchtechnology.de/privacy';
const String kMascotName = 'Toni';

/// Map tiles: override with --dart-define=MAP_TILE_URL=... (e.g. Mapbox static tiles).
/// Empty → OpenTopoMap base + OpenSnowMap piste overlay (no key, dev/TestFlight only).
const String kMapTileUrl = String.fromEnvironment('MAP_TILE_URL');
