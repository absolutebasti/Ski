# Schwung — v1 build plan (Flutter 3.44 / Dart 3.12, iOS TestFlight first)

Status: final · Date: 2026-09-22 · Language of all artifacts: English · UI copy: German source, English second

---

## 0. Amendments by the lead (2026-09-22, after the design panel)

The sections below were produced by the design panel (3 proposals → 3 judges → synthesis). The adversarial verify pass did **not** run (Claude spend limit hit; retry after 12:10 Europe/Berlin). The lead checked the riskiest claims by hand and changed the following:

| # | Change | Why |
|---|---|---|
| A1 | App name **Schwung** instead of Schuss (bundle id `de.torchtechnology.schwung`) | 'SCHUSS: Slopes & Après' already exists in the US App Store (ski category). |
| A2 | **Apple Watch companion app is in scope as WP-13** (native SwiftUI watchOS target inside `app/ios`, bridged with `watch_connectivity`): Start / End from the wrist, live hero numbers, heart rate from the Watch into the day. Ships with the second TestFlight build, not the first. | Founder requirement (2026-09-22): "auf jeden Fall auch für Apple Watch, damit das Tracking sehr einfach geht". Slopes' Watch app is the benchmark. |
| A3 | Stack stays **Flutter** for the phone as the founder requested. Note for the founder: with a Watch app being native anyway, a fully native SwiftUI iOS+watchOS build would share one tracking engine, get HealthKit/Live Activities/MapKit for free and reuse ShapeMe code — at the price of no Android. Decision stays with the founder; the plan is written for Flutter + native Watch target. | Transparency on the trade-off. |
| A4 | **Sentry removed** from v1. TestFlight crash reports (Xcode Organizer) plus the hidden diagnostics bundle are enough; no third-party SDK, no DSN secret. | Fewer moving parts, no account needed. |
| A5 | iOS uses **Swift Package Manager** (Flutter 3.44 default). permission_handler compiles only the permissions whose usage keys exist in Info.plist; the Podfile macro step in §6/§14 is obsolete. The probe build with all packages passed on this Mac. | Verified 2026-09-22. |
| A6 | **Mascot** = the generated female ski guide (charcoal shell, cream beanie), name **Toni** kept. Assets already generated with fal.ai and committed under `design/mascot/` (16:9 card loop, 9:16 hero loop, stills). The §13 male-guide spec is superseded; keep §13's usage rules and generation pipeline. | Assets exist and are on-brand; no second generation round needed. |
| A7 | **Logo** = 'peak + run' mark (one stroke: a summit whose right flank becomes the descent), cream `#F4F1EA` on ink `#0A0B0E`, committed under `design/logo/` with 1024 px no-alpha exports. §12's diamond concept is superseded. | Chosen from 12 rendered candidates; legible at 29 pt; sibling of the ShapeMe octagon. |
| A8 | **Opt-in social (v1.5)** added to the roadmap: per-resort / per-country leaderboards (km, top speed, vertical) and private group days for up to 3 people, only when the user switches sharing on. Needs anonymous Supabase auth + two tables; v1's `days` aggregates are the publishable unit. | Founder idea (2026-09-22); see `docs/competitors/skiline.md`. |
| A9 | Competitor benchmarks extended: `docs/competitors/bergfex-ski.md`, `slopes.md`, `skiline.md`. Parity items pulled into v1: ski/lift/rest time split, altitude profile, share card, GPS-quality pill, resort auto-naming. v1.1 candidates: 'Gebiet' info (5-day forecast + fresh snow), Live Activity, season trends vs last season, Skiline-style altitude 'skyline' chart. | Founder supplied 21 screenshots after the panel had started. |
| A10 | Package versions refreshed to pub.dev of 2026-09-22: battery_plus 7.1, drift_flutter 0.3.1, package_info_plus 10.2, xml 7.0, uuid 4.6, http 1.6. | The panel quoted slightly older versions. |
| A11 | Legacy PWA moved to `legacy-pwa/` (history preserved via git mv). The exposed Mapbox token in `legacy-pwa/reviews/initial-assessment.md` must be **rotated** by the founder (public repo). | Housekeeping and security. |

---

## 1. Product definition

**One-liner.** Schwung records your whole ski day with one tap, keeps tracking while the phone stays locked in your jacket, and hands you honest runs, vertical and top speed in the evening — no zeros, no ads, no menus.

**Non-negotiables.**
1. Tracking continues with the screen locked / app backgrounded for a full ski day.
2. Nothing is lost on crash, kill or dead battery (every fix on disk within 5 s).
3. Numbers are honest: barometer vertical, Doppler speed, max speed only inside runs, ski-km never summed with lift-km, gradient only per run.
4. Two buttons on the mountain: **Tag starten** and **Tag beenden** (hold). Runs, lifts and stops are detected automatically.
5. Onboarding ≤ 3 steps, ≤ 60 s, with the mascot.
6. A lot of information, presented after the day, in a fixed order, with a hero hierarchy.

**Name decision.** `Schwung` — the German word for a ski turn and for momentum, one word, no umlaut, pronounceable in English. First choice 'Schuss' was dropped on 2026-09-22: the US App Store already lists 'SCHUSS: Slopes & Après' (Yang LLC) in the ski category. iTunes Search shows no exact 'Schwung' app and no ski-related app of that name in DE/US (checked 2026-09-22). Bundle id `de.torchtechnology.schwung`. The display name, wordmark and share-card footer read `kAppName` from `app/lib/app/brand.dart`; iOS `CFBundleDisplayName` and Android `android:label` follow the same value. The bundle id becomes permanent with the first App Store Connect upload — confirm the name with the founder before that. Alternatives if blocked: Firn, Talfahrt.

## 2. v1 scope

