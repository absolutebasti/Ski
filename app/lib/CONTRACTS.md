# Cross-package contracts (read before implementing any work package)

Lead-owned files: `pubspec.yaml`, `lib/main.dart`, `lib/app/**`, `lib/core/**`, `test/support/**`.
Do **not** edit them; if a contract is missing, add a note to your final report and code against your best
interpretation. Everything below already exists and compiles.

## Core (`package:schwung/core/core.dart`)

| Symbol | File | Notes |
|---|---|---|
| `TrackingConfig` | core/constants.dart | every threshold, static consts, SI units |
| `RawFix`, `PressureSample` | core/models/raw_fix.dart | platform inputs, JSON round-trip |
| `TrackPoint` | core/models/track_point.dart | one engine tick; `accepted`, `rejectReason`, `state`, `fusedAltM`, `heartRateBpm` |
| `Segment` | core/models/segment.dart | run / lift / stop / other / signalLoss with per-segment stats; `flags` bit 1 = vehicle |
| `DayStats` | core/models/day_stats.dart | aggregates stored on the `days` row; `DayStats.empty` |
| `DayRecord`, `DaySummary`, `DayDetail`, `SeasonTotals`, `PersonalBests` | core/models/day.dart | DB row / list item / detail payload / SQL aggregates |
| `LiveState`, `RecordingState` | core/models/live_state.dart | 1 Hz UI state; controller state |
| `Resort`, `WeatherSnapshot` | core/models/resort.dart | bundled resort centre; Open-Meteo snapshot |
| enums `RejectReason`, `MotionState`, `SegmentKind`, `GpsQuality`, `DayStatus`, `RecordingStatus` | core/models/enums.dart | |
| `LocationSource`, `BarometerSource`, `BatterySource`, `HeartRateSource` | core/sources.dart | interfaces; WP-03 implements, WP-05 consumes, fakes in test/support/fakes.dart |
| `haversineM`, `bearingDeg` | core/geo/haversine.dart | |
| `seasonKey`, `seasonKeyFromMs`, `seasonStart` | core/season.dart | Jul 1 – Jun 30, '2025/26' |
| `Fmt` | core/units/format.dart | `kmh`, `metres`, `km`, `durationCompact`, `clock`, `timeOfDay`, `dateShort`, `dateLong`, `percent`, `temp` |
| `settingsProvider`, `Settings`, `SettingsNotifier` | core/settings.dart | locale / onboardingDone / notificationsOptIn / lastResortId / diagnosticsUnlocked |
| `isRecordingProvider` | core/settings.dart | `ref.read(isRecordingProvider.notifier).set(true/false)` — WP-05 must call this |

## App layer (`package:schwung/app/...`)

| Symbol | File | Notes |
|---|---|---|
| `kAppName`, `kBundleId`, `kSupportEmail`, `kPrivacyUrl`, `kMascotName`, `kMapTileUrl` | app/brand.dart | |
| `AppColors.of(context)`, `Tokens` | app/theme/tokens.dart | semantic colours; never hard-code hex in features |
| `AppText.hero/stat/headline/title/bodyText/label/unit/button` | app/theme/typography.dart | |
| `AppLocale.of(context).pick(de:, en:)` | app/l10n/app_locale.dart | keep strings in `<feature>_strings.dart` |
| `AppCard`, `PrimaryButton`, `SecondaryButton`, `HoldToConfirmButton`, `HeroNumber`, `StatTile`, `StackedTimeBar`, `StateChip`, `RecordingPill`, `AppSheet.show`, `EmptyState`, `MascotCard` | app/widgets/widgets.dart | |
| `AppNav.openDay(context, id)`, `AppNav.openSummary(context, id)` | app/router.dart | |
| `AppRouter.heute()/tage()/onboarding()/dayDetail(id)/summary(id)` | app/router.dart | placeholders; WP-12 swaps to real screens |

## Providers each work package must expose (exact names — other packages import them)

