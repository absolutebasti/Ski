# Cross-package contracts (read before implementing any work package)

Lead-owned files: `pubspec.yaml`, `lib/main.dart`, `lib/app/**`, `lib/core/**`, `test/support/**`.
Do **not** edit them; if a contract is missing, add a note to your final report and code against your best
interpretation. Everything below already exists and compiles.

## Core (`package:dropline/core/core.dart`)

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
| `settingsProvider`, `Settings`, `SettingsNotifier` | core/settings.dart | locale / onboardingDone / notificationsOptIn / lastResortId / diagnosticsUnlocked / seasonGoalHm / appearance (`system`\|`light`\|`dark`, `themeMode` getter, `setAppearance`) |
| `isRecordingProvider` | core/settings.dart | `ref.read(isRecordingProvider.notifier).set(true/false)` — WP-05 must call this |

## App layer (`package:dropline/app/...`)

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
| `databaseProvider` | `Provider<AppDatabase>` | WP-02 (done) | data/db/providers.dart |
| `daysRepositoryProvider` | `Provider<DaysRepository>` | WP-02 (done) | data/db/providers.dart |
| `daysListProvider` | `StreamProvider<List<DaySummary>>` (finished days, newest first, soft-deleted excluded) | WP-02 | data/db/providers.dart |
| `dayDetailProvider` | `FutureProvider.family<DayDetail, String>` | WP-02 | data/db/providers.dart |
| `seasonTotalsProvider` | `StreamProvider<List<SeasonTotals>>` (newest season first) | WP-02 | data/db/providers.dart |
| `personalBestsProvider` | `StreamProvider<PersonalBests>` | WP-02 | data/db/providers.dart |
| `resortRepositoryProvider` | `FutureProvider<ResortRepository>` with `Resort? nearest(double lat, double lon)`, `Resort? byId(String)`, `List<Resort> all` | WP-02 (done) | data/resorts/resort_repository.dart |
| `locationSourceProvider`, `barometerSourceProvider`, `batterySourceProvider`, `heartRateSourceProvider` | `Provider<...Source>` | WP-03 (done) | platform/providers.dart |
| `permissionServiceProvider` | `Provider<PermissionService>` — `Future<LocationPermissionState> requestWhenInUse()`, `Future<LocationPermissionState> requestAlways()`, `Future<bool> requestMotion()`, `Future<bool> requestNotifications()`, `Future<LocationPermissionState> status()`, `Future<bool> hasPreciseLocation()`, `Future<bool> requestTemporaryFullAccuracy()`, `Future<void> openSettings()` | WP-03 (done) | platform/permission_service.dart |
| `notificationServiceProvider` | `Provider<NotificationService>` — `showReminder(id, title, body)`, `cancel(id)`, `scheduleIn(id, Duration, title, body)` | WP-03 (done) | platform/notification_service.dart |
| `watchdogChannelProvider` | `Provider<WatchdogChannel>` — `start()`, `stop()`, `Future<bool> didLaunchFromLocation()` | WP-03 (done) | platform/watchdog_channel.dart |
| `recordingControllerProvider` | `NotifierProvider<RecordingController, RecordingState>` — `startDay()` (throws `RecordingError(kind)`: locationDenied, locationServiceOff, reducedAccuracy, alreadyRecording), `Future<String?> endDay()` (dayId or null if discarded), `discardDay()`, `Future<bool> resumeIfActive()`, `resumeDay(id)`, `Future<String?> endRecoveredDay(id)`, `discardRecoveredDay(id)`, `recomputeDay(id)` | WP-05 (done) | features/recording/recording_controller.dart |
| `liveStateProvider` | `Provider<LiveState>` (rebuilds ≈1 Hz while recording) | WP-05 (done) | features/recording/live_state_provider.dart |
| `liveTrackProvider` | `NotifierProvider<LiveTrackNotifier, List<TrackPoint>>` — ring of the last 300 accepted points | WP-05 (done) | features/recording/live_track_provider.dart |
| `recoveryProvider` | `FutureProvider<RecoveryInfo?>` (`dayId`, `startedAt`, `lastFixAt`, `runCount`, `dropM`, `resortName`); non-null = show the recovery card | WP-05 (done) | features/recording/recovery_service.dart |
| `weatherProvider` | `FutureProvider.family<WeatherSnapshot?, Resort>` | WP-11 | data/weather/weather_provider.dart |
| `TrackingEngine` | class — `TrackingEngine(config)`, `void addFix(RawFix)`, `void addPressure(PressureSample)`, `EngineTick tick(int nowMs)` returning the new `TrackPoint` + `LiveState` + emitted `Segment`s; `static DayComputation computeDay(List<TrackPoint>)` | WP-01 | tracking/engine.dart |
| `TrackMap` | widget — `TrackMap({points, segments, follow = false, center, interactive = true, scrubTs, tilesEnabled = true, locateSignal})` | WP-09 (done) | features/map/track_map.dart |
| `MapSheet.show(context)` | static — full-height sheet with live map (reads `liveStateProvider` + `liveTrackProvider` from features/recording/live_track_provider.dart) | WP-09 | features/map/map_sheet.dart |
| `ThumbnailRenderer.render(DayDetail) → Future<String path>` | | WP-09 | features/map/thumbnail_renderer.dart |
| `AltitudeProfile` | widget — `AltitudeProfile({required List<TrackPoint> points, required List<Segment> segments, ValueChanged<int?>? onScrub, double height = 200})` | WP-10 (done) | features/profile/altitude_profile.dart |
| `shareServiceProvider` / `ShareService` | `Provider<ShareService>`; `shareDayCard(BuildContext, DayDetail, {awaitFrame})`, `shareGpx(DayDetail)`, `shareDiagnostics(String dayId)`, `buildDiagnostics(dayId)` | WP-10 (done) | features/share/share_service.dart |
| `HeuteScreen`, `TagesbilanzScreen(dayId:)`, `SettingsSheet.show(context)`, `DiagnosticsPage` | widgets | WP-07 (done) | features/today, features/summary, features/settings |
| `locationStatusProvider`, `preciseLocationProvider`, `barometerAvailableProvider`, `appVersionProvider`, `settingsRefreshProvider` | FutureProviders for the settings sheet / idle cards | WP-07 (done) | features/settings/settings_providers.dart |
| `watchBridgeProvider`, `watchTransportProvider`, `watchClockProvider`, `watchHeartRateSourceProvider` | Apple Watch bridge (attach() in main.dart, self-seeding) | WP-13 (done) | platform/watch/** |
| `TageScreen`, `DayDetailScreen({dayId, tilesEnabled = true, heroHeight = 320})` | widgets | WP-08 (done) | features/days |
| `OnboardingFlow` | widget; on finish calls `settingsProvider.notifier.setOnboardingDone()` and `Navigator.pushAndRemoveUntil` to `RootShell` (app.dart freezes the initial onboarding decision) | WP-06 (done) | features/onboarding/onboarding_flow.dart |

## Rules

1. Riverpod 3 without codegen (`Notifier`, `NotifierProvider`, `Provider`, `StreamProvider`, `FutureProvider`, `.family`). No `StateProvider`, no `ChangeNotifier`.
2. Pure-Dart layers (`core/`, `tracking/`) never import Flutter.
3. All units SI; format only in widgets via `Fmt`.
4. Strings: German first, English second, via `AppLocale.pick`. Sentence case. Ski vocabulary: Abfahrt, Höhenmeter, Liftfahrt, Pause, Gefälle, Skitag, Top-Speed.
5. Tests live under `test/<your package>/`; use `test/support/fakes.dart` and `pump.dart`.
6. Run `flutter analyze` and `flutter test test/<your package>` before reporting; zero analyzer issues.
7. Widget tests that mount `RootShell`, `HeuteScreen` or `TageScreen` use `test/support/screen_overrides.dart` so no database or plugin is touched.

## Backend (v1.5, Supabase project `svzmmpzevmpodcelzvit`, schema in `supabase/migrations/0001_dropline.sql`)

| Symbol | Type / signature | Owner | File |
|---|---|---|---|
| `supabaseProvider` | `Provider<SupabaseClient?>` — null when the backend is unavailable; every feature must work with null | lead (done) | data/supabase/supabase_client.dart |
| `authStateProvider` | `StreamProvider<AuthUser?>` (`id`, `email?`, `displayName`) — signed-in user or null | WP-14 | data/sync/auth_service.dart |
| `authServiceProvider` | `Provider<AuthService>` — `Future<AuthUser?> signInWithApple()`, `signOut()`, `Future<void> deleteAccount()` (deletes rows via RPC/table deletes then signs out) | WP-14 | data/sync/auth_service.dart |
| `syncServiceProvider` | `Provider<SyncService>` — `Future<void> pushDay(String dayId)`, `Future<void> pullAll()`, `Future<void> syncNow()`, `Stream<SyncStatus> status` (`idle`, `syncing`, `offline`, `error`, `lastSyncAt`) | WP-14 | data/sync/sync_service.dart |
| `profileProvider` | `FutureProvider<Profile?>` (`displayName`, `avatarUrl`, `homeResortId`, `shareLeaderboards`) + `profileServiceProvider` with `update(...)` | WP-15 | features/account/profile_service.dart |
| `AccountSheet.show(context)` | Sign in with Apple / profile / opt-in toggle / sign out / delete account | WP-15 | features/account/account_sheet.dart |
| `SocialScreen` | third tab: Gebiets-Top-10 (season, metric chips, own rank), Tagesduell (create/join by code, live board), Wochen-Challenge | WP-16 | features/social/social_screen.dart |
| `leaderboardProvider` | `FutureProvider.family<List<LeaderboardEntry>, LeaderboardQuery>` via RPC `leaderboard(p_resort_id, p_season_key, p_metric, p_limit)` | WP-16 | features/social/leaderboard_providers.dart |
| `groupBoardProvider` | `FutureProvider.family<List<GroupMemberStats>, String groupId>` via RPC `group_board(p_group_id)` | WP-16 | features/social/group_providers.dart |

Rules for backend packages: never block the UI on the network; every remote call has a 10 s timeout and degrades to the local state; Sign in with Apple is the only provider (`supabase.auth.signInWithApple()` from supabase_flutter, iOS entitlement is configured); leaderboards need `profiles.share_leaderboards = true`, which the user switches on explicitly in the Account sheet (default off).