| In | Out (see ANALYSIS.md §6) |
|---|---|
| Day recording Start / hold-to-End; day = primary object; restart within 4 h at same resort appends silently | Manual pause, second timer |
| Background tracking iOS (location background mode) + Android foreground service; in-app recording pill + tab dot; iOS blue indicator | Live Activity (v1.1) |
| Crash-safe autosave, silent resume < 30 min, inline recovery card otherwise | — |
| Accuracy pipeline (gate → speed → altitude fusion → vertical → distance → segmenter → stats), deterministic live == offline | Kalman filters |
| Guards: stream watchdog, vehicle flag/auto-end, idle reminder/auto-end, 4 h reminder, meaningful-day discard | — |
| Heute screen idle + live, Karte sheet, Tage list, Tag detail, Tagesbilanz, Einstellungen sheet, hidden diagnostics | Map tab, resort picker, achievements |
| Personal bests + season totals by SQL (season = Jul 1 – Jun 30) | Persisted records |
| Share PNG day card + GPX; delete day; delete all data | GPX import, JSON export |
| Resort auto-detection from bundled `resorts.json` (~40 Alpine resorts) | Piste naming (columns reserved) |
| Weather one-liner (Open-Meteo, base/summit) — first thing to cut | Live lift status |
| Onboarding 3 steps with mascot clips; permissions: WhenInUse → Always (two-step) → Motion & Fitness | Notifications in onboarding (asked at first End) |
| DE + EN, dark-first with ThemeMode.system light variant, Sentry | fr/it/es, in-app theme toggle, analytics |
| Android builds (manifest, foreground config); no Android device QA | Play Store |

## 3. Screens

| Screen | Route / host | Content (fixed order) |
|---|---|---|
| **Heute — idle** | tab 0 | Resort label + weather line ('Kitzbühel · −4° Berg · 12 cm Neuschnee heute Nacht'); if a day exists: 'Zuletzt' card (date, Abfahrten · Höhenmeter · Top-Speed) and 'Saison' row (Skitage, Abfahrten, Höhenmeter); else one sentence + mascot still. Bottom: 72 pt full-width champagne **Tag starten** (thumb zone). Inline states above the button: location denied → 'Standort ist aus' + Einstellungen öffnen; reduced accuracy → 'Genau ein' card (Start blocked); recovery card (see below). Gear top-right → Einstellungen sheet. |
| **Heute — live** | tab 0 | Top pill '● Aufnahme läuft · GPS gut' + state chip ('Abfahrt 7' / 'Im Lift' / 'Pause' / 'Kein GPS – Höhe über Barometer'). Hero row (88 pt tabular): Höhenmeter · Abfahrten · Top-Speed. Secondary: Geschwindigkeit (large), Höhe, Zeit. Stacked bar Ski / Lift / Pause / Signalverlust with minutes. Footer: 'Akku reicht bis ca. 16:30'. Buttons: small **Karte** (opens sheet), hold-to-end **Tag beenden** (1.2 s ring, heavy haptic). Run-committed: medium haptic + 3 s banner 'Abfahrt 7 · 312 hm · 61 km/h'. |
| **Karte** (sheet) | modal from Heute | flutter_map, follow-me puck with heading, zoom 15, today's track (runs champagne 4 px + glow, lifts dashed grey), locate button; swipe to close. No layers, no 3D. |
| **Tage** | tab 1 | Season header ('2025/26 · 6 Tage · 41 Abfahrten · 18.240 hm') + PB chips (Top-Speed, größter Tag, längste Abfahrt); day cards newest first: date, resort, Abfahrten · Höhenmeter · Top-Speed, map thumbnail PNG, PB badge; older seasons collapsed. Long-press: Teilen / Löschen. Empty: mascot still + one line. |
| **Tag** (detail) | push from Tage | 1) header: date, resort, weather glyph, Abfahrten · Höhenmeter · Top-Speed; 2) map fit-to-bounds with start/end markers; 3) scrubbable time-based altitude profile (lift + signal-loss shading; scrub moves a marker on the map); 4) stacked time bar + Gesamt; 5) stats grid: Ski-km, Lift-km, Abfahrt, Aufstieg, Ø Speed beim Skifahren, Längste Abfahrt, Höchster/Tiefster Punkt, Lifte; 6) run list 'Abfahrt 7 · 10:42 · 312 hm · 2,1 km · 61 km/h · 14 %'; 7) Teilen (PNG + GPX), Löschen. |
| **Tagesbilanz** | full-screen route after End | Staggered count-up (80 ms): Höhenmeter → Abfahrten → Top-Speed → Ski-km; time bar; 'Beste Abfahrt' card; PB chips in champagne with heavy haptic; mascot still + one rule-based line; buttons Teilen / Fertig. First time: notification opt-in sheet ('Erinnerung nach 4 h, Akku-Warnung'). |
| **Recovery card** | inline on Heute | Active day with lastFixAt > 30 min: 'Tag vom 27.12. wurde unterbrochen · 7 Abfahrten · 1.804 hm' → **Beenden & speichern** / Fortsetzen / Verwerfen. < 30 min: silent resume, no card. |
| **Einstellungen** | bottom sheet | Sprache (System / Deutsch / English), Einheiten (read-only, follows locale), Standortzugriff status + Einstellungen öffnen, Benachrichtigungen toggle, Alle Daten löschen (double confirm), Datenschutz, Version. 7 taps on Version → **Diagnose**: GPS/precise/barometer status, accepted/rejected fixes today, stream restarts, 'Neu berechnen' (selected day), 'Diagnosepaket teilen' (gzip JSON of raw points), 'Fixture abspielen' (debug builds). |
| **Onboarding** | first launch | 3 pages, see §4. |

## 4. Onboarding (3 steps, ≤ 60 s)

Each page: full-bleed graphite, 16:9 mascot video card at the top (muted loop), caption line, headline, one sentence, one primary button, progress dots.