| Provider | Type | Owner | File |
|---|---|---|---|
| `databaseProvider` | `Provider<AppDatabase>` | WP-02 | data/db/database.dart |
| `daysRepositoryProvider` | `Provider<DaysRepository>` | WP-02 | data/db/days_repository.dart |
| `daysListProvider` | `StreamProvider<List<DaySummary>>` (finished days, newest first, soft-deleted excluded) | WP-02 | data/db/providers.dart |
| `dayDetailProvider` | `FutureProvider.family<DayDetail, String>` | WP-02 | data/db/providers.dart |
| `seasonTotalsProvider` | `StreamProvider<List<SeasonTotals>>` (newest season first) | WP-02 | data/db/providers.dart |
| `personalBestsProvider` | `StreamProvider<PersonalBests>` | WP-02 | data/db/providers.dart |
| `resortRepositoryProvider` | `Provider<ResortRepository>` with `Resort? nearest(double lat, double lon)` and `Resort? byId(String)` | WP-02 | data/resorts/resort_repository.dart |
| `locationSourceProvider`, `barometerSourceProvider`, `batterySourceProvider`, `heartRateSourceProvider` | `Provider<...Source>` | WP-03 | platform/providers.dart |
| `permissionServiceProvider` | `Provider<PermissionService>` — `Future<LocationPermissionState> requestWhenInUse()`, `Future<LocationPermissionState> requestAlways()`, `Future<bool> requestMotion()`, `Future<bool> requestNotifications()`, `Future<LocationPermissionState> status()`, `Future<bool> hasPreciseLocation()`, `Future<bool> requestTemporaryFullAccuracy()`, `Future<void> openSettings()` | WP-03 | platform/permission_service.dart |
| `notificationServiceProvider` | `Provider<NotificationService>` — `showReminder(id, title, body)`, `cancel(id)`, `scheduleIn(id, Duration, title, body)` | WP-03 | platform/notification_service.dart |
| `watchdogChannelProvider` | `Provider<WatchdogChannel>` — `start()`, `stop()`, `Future<bool> didLaunchFromLocation()` | WP-03 | platform/watchdog_channel.dart |
| `recordingControllerProvider` | `NotifierProvider<RecordingController, RecordingState>` — `Future<void> startDay()`, `Future<String?> endDay()` (returns dayId or null if discarded), `Future<void> discardDay()`, `Future<void> resumeIfActive()` | WP-05 | features/recording/recording_controller.dart |
| `liveStateProvider` | `Provider<LiveState>` (rebuilds ≈1 Hz while recording) | WP-05 | features/recording/live_state_provider.dart |
| `recoveryProvider` | `FutureProvider<RecoveryInfo?>` (`dayId`, `startedAt`, `lastFixAt`, `runCount`, `dropM`) | WP-05 | features/recording/recovery_service.dart |
| `weatherProvider` | `FutureProvider.family<WeatherSnapshot?, Resort>` | WP-11 | data/weather/weather_provider.dart |
| `TrackingEngine` | class — `TrackingEngine(config)`, `void addFix(RawFix)`, `void addPressure(PressureSample)`, `EngineTick tick(int nowMs)` returning the new `TrackPoint` + `LiveState` + emitted `Segment`s; `static DayComputation computeDay(List<TrackPoint>)` | WP-01 | tracking/engine.dart |
| `TrackMap` | widget — `TrackMap({required List<TrackPoint> points, required List<Segment> segments, bool follow = false, LatLng? center, bool interactive = true, int? scrubTs})` | WP-09 | features/map/track_map.dart |
| `MapSheet.show(context)` | static — full-height sheet with live map (reads `liveStateProvider` + WP-05's `liveTrackProvider: Provider<List<TrackPoint>>` ring) | WP-09 | features/map/map_sheet.dart |
| `ThumbnailRenderer.render(DayDetail) → Future<String path>` | | WP-09 | features/map/thumbnail_renderer.dart |
| `AltitudeProfile` | widget — `AltitudeProfile({required List<TrackPoint> points, required List<Segment> segments, ValueChanged<int?>? onScrub})` | WP-10 | features/profile/altitude_profile.dart |
| `ShareService` | `Future<void> shareDayCard(BuildContext, DayDetail)`, `Future<void> shareGpx(DayDetail)`, `Future<void> shareDiagnostics(String dayId)` | WP-10 | features/share/share_service.dart |
| `HeuteScreen`, `TagesbilanzScreen(dayId:)`, `SettingsSheet.show(context)` | widgets | WP-07 | features/today, features/summary, features/settings |
| `TageScreen`, `DayDetailScreen(dayId:)` | widgets | WP-08 | features/days |
| `OnboardingFlow` | widget; on finish calls `settingsProvider.notifier.setOnboardingDone()` and `Navigator.pushReplacement` to `RootShell` | WP-06 | features/onboarding/onboarding_flow.dart |

## Rules

1. Riverpod 3 without codegen (`Notifier`, `NotifierProvider`, `Provider`, `StreamProvider`, `FutureProvider`, `.family`). No `StateProvider`, no `ChangeNotifier`.
2. Pure-Dart layers (`core/`, `tracking/`) never import Flutter.
3. All units SI; format only in widgets via `Fmt`.
4. Strings: German first, English second, via `AppLocale.pick`. Sentence case. Ski vocabulary: Abfahrt, Höhenmeter, Liftfahrt, Pause, Gefälle, Skitag, Top-Speed.
5. Tests live under `test/<your package>/`; use `test/support/fakes.dart` and `pump.dart`.
6. Run `flutter analyze` and `flutter test test/<your package>` before reporting; zero analyzer issues.
