/// The only place the product name lives. Renaming = change here + bundle id.
const String kAppName = 'SlopeTrack';
const String kBundleId = 'de.torchtechnology.slopetrack';
const String kSupportEmail = 'hello@torchtechnology.de';
const String kPrivacyUrl = 'https://absolutebasti.github.io/Ski/privacy.html';
const String kSupportUrl = 'https://absolutebasti.github.io/Ski/support.html';
const String kImprintUrl = 'https://absolutebasti.github.io/Ski/imprint.html';
const String kMascotName = 'Toni';

/// Map tiles: override with --dart-define=MAP_TILE_URL=... (e.g. Mapbox static tiles).
/// Empty → OpenTopoMap base + OpenSnowMap piste overlay (no key, dev/TestFlight only).
const String kMapTileUrl = String.fromEnvironment('MAP_TILE_URL');