| Step | Copy (DE) | Mascot line | Action |
|---|---|---|---|
| 1 Willkommen | 'Ein Knopf. Ein Skitag.' — 'Schwung zählt deine Abfahrten, Höhenmeter und Top-Speed — automatisch, auch wenn das Handy in der Jacke steckt.' | 'Servus, ich bin Toni. Ich zähl' mit — du fährst.' | Weiter |
| 2 So funktioniert's | Three rows: 'Tippe auf Start' → 'Handy weg, Sperre an — die Aufnahme läuft' → 'Am Abend: Beenden, fertig.' Small mock of the iOS status pill: 'Dieses blaue Symbol heißt: es läuft.' + 'Lift, Pause, Abfahrt erkennen wir selbst.' | 'Lift, Pause, Abfahrt — das erkenn' ich selbst. Du musst nichts drücken.' | Weiter |
| 3 Standort & Sensoren | 'Gleich fragt dich das iPhone dreimal:' (a) Standort → 'Beim Verwenden' erlauben; (b) direkt danach 'Auf Immer erlauben ändern' — damit die Aufnahme nach einem Neustart weiterläuft; (c) Bewegung & Fitness → für den Luftdrucksensor (Höhenmeter auf den Meter). | 'Drei Fragen vom iPhone, dann sind wir startklar.' | **Erlauben** → `locationWhenInUse.request()` → on granted immediately `locationAlways.request()` (iOS shows 'Keep Only While Using / Change to Always Allow' **now**, once) → `sensors.request()`. Denied location: inline 'In Einstellungen öffnen', onboarding still finishes. Then `onboardingDone = true`, land on Heute, Start button pulses once. |

While-Using only is a fully working path (day is started in the foreground). Notifications are never requested here.

## 5. Accuracy pipeline (all constants in `app/lib/core/constants.dart`)

**Sensors.** geolocator stream at ~1 Hz (`LocationAccuracy.best`, distanceFilter 0, fitness, no auto-pause) → `RawFix{ts, lat, lon, hAccM, gpsAltM, vAccM, speedMs, speedAccMs, courseDeg, isMocked}`. sensors_plus barometer → `PressureSample{ts, hPa}`, pre-filtered: median-of-3, rate limit 3 hPa/s (faster = artefact). battery_plus level every 5 min.

**Engine.** `TrackingEngine` (pure Dart, no Flutter imports) driven by `tick(nowMs)` at 1 Hz. Each tick merges the newest fix (if new) and the newest pressure (age ≤ 3 s) into one `TrackPoint`, runs gate → altitude fuser → speed → vertical → distance → segmenter → stats, emits events. Ticks without a new fix still carry pressure, so altitude keeps running in gondolas and tunnels. `TrackingEngine.computeDay(points)` replays the same code offline; live == offline is asserted in tests. `engineVersion` (int) is stored per day.

**Gate (per raw fix, before anything else).** Reject with reason if: ts ≤ last accepted or age > 5 s (`stale`); hAcc > 30 m (`hAcc`); altitude outside 0–4500 m (`altitudeRange`); implied speed vs previous accepted > 45 m/s (`impliedSpeed`); |Δv/Δt| from consecutive Doppler speeds > 8 m/s² (`accel`); isMocked (`mocked`). Rejected points are stored with `accepted=false`. Flags: `speedTrusted` = speed ≥ 0 && speedAcc ≤ 1.5; `maxCandidate` = speedTrusted && hAcc ≤ 20 && speedAcc ≤ 1.0; `altAnchor` = vAcc ≤ 15. All rolling windows reset after a gap > 10 s (no interpolation).

**Speed.** v = Doppler if speedTrusted else Haversine/dt over the last ≥ 3 s of accepted fixes; zero-clamp < 0.8 m/s. Display = median-of-3 → EMA α 0.4. Max speed: `maxCandidate` inside RUN only, confirmed when ≥ 2 of 3 consecutive candidates lie within 15 % of it; hard cap 45 m/s; stored with ts + segment id. Avg speed per run = distance / moving time (v ≥ 0.8).

**Altitude fusion.** h_baro = 44330.8 · (1 − (p/1013.25)^0.19026). h_fused = a + k · h_baro. a = median(gpsAlt − h_baro) over the first 10 altAnchor fixes (GPS-only until then), then EMA α 0.02 per altAnchor fix. k = 1.0; updated only when the window since the last k-update spans ≥ 80 m of barometric change: k_obs = ΔgpsAlt/Δh_baro over that window (weighted by 1/vAcc²), k ← 0.8·k + 0.2·k_obs, clamped 0.85–1.15 (`kBaroScaleCorrectionEnabled = true`). Result: < 1 m relative precision, GPS-anchored absolute within ~3 m, cold-air scale error corrected after the first lift. Fallback without barometer (no sensor / Motion denied): h_fused = EMA α 0.3 of gpsAlt over altAnchor fixes; vertical thresholds × 2.5; `hasBarometer=false` on the day. Anchor is never persisted across days.

**Vertical.** Turning-point hysteresis on h_fused: running extreme; when altitude moved ≥ 10 m (baro) / ≥ 25 m (GPS-only) away in the opposite direction, commit and flip. UI Höhenmeter per run = run start alt − run end alt (from segmenter); day total = Σ run drops; hysteresis totals are diagnostics.

**Distance.** Haversine between consecutive accepted fixes, added only when v ≥ 0.8 m/s and dt ≤ 5 s. Ski-km = Σ inside RUN, Lift-km = Σ inside LIFT, never summed in the UI.

