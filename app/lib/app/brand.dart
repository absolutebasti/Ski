/// The only place the product name lives. Renaming = change here + bundle id.
const String kAppName = 'SlopeTrack';
const String kBundleId = 'de.torchtechnology.slopetrack';
const String kSupportEmail = 'hello@torchtechnology.de';
const String kPrivacyUrl = 'https://absolutebasti.github.io/Ski/privacy.html';
const String kSupportUrl = 'https://absolutebasti.github.io/Ski/support.html';
const String kImprintUrl = 'https://absolutebasti.github.io/Ski/imprint.html';
const String kTermsUrl = 'https://absolutebasti.github.io/Ski/terms.html';
const String kMascotName = 'Toni';

/// App Store page. Empty until the App Store Connect record exists — then put
/// the URL here and in STORE_URL of docs/index.html, docs/d and docs/f.
const String kAppStoreUrl = '';

/// Flip once slopetrack.app points at the GitHub Pages site and serves the
/// apple-app-site-association (Universal Links, nicer share links).
const bool kCustomDomainLive = false;

/// The public landing page (App Store button, legal pages).
const String kWebsiteUrl = kCustomDomainLive ? 'https://slopetrack.app' : 'https://absolutebasti.github.io/Ski/';

/// Where a shared result sends someone who does not have the app yet: the
/// App Store once live, the landing page until then.
const String kGetAppUrl = kAppStoreUrl == '' ? kWebsiteUrl : kAppStoreUrl;

/// Map tiles: override with --dart-define=MAP_TILE_URL=... (e.g. Mapbox static tiles).
/// Empty → OpenTopoMap base + OpenSnowMap piste overlay (no key, dev/TestFlight only).
const String kMapTileUrl = String.fromEnvironment('MAP_TILE_URL');