**Segmenter (1 Hz state machine; states STOP, RUN, LIFT, OTHER; inputs v_h = display speed, v_z10 / v_z30 = least-squares slope of h_fused over 10 s / 30 s, gained60 = h_fused − min over 60 s, gap flag).**
- STOP: v_h < 0.8 m/s for ≥ 10 s; exit when v_h ≥ 1.5 m/s for 3 s.
- LIFT enter: (v_z30 ≥ +0.8 m/s for ≥ 20 s OR gained60 ≥ 30 m) with v_h ≤ 8 m/s, OR GPS gap > 30 s with ≥ 30 m barometric gain. LIFT exit: v_z30 ≤ +0.2 for ≥ 15 s or v_z10 ≤ −0.7. Valid if ≥ 60 s and ≥ +30 m, else OTHER.
- RUN enter: v_z10 ≤ −0.7 m/s AND v_h ≥ 2 m/s in ≥ 8 of the last 10 ticks. RUN exit: LIFT condition, STOP lasting ≥ 45 s (shorter stops absorbed), or flat (|v_z30| < 0.3 && v_h < 2) for ≥ 60 s. Valid if ≥ 60 s and ≥ 40 m drop, else merged into neighbour; two runs separated by STOP < 45 s merge.
- OTHER: everything else (walking, traverses); shown as 'Sonstiges' inside Pause.
- SIGNAL LOSS: gap > 120 s without accepted fixes → its own bucket, never Pause.
- Guards: **vehicle** = v_h > 30 m/s sustained 60 s → OTHER with `vehicle` flag (never RUN); persisting 5 min → auto-end the day at vehicle start + notification. **idle** = STOP > 90 min after last run → notification 'Noch am Fahren?'; > 180 min → auto-end with trailing idle trimmed. **4 h reminder** notification. **meaningful day**: < 100 m distance or < 60 s moving → discard silently on End. **restart merge**: Start ≤ 4 h after End, same resort → append.

**Stats.** Per run: duration, moving time, drop, distance, confirmed max speed (+ts), avg speed, avg gradient % = drop / horizontal distance, steepest 100 m window, start/end alt. Per day: runs, lifts, drop, ascent, ski/lift/total distance, ski/lift/pause/signal-loss/other ms, elapsed, max/min alt, longest run (drop & distance), best run, accepted/rejected fixes, stream restarts, hasBarometer, vehicle flag. All durations from fix timestamps. GPS quality words: rolling 10 s median hAcc ≤ 5 'Sehr gut', ≤ 10 'Gut', ≤ 20 'OK', > 20 'Schwach'; no accepted fix for 10 s → 'Kein GPS – Höhe über Barometer'.

**Testing.** `SyntheticDayGenerator` (lifts, runs with gradient, stops, GPS noise σ, dropouts, pressure drift, temperature scale) → property tests: run count exact, drop within 3 %, no RUN inside LIFT, live == offline. Recorded fixtures `app/test/fixtures/*.json` (diagnostics bundle format) with expected counts; acceptance target = founder's 27.12.2025 day (7 runs, 1 804 m, 67.8 km/h) once recorded. No threshold changes without a fixture regression run.

## 6. Background tracking

### iOS (exact config)
- `Info.plist`: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationTemporaryUsageDescriptionDictionary` { `Tracking`: … }, `NSMotionUsageDescription` (CMAltimeter), `UIBackgroundModes = [location]` **only**, `ITSAppUsesNonExemptEncryption = false`, `CFBundleLocalizations = [de, en]`, `CFBundleDisplayName = Schwung`. Purpose strings localised via `ios/Runner/de.lproj/InfoPlist.strings` and `en.lproj/InfoPlist.strings`:
  - WhenInUse (de): 'Schwung braucht deinen Standort, um Geschwindigkeit, Abfahrten und Höhenmeter aufzuzeichnen.'
  - Always (de): 'Nur so läuft die Aufnahme weiter, wenn dein iPhone gesperrt in der Jacke steckt, und kann nach einem Neustart fortgesetzt werden.'
  - Motion (de): 'Der Luftdrucksensor macht Höhenmeter auf den Meter genau.'
  - Temporary full accuracy (de): 'Ohne genaue Position können Abfahrten nicht erkannt werden.'
- Xcode: Signing & Capabilities → Background Modes → Location updates; automatic signing, Team `5GDU97KSQU`; deployment target iOS 16.0.
- `Podfile` post_install: `PERMISSION_LOCATION=1`, `PERMISSION_SENSORS=1`, `PERMISSION_NOTIFICATIONS=1`, all other permission_handler macros 0.
- `PrivacyInfo.xcprivacy`: required-reason APIs UserDefaults (CA92.1), file timestamp (C617.1), disk space (E174.1); data types Precise Location + Fitness, not linked, not for tracking.
- Stream: `Geolocator.getPositionStream(locationSettings: AppleSettings(accuracy: LocationAccuracy.best, distanceFilter: 0, activityType: ActivityType.fitness, pauseLocationUpdatesAutomatically: false, allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true))`, subscribed only in `RecordingController.startDay()` and cancelled in `endDay()`.
- Before every Start: `Geolocator.getLocationAccuracy()`; if reduced → `requestTemporaryFullAccuracy(purposeKey: 'Tracking')`; still reduced → Start blocked with the 'Genau ein' card.
- Stream watchdog: active day, no fix for 60 s, `isLocationServiceEnabled` && permission OK → cancel + resubscribe; `streamRestarts++` on the day, Sentry breadcrumb.
- Relaunch after kill (needs Always): `ios/Runner/TrackingWatchdog.swift` (~60 lines) — MethodChannel `de.torchtechnology.schwung/watchdog` with `start` (startMonitoringSignificantLocationChanges) / `stop` / `didLaunchFromLocation`; `AppDelegate` records `launchOptions[.location]`. `main()` checks for an active day before `runApp` and resumes the stream headlessly.
- Recording state: in-app pill + tab-bar dot are primary; the iOS blue indicator is expected with `showBackgroundLocationIndicator: true` (verified in QA for both While-Using and Always).

### Android (builds, no device QA)
- `AndroidSettings(accuracy: LocationAccuracy.best, distanceFilter: 0, intervalDuration: Duration(seconds: 1), foregroundNotificationConfig: ForegroundNotificationConfig(notificationTitle: 'Aufnahme läuft', notificationText: 'Schwung zeichnet deinen Skitag auf', enableWakeLock: true, setOngoing: true, notificationIcon: AndroidResource(name: 'ic_notification')))`.
- Manifest: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`; geolocator's service with `foregroundServiceType="location"`; minSdk 24, targetSdk 35. Barometer via sensors_plus TYPE_PRESSURE (no permission).

### Crash safety (both platforms)
No emergency path. Every tick's `TrackPoint` goes into a write buffer flushed in one drift transaction every 10 points or 5 s; the `days` row (status `active`) carries `lastFixAt` and running aggregates in the same transaction. `WidgetsBindingObserver` paused/detached → flush now. On launch: active day with lastFixAt < 30 min → restart stream, rebuild segmenter state from the last 120 s of points, continue silently; older → recovery card. Memory holds only a 300-point ring for the map sheet.

### Battery
Budget ≤ 8 %/h screen-off. Measured on the first device day with Xcode Energy Log. Estimate on the live screen from the last 30 min drain; notification at 15 %. No network, no map, no chart rebuilds while backgrounded.

## 7. Packages (see structured list; versions verified against pub.dev as of Sep 2026 — run `flutter pub outdated` at S0)

geolocator 14.0.3 · permission_handler 13.0.2 · sensors_plus 7.1.0 · battery_plus 6.2 · drift 2.35 + drift_flutter + sqlite3_flutter_libs (dev drift_dev, build_runner) · flutter_riverpod 3.4 · flutter_map 8.3.2 + latlong2 · flutter_map_location_marker 10.3 · flutter_map_cache 2.1 + dio + dio_cache_interceptor + http_cache_file_store · fl_chart 1.2 · flutter_local_notifications 22.3 · share_plus 13.3 · xml 6.6 · video_player 2.14 · shared_preferences 2.5 · uuid 4.5 · intl 0.20 + flutter_localizations · http 1.5 · path_provider 2.1 · package_info_plus 8.3 · url_launcher 6.3 · sentry_flutter 9.x · collection · dev: flutter_launcher_icons 0.14.4, flutter_native_splash 2.4, flutter_lints 6. Not used: go_router, freezed, riverpod_generator, flutter_map_tile_caching (GPL), mapbox_maps_flutter, live_activities (v1.1), flutter_background_geolocation (fallback only).

## 8. Architecture and folder tree

```
app/                                  Flutter project (flutter create --org de.torchtechnology schuss)
  pubspec.yaml                        LEAD
  lib/
    main.dart                         LEAD: Sentry init, ProviderScope, headless resume check, runApp
    app/                              LEAD
      app.dart                        MaterialApp, ThemeMode.system, locale delegates
      brand.dart                      const kAppName = 'Schwung'; kBundleId; kSupportEmail
      router.dart                     Routes: '/', '/day/:id', '/summary/:id', '/onboarding', '/map' (sheet), '/settings' (sheet)
      placeholders.dart               stub screens used until WP-12 wires the real ones
      theme/tokens.dart               colours, spacing, radii, motion durations
      theme/typography.dart           text styles (display/hero/body/label), tabular figures
      theme/theme.dart                ThemeData dark + light
      l10n/app_locale.dart            AppLocale.of(context).pick(de:, en:); localeProvider
      widgets/                        AppCard, PrimaryButton, HoldToConfirmButton, HeroNumber, StatTile,
                                      StackedTimeBar, RecordingPill, StateChip, Sheet, EmptyState, MascotCard(video)
    core/                             LEAD (pure Dart)
      constants.dart                  every threshold (§5), TrackingConfig
      models/                         RawFix, PressureSample, TrackPoint, Segment, DayStats, LiveState, enums
      geo/haversine.dart, geo/bearing.dart, geo/circular.dart
      units/format.dart               km/h, m, hm, mm:ss, locale-aware via intl
      season.dart                     seasonKey(ts) Jul 1 – Jun 30, label '2025/26'
    tracking/                         WP-01 (pure Dart): gate, speed_estimator, altitude_fuser, vertical_accumulator,
                                      segmenter, day_stats, engine, compute_day, synthetic_day, gps_quality
    data/
      db/                             WP-02: database.dart, tables.dart, daos/*, migrations
      prefs/                          WP-02: SettingsRepository (shared_preferences)
      resorts/                        WP-02: ResortRepository (assets/resorts.json), nearest within radius
      weather/                        WP-11: OpenMeteoClient, WeatherSnapshot, wmo.dart, cache
    platform/                         WP-03: LocationSource, BarometerSource, BatterySource, PermissionService,
                                      NotificationService, WatchdogChannel, fakes/
    features/
      recording/                      WP-05: RecordingController, BatchWriter, RecoveryService, Guards, live providers
      onboarding/                     WP-06
      today/                          WP-07: HeuteScreen (idle+live), RecoveryCard
      summary/                        WP-07: TagesbilanzScreen
      settings/                       WP-07: SettingsSheet, DiagnosticsPage
      days/                           WP-08: TageScreen, DayDetailScreen, RunList, StatsGrid
      map/                            WP-09: TrackMap (shared), MapSheet, ThumbnailRenderer, tile config
      profile/                        WP-10: AltitudeProfile (fl_chart)
      share/                          WP-10: ShareCard, GpxExporter, DiagnosticsBundle, ShareService
      weather/                        WP-11: WeatherLine widget
  assets/                             WP-04: icon/, mascot/, fonts/, resorts.json
  ios/, android/                      WP-03 (platform config) — Runner/TrackingWatchdog.swift, Info.plist, Podfile, manifest
  test/                               per WP; test/support/ (LEAD): fake providers, pump helpers
  integration_test/                   WP-12
tools/                                WP-04: make_icon.py, fal_generate_mascot.py, build_resorts.py; LEAD: rename_app.sh, ci.sh
docs/ANALYSIS.md, docs/PLAN.md, docs/QA.md
```

**State.** Riverpod 3, no codegen. Contracts (defined by the lead in `app/lib/app/router.dart` comments and `test/support/`; implemented by the owning WP):
- `recordingControllerProvider: NotifierProvider<RecordingController, RecordingState>` (keepAlive) — `startDay()`, `endDay()`, `discardDay()`, `resumeIfActive()`; `RecordingState{status: idle|starting|recording|ending, dayId?, startedAt?}`.
- `liveStateProvider: Provider<LiveState>` (1 Hz while resumed) — hero numbers, speed, alt, elapsed, time buckets, gpsQuality, motionState, lastRun, batteryEta.
- `daysListProvider: StreamProvider<List<DaySummary>>`, `dayDetailProvider(id): FutureProvider<DayDetail>`, `seasonTotalsProvider`, `personalBestsProvider`.
- `settingsProvider: NotifierProvider<SettingsNotifier, Settings>`; `permissionStatusProvider`; `resortProvider(LatLng)`; `weatherProvider(Resort)`.
- Sources are interfaces (`LocationSource`, `BarometerSource`, `BatterySource`) with fakes replaying fixtures at 100×.

**Persistence.** drift single source of truth; UI reads streams from drift, live view reads `liveStateProvider`. Soft delete days (`deletedAt`) + hard delete their points.

**Config.** `--dart-define-from-file=env/prod.json` with `MAP_TILE_URL`, `SENTRY_DSN`; `env/` is gitignored; `env/example.json` committed.

## 9. Data model (drift, SI units, ms epoch)

```dart
// app/lib/core/models (shared contracts)
class RawFix { final int ts; final double lat, lon, hAccM; final double? gpsAltM, vAccM, speedMs, speedAccMs, courseDeg; final bool isMocked; }
class PressureSample { final int ts; final double hPa; }
enum RejectReason { none, stale, nonMonotonic, hAcc, altitudeRange, impliedSpeed, accel, mocked }
enum MotionState { unknown, stop, run, lift, other }
enum SegmentKind { run, lift, stop, other, signalLoss }
class TrackPoint { int ts; double? lat, lon, hAccM, gpsAltM, vAccM, speedMs, speedAccMs, courseDeg, pressureHpa, fusedAltM; bool accepted; RejectReason rejectReason; MotionState state; }
class Segment { String id, dayId; SegmentKind kind; int idx; int? runNumber; int startTs, endTs; double startAltM, endAltM, dropM, distanceM; int movingMs; double maxSpeedMs; int? maxSpeedAtTs; double avgSpeedMs, avgGradientPct; double? steepest100mPct; int startPointId, endPointId; int flags; String? pisteName, pisteOsmId, liftName; }
class DayStats { int elapsedMs, skiMs, liftMs, pauseMs, signalLossMs, otherMs, runCount, liftCount; double dropM, ascentM, skiDistanceM, liftDistanceM, totalDistanceM, maxSpeedMs, avgSkiSpeedMs, maxAltM, minAltM; String? maxSpeedSegmentId, longestRunSegmentId; int acceptedFixes, rejectedFixes; bool hasBarometer, vehicleFlag; }
class LiveState { DayStats stats; double speedMs; double? altM; MotionState state; GpsQuality gps; Segment? lastRun; int? batteryEtaTs; }
```

Tables:
- `days(id TEXT PK uuid7, startedAt INT, endedAt INT?, status TEXT active|finished|discarded, resortId TEXT?, resortName TEXT?, lastFixAt INT, engineVersion INT, streamRestarts INT, weatherJson TEXT?, mapThumbPath TEXT?, + all DayStats columns, schemaVersion INT, createdAt, updatedAt, deletedAt?)` — index startedAt DESC, status.
- `segments(… Segment fields …)` — index (dayId, idx).
- `points(id INTEGER PK autoinc, dayId TEXT FK, … TrackPoint fields …)` — index (dayId, ts). Raw values only; fusedAltM is the only derived column (for the profile).
- Derived by SQL, never stored: personal bests (MAX over days/segments), season totals (GROUP BY seasonKey), streaks.
- `assets/resorts.json`: `[{id, name, country, lat, lon, radiusKm, baseAltM, summitAltM}]`, ~40 Alpine resorts; resort = nearest centre within radiusKm at first accepted fix, else 'Freies Gelände'.
- Settings (shared_preferences): `locale` (system|de|en), `onboardingDone`, `notificationsOptIn`, `lastResortId`.
- Exports: GPX 1.1 (one `<trk>`, one `<trkseg>` per run/lift, `<ele>` = fusedAltM, namespaces on root, `gpxtpx:speed`), diagnostics bundle = gzip JSON `{day, segments, points[], engineVersion, device}`.

## 10. Map strategy

flutter_map 8 raster, single `TileLayer(urlTemplate: kTileUrlTemplate)` where `kTileUrlTemplate` = `MAP_TILE_URL` dart-define, default `https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}@2x?access_token=…` (Outdoors already draws OSM pistes by difficulty, lifts, hillshade — zero hand-made piste data). No-key fallback used automatically when `MAP_TILE_URL` is empty: OpenTopoMap base + OpenSnowMap overlay (`https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png`, ODbL attribution) — dev/TestFlight only, policy check before store release. Cache: flutter_map_cache with `HttpCacheFileStore`, maxStale 30 days, stale-if-error. Layers: track polylines (runs champagne 4 px + 12 px 25 % glow, lifts dashed grey 2 px, stops hidden), start/end + scrub markers, location puck with heading (sheet only). Live: 2D, zoom 15 follow-me, polylines rebuilt ≤ every 2 s from the 300-point ring. Detail: fitBounds padding 48. Day-card thumbnails rendered once at End via RepaintBoundary → PNG (`mapThumbPath`); the list never loads tiles. Cost v1: €0.

## 11. Design system (`app/lib/app/theme/tokens.dart`)

| Token | Value | Use |
|---|---|---|
| bg / surface / elevated / hairline | #0B0B0C / #141416 / #1E1E21 / #2A2A2E | graphite scale (ShapeMe DNA); live screen uses pure #000 |
| textPrimary / secondary / tertiary | #F5F2EA / #9A9A9F / #5C5C62 | numbers always textPrimary, ≥ 7:1 contrast |
| champagne / champagnePressed | #D9C39A / #C4AC80 | Start button, run track, PB chips, share card — the family link |
| ice | #BFE3F2 | live speed, GPS 'Gut', recording pill dot |
| danger | #FF5A4A | 'Schwach', hold-to-end ring, delete |
| liftGrey | #6B6B70 | dashed lift lines, lift bar segment |
| piste colours | from tiles only | never drawn by us |
| light theme | bg #F5F2EA, surface #FFFFFF, ink #101012, champagne #8E6F2E, ice #0E7BB0 | ThemeMode.system, no toggle |
| type | display Inter Tight 800/900 (bundled); body Inter 400/600; `FontFeature.tabularFigures()` on all numbers | hero 88 (72 on ≤ 375 pt wide), stat 34, body 17, label 11 uppercase +0.06 em |
| layout | 8 pt grid, 20 pt padding, radius 16, targets ≥ 56 pt, Start 72 pt, hold-to-end 64 pt in the bottom 30 % | glove-friendly |
| motion | count-up 400 ms easeOutCubic; hold ring 1.2 s; Start pulse once after onboarding; recording dot 1.2 s; nothing else moves live | reduce-motion aware |
| haptics | medium on Start and run committed; heavy on End and PB; light tick on new top speed | |
| copy | sentence case German, ski vocabulary: Abfahrt, Höhenmeter, Liftfahrt, Pause, Gefälle, Skitag; '–' for undefined, never '0' | |
| share card | 1080×1350, graphite, champagne numbers, mini route, `kAppName` wordmark bottom-right | |

## 12. Logo spec

Same construction rules as the ShapeMe icon so the two read as a family on a home screen: cream field #F5F2EA, ink #101012, no gradients, no text, two shapes only. Mark = a rounded diamond outline (rotated square, the piste-sign shape, stroke 8 % of width, corner radius 6 %) containing one bold diagonal 'schuss' stroke from upper-left to lower-right (stroke 11 % of width, matching the ShapeMe 'S' weight) that flattens into a short horizontal at the bottom-right — reads as fall line / vertical drop and as a stylised S. Legible at 29 pt. Deliverables from `tools/make_icon.py` (parametric SVG on a 1024 grid, geometry on 64 px multiples, rasterised with cairosvg): `assets/icon/icon.svg`, `icon_1024.png` (no alpha), `icon_dark_1024.png` (ink field, cream mark, for iOS 18 dark/tinted), `adaptive_fg.png` / `adaptive_bg.png` (Android), `mark_mono.svg` (tab bar, notifications, share card). Generated via flutter_launcher_icons (`remove_alpha_ios: true`, `background_color_ios: '#F5F2EA'`) and flutter_native_splash (cream, mark centred). The legacy gold crossed-skis/snowflake artwork is discarded.

## 13. Mascot spec ('Toni')

Photorealistic Austrian ski guide, mid-30s, weathered face, short beard, goggles pushed up on a dark beanie, matte champagne shell jacket over graphite layers (the palette worn as clothing), flat winter light on a groomed piste with peaks behind. Calm, dry Tyrolean humour, informal 'du', never shouts, never coaches technique. Sibling of ShapeMe's coach: same production style (AI photoreal video, 16:9 card, one caption line), different setting and temperament.

Usage: onboarding cards 1–3, empty states (Heute without data, Tage), Tagesbilanz still + one rule-based line (first day / PB day / > 10 runs / > 2 000 hm / short day). Never on the live screen, never during the day.

Generation (`tools/fal_generate_mascot.py`, `FAL_KEY` from env, prompts + seeds committed in `tools/mascot_prompts.md`):
1. Reference still — fal.ai `fal-ai/flux-pro/v1.1` (or Seedream 4), seed fixed, prompt: *"Photorealistic portrait of an Austrian mountain ski guide in his mid-thirties, weathered tanned face, short dark beard, dark grey wool beanie, ski goggles pushed up onto the beanie, matte champagne-beige technical shell jacket over charcoal mid-layer, standing on a groomed alpine piste, flat overcast winter light, snow-covered Kitzbühel Alps behind, calm confident half-smile looking into the camera, 50 mm lens, shallow depth of field, natural skin texture, no text, no logos"*. Negative: cartoon, illustration, logo, text, extra fingers, oversaturated.
2. Three clips — fal.ai `fal-ai/bytedance/seedance/v1/pro/image-to-video` from the still, 1280×720, 5 s, muted: (a) *"skids to a stop on skis, sprays a little snow, looks into the camera and nods"*; (b) *"taps a phone once, slides it into the chest pocket of his jacket, zips it, nods"*; (c) *"sits on a chairlift, phone in pocket, looks at the mountains, gives a small thumbs up"*.
3. ffmpeg: trim to a seamless loop (12-frame crossfade), H.264 crf 26, `-an`, `-movflags +faststart`, ≤ 1.5 MB each → `assets/mascot/toni_stop.mp4`, `toni_pocket.mp4`, `toni_lift.mp4`; poster JPEGs and one `toni_still.jpg` for empty states. Budget 20–30 generations; ship stills if clip consistency is not reached.

## 14. TestFlight checklist

1. App Store Connect record under Team 5GDU97KSQU, bundle id `de.torchtechnology.schwung`, primary language German, category Health & Fitness; name availability checked.
2. Xcode 26.3: iOS 16.0 target, automatic signing, Background Modes → Location updates only; Push off.
3. Info.plist keys and `InfoPlist.strings` de/en as in §6; `PrivacyInfo.xcprivacy` present; App Privacy answers: Precise Location + Fitness for app functionality, not linked, no tracking; crash data via Sentry.
4. Podfile macros LOCATION/SENSORS/NOTIFICATIONS = 1; `pod install` clean; Release build without warnings-as-errors.
5. Icons (no alpha) and splash generated; dark/tinted icon variants checked.
6. `env/prod.json` with `MAP_TILE_URL`, `SENTRY_DSN`; no secrets in git; `flutter build ipa --release --dart-define-from-file=env/prod.json --export-method app-store`.
7. Device protocol (physical iPhone, Release build): (a) 60 min locked in pocket walking/cycling → continuous 1 Hz points, no gaps > 5 s, blue indicator visible; (b) swipe-kill mid-day → relaunch: silent resume (< 30 min) and watchdog relaunch with Always after moving ≥ 500 m; (c) permission matrix Always / While Using / Allow Once / Denied / Precise off → defined screen for each, Start blocked on reduced accuracy; (d) Motion denied → GPS-only fallback flagged in diagnostics; (e) airplane mode → tracking unaffected, cached tiles shown; (f) 3 h locked run → %/h recorded, ≤ 8 %/h; (g) barometer samples continue in background (diagnostics counter).
8. Fixture run: one mountain descent/ascent day (Hintertux/Stubai glacier in October or a car/e-bike pass descent) → diagnostics bundle committed as fixture; segmenter fixture suite green; live == offline test green.
9. Performance on a synthetic 6 h day (21 k points): Tage list < 100 ms, Tag detail < 500 ms, memory < 120 MB, no jank on profile scrub.
10. Localisation: DE sentence case, EN complete; no truncation at 375 pt width and Dynamic Type xxL (competitor's 'MAX. GESCHWINDI' bug).
11. Share sheet produces PNG + GPX; GPX validates in an external parser; delete day and delete all verified.
12. Sentry receives a test event from the Release build; no analytics SDKs.
13. Android: `flutter build apk --release` succeeds in CI (no SDK on this Mac).
14. Upload via Xcode Organizer / Transporter; TestFlight beta notes explain background location, the three prompts and outdoor testing; internal group (founder) first, then external; testers asked to share the diagnostics bundle after day one.

## 15. Build sequence and work packages (file ownership is disjoint; see structured `work_packages`)

| Wave | WP | Owner paths (under `app/` unless noted) | Depends on |
|---|---|---|---|
| 0 (serial, lead) | WP-00 Scaffold & contracts | pubspec.yaml, lib/main.dart, lib/app/**, lib/core/**, test/support/**, analysis_options.yaml, tools/ci.sh, tools/rename_app.sh, env/example.json | — |
| 1 (parallel) | WP-01 Tracking engine | lib/tracking/**, test/tracking/**, test/fixtures/** | 00 |
| 1 | WP-02 Data layer | lib/data/db/**, lib/data/prefs/**, lib/data/resorts/**, test/data/** | 00 |
| 1 | WP-03 Platform sources + iOS/Android config | lib/platform/**, ios/**, android/**, test/platform/** | 00 |
| 1 | WP-04 Design assets | assets/**, flutter_launcher_icons.yaml, flutter_native_splash.yaml, tools/make_icon.py, tools/fal_generate_mascot.py, tools/build_resorts.py, tools/mascot_prompts.md | 00 |
| 1 | WP-09 Map component | lib/features/map/**, test/features/map/** | 00 |
| 1 | WP-10 Profile chart + share/export | lib/features/profile/**, lib/features/share/**, test/features/share/** | 00 |
| 1 | WP-11 Weather | lib/data/weather/**, lib/features/weather/**, test/data/weather/** | 00 |
| 2 | WP-05 Recording controller | lib/features/recording/**, test/features/recording/** | 01, 02, 03 |
| 2 | WP-06 Onboarding | lib/features/onboarding/**, test/features/onboarding/** | 00, 03, 04 |
| 2 | WP-08 Tage list + Tag detail | lib/features/days/**, test/features/days/** | 02, 09, 10 |
| 3 | WP-07 Heute + Tagesbilanz + Settings/Diagnostics | lib/features/today/**, lib/features/summary/**, lib/features/settings/**, test/features/today/** | 05, 09, 10, 11 |
| 3 | WP-13 Apple Watch companion (SwiftUI watchOS target `SchwungWatch` in `ios/`, `watch_connectivity` bridge, `lib/platform/watch/**`): Start/End from the wrist, live Höhenmeter · Abfahrten · Top-Speed · Zeit, HKWorkoutSession for heart rate, HR stored per point | ios/SchwungWatch/**, lib/platform/watch/**, test/platform/watch/** | 03, 05 |
| 4 (serial, lead) | WP-12 Integration, device QA, TestFlight | lib/app/router.dart (swap placeholders), integration_test/**, docs/QA.md | all |

Estimated effort: wave 0 ½ day; wave 1 2–3 days in parallel; wave 2 2 days; wave 3 2 days; wave 4 2–3 days including two device days.

## 16. Risks

| Risk | Mitigation |
|---|---|
| iOS background continuity can only be proven on a real device over hours | two device days before the first TestFlight build; fallback flutter_background_geolocation behind the same `LocationSource` interface |
| App kill by iOS/user stops tracking | data is safe on disk; Swift watchdog relaunches with Always; recovery card otherwise |
| Segmenter thresholds untuned until real snow days | raw fixes stored, `engineVersion` + 'Neu berechnen', diagnostics bundle → fixtures, one glacier day in October |
| Barometer needs Motion & Fitness; denial → GPS-only vertical | explained in onboarding step 3; flagged per day; thresholds × 2.5 |
| sensors_plus barometer cadence in background unverified | QA item 7g; fallback = 30-line CMAltimeter MethodChannel in `platform/` |
| Battery 6–9 %/h at 1 Hz | measured; LocationAccuracy.best (not bestForNavigation); estimate + 15 % warning |
| Mapbox token/URL restriction setup; OpenSnowMap policy | tile URL is one dart-define; fallback wired; decide provider before store release |
| Open-Meteo non-commercial tier | weather is the first feature to cut; WeatherKit/paid tier before store release |
| 'Schwung' name/trademark | check before App Store Connect; rename is one constant + `tools/rename_app.sh` |
| Mascot clip consistency | fixed seed + prompt sheet, stills as fallback |
| App Review on Always | purpose string states the relaunch benefit; app fully works with While-Using; no 'processing' mode |
| No live map tab is the biggest product bet | MapSheet is a full component; promoting it to a tab is a one-day change |
