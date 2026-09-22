# Schwung — Legacy audit, competitor critique and v1 decisions

Date: 2026-09-22 · Author: lead architect · Status: final input for `docs/PLAN.md`

## 1. Executive summary

| Question | Answer |
|---|---|
| Can the legacy PWA (`js/`, ~17k lines) be ported? | No. Only 3 of 7 tracking modules are wired, the live path has fatal bugs (distance always 0, vertical drop almost never counted, 8–20 s speed/altitude lag), and background tracking is impossible in a PWA. |
| What is worth keeping? | ~10 small things: Haversine, hypsometric constants, CoreLocation config values, 8 resort centres, WMO code table, colour conventions, GPX filename convention, a few thresholds and product decisions. |
| Why is the competitor beatable? | It fragments a morning into three sessions, stops when the phone is locked, mixes ski and lift km, computes gradient over lifts, shows 16 zeros on the idle screen and runs ads. It captured well under a third of the founder's time on snow. |
| What does v1 have to nail? | Locked-phone tracking that never stops, honest numbers (barometer vertical, Doppler speed, auto run/lift/stop split), one Start / one End, a short onboarding with the mascot, a beautiful end-of-day summary. |

## 2. Legacy code audit

### 2.1 What actually runs

| File | Loaded by index.html | Status | Verdict |
|---|---|---|---|
| gps-tracker.js | yes | live path, broken Kalman filters, validation after filtering | drop, replace |
| stats.js | yes | distance always 0 (`distanceFromPrevious` never set), vertical drop only for >5 m/s descent | drop, replace |
| utils.js | yes | Haversine correct | port Haversine only |
| storage.js | yes | IndexedDB wrapper, works; one blob per run | replace with drift |
| supabase.js | yes | init never called at startup, epoch-ms into TIMESTAMPTZ, errors swallowed | drop for v1 |
| app.js | yes | 2 000+ lines of UI glue, emergencySave via pagehide, blocking confirm() | drop |
| map.js / visualization-3d.js | yes | never ran (placeholder Mapbox token); private `_data` access; speed colouring broken | drop |
| weather.js | yes | correct Open-Meteo usage, never called | port improved |
| achievements.js, audio.js, gpx.js, photos.js, theme-manager.js | yes | achievements/audio noisy; GPX import throws on every file, export not well-formed; photos keep only a 200 px thumbnail | drop (GPX export rebuilt) |
| activity-detector.js, barometer.js, slope-calculator.js, ski-style-detector.js | **no** | dead; units mismatch, typo'd config keys, Web APIs that do not exist on iOS | drop; keep the *ideas* (auto segmentation, barometer fusion) |
| background-geolocation.js, analytics.js, ratelimiter.js, store.js, sync-manager.js, resort-manager.js, segments.js, i18n.js, deeplink.js, heart-rate.js | **no** | dead; hallucinated Capacitor API, inverted wake lock, mocked uploads, Math.random leaderboards | drop |
| csrf-protection.js, security-utils.js, request-utils.js, timer-manager.js, error-boundary.js, logger.js | partly | web-only theatre (client-side CSRF, 5-minute timer reaper) | drop |
| sw.js | yes | non-GET requests never queued, precache fails atomically | drop |
| supabase/functions/scrape-slopes | deployed | fabricates per-difficulty counts (25/45/30) and Streif/Hahnenkamm status; no cron; ToS risk | drop |
| assets/trails/kitzbuehel.geojson, -details.json | yes | synthetic geometry north of town; every lift 'open' | drop |

### 2.2 Severe correctness bugs in the live path

| # | Bug | Effect |
|---|---|---|
| 1 | `Stats.updateFromPosition` reads `distanceFromPrevious`, never produced | every saved run has distance = 0 km |
| 2 | vertical drop only counted when a sample descends >5 m in one fix (>5 m/s) | normal piste skiing accrues ~0 Höhenmeter |
| 3 | scalar speed Kalman Q=0.01, R≈0.5–1 → 8–10 s time constant | max speed under-reported by 30–60 % |
| 4 | altitude Kalman + 10-sample median → 15–20 s lag | displayed altitude 60–100 m stale on a descent |
| 5 | 2D Kalman: asymmetric covariance update, velocity variance grows unbounded, R ≈ hAcc/5 (should be hAcc²) | filter degrades to a noisy pass-through, jumps after any gap >10 s |
| 6 | `requestPermission()` calls `processPosition()` before `initKalmanFilters()` | first Start after page load throws |
| 7 | validation runs after the fix has been fed into all filters | bad fixes pollute every estimate |
| 8 | only filtered values stored, km/h in one module and m/s in another | nothing can be recomputed later |
| 9 | background = Screen Wake Lock only | tracking stops on lock (the founder's #1 complaint; a platform limit, not a bug) |
| 10 | flush to IndexedDB only after 5 000 points (~83 min), never read at startup; emergencyRun 1 h window | 'crash safety' protects nothing |

### 2.3 Data layer and backend

| Item | Finding | v1 decision |
|---|---|---|
| Run entity | a 'run' is the whole Start-to-End session; no run/lift/stop segmentation anywhere | new model: day → segments → points |
| Supabase runs table | no client id, no updated_at/deleted_at, no UPDATE policy; `user_records` view not `security_invoker` (leaks all users' aggregates); `update_slope_status()` SECURITY DEFINER without auth check | no cloud in v1; schema kept only as seed for a v2 backup |
| Sync | never worked (init not called, Background Sync absent on iOS, failures marked synced) | drop; data model is sync-ready (uuid v7, updated_at, deleted_at) |
| Records | persisted, stale after delete | derive by SQL |
| Encryption | AES-GCM module unused | drop; iOS Data Protection suffices |
| Resorts | two conflicting catalogues (170 km/57 lifts vs 233 km/56; official KitzSki ≈ 233 km/58); centres accurate, stats guessed | keep 8 centres as seeds, no stats |
| Weather | Open-Meteo request shape correct, no elevation, memory-only cache | port improved; licence question (non-commercial tier) before store release |

### 2.4 Reusable assets (complete list)

| Asset | Where | Use in v1 |
|---|---|---|
| Haversine (R = 6 371 000) | js/utils.js | `core/geo/haversine.dart` (or Geolocator.distanceBetween) — one implementation |
| Hypsometric constants P0 1013.25, exponent 0.19026, 44 330.8 m | js/barometer.js | `tracking/altitude_fuser.dart` |
| CLLocationManager config: fitness, pausesAutomatically=false, allowsBackground=true, showsIndicator=true | js/background-geolocation.js | `platform/location_source.dart` (distanceFilter 5 m → 0) |
| GPS accuracy tiers ≤5/≤10/≤20 m | js/gps-tracker.js | GPS quality words (Sehr gut / Gut / OK / Schwach) |
| 8 resort centres | js/resorts.js | seeds for `assets/resorts.json` |
| WMO weather code table (25 codes), 16-point compass | js/weather.js | `data/weather/wmo.dart` collapsed to 8 buckets |
| Speed ramp 0/30/60 km/h, difficulty colours blue/red/black | css, visualization-3d.js | map polylines, tokens |
| GPX 1.1 layout + filename `schwung-YYYY-MM-DD-<id6>.gpx` | js/gpx.js | `features/share/gpx_exporter.dart` with namespaces fixed |
| Thresholds: MIN_ACCURACY 30 m, max age 5 s, save gate | config.js/app.js | `core/constants.dart` (gate raised to 100 m / 60 s) |
| Product decisions: auto-pause disabled, short-run discard | app.js | segmenter design |
| German key inventory (~125 keys) | js/i18n.js | checklist only; copy rewritten in sentence case (Abfahrt, Höhenmeter, Liftfahrt, Gefälle) |

Everything else — Kalman filters, ski-style detection, slope/avalanche, segments/leaderboards, achievements, photos, audio, 3D, GPX import, scraper, resort details, deep links, heart rate, analytics, CSRF, rate limiter, service worker — is discarded.

## 3. Competitor critique ("Ski Tracker", German localisation of a Dutch indie app)

| Screen | Main failures | Ideas worth keeping |
|---|---|---|
| Dashboard (IMG_1886) | 16 grey zeros before doing anything; tiny Start in the header, second unrelated 'FAST RIDE' timer; '+NAP' jargon, 'Steigung' overloaded, typo 'Durschnittsg.'; ad banner; raw DMS coordinates; light grey on white in snow glare | Ski / Lift / Rest time split (as one stacked bar); max & min altitude; GPS-quality intent |
| Map (IMG_1887) | opens zoomed out to Salzburg, no marker, no pistes, no track; cryptic collapsed 'Höhe (d)' | relief + locate button; scrubbable profile under the map |
| History list (IMG_1888) | grouped by calendar month (a season spans Dec–Apr); two taps to a session; 85 % empty; km silently sums ski + lift | group-level aggregates (should be season → day) |
| History detail (IMG_1889) | one morning = three sessions; 'Gefälle 19°' for a session with 0 runs; 14 numbers per card, 'MAX. GESCHWINDI' truncated; no map, no run list | the metric set itself (runs, lifts, vertical, time split, max speed, altitude range) |

## 4. Founder data insights (from the competitor screenshots)

| Observation | Evidence | Consequence for Schwung |
|---|---|---|
| Tracking died twice in the first 20 min | sessions at 09:20:41, 09:32:17, 09:40:14 with 31 s / 56 s gaps | day is the primary object; Start within 4 h at the same resort appends silently; relaunch watchdog |
| A lift ride alone became a 'session' | 1 lift, 0 runs, +512 m in 5:57, then stopped at the top | tracking must survive a locked phone in a gondola; baro-only ticks during GPS gaps |
| 106 m altitude jump in 31 s | session 1 min 1 554 m → session 2 min 1 448 m | GPS-only altitude is not good enough; barometer fusion is mandatory |
| Day ended silently at ~11:08 | December day started 09:20 | under-recorded by 3–5 h; stream watchdog + guards + 4 h reminder |
| 46 % 'Pausen' | 40:50 rest vs 20:13 ski in session 3 | missing fixes must be 'Signalverlust', never Pause; stops <45 s merge into runs |
| Garbage gradient | 19° with 0 runs, 8° for real runs | gradient only per run, drop / horizontal distance |
| Day totals hide the good numbers | 7 runs, 1 804 m, 67.8 km/h never surfaced at day level; '22.3 km' mixes ski + lift | hero numbers Höhenmeter · Abfahrten · Top-Speed; ski-km and lift-km never summed |
| Short laps | ~3.4 min, ~243 m per run | segmenter needs time hysteresis and a 40 m / 60 s minimum |
| Usage | 9 h 06 min tracked across two seasons | reliability, not features, is the product |
| Acceptance target | 27.12.2025: 7 runs, 1 804 m descent, 67.8 km/h, 1 448–1 963 m | first fixture acceptance test (±1 run, ±5 % drop, ±3 km/h) |

## 5. Proposal synthesis

| Proposal | Score (3 judges) | Taken |
|---|---|---|
| P1 Simplicity-first ('Schwung') | 39 / 39 / 42 — winner | base: 2 tabs, Heute idle+live, map sheet, recovery card, pure-Dart tracking layer, drift as source of truth, design tokens, 3-step onboarding |
| P2 Accuracy-first | 37 / 37 / 39 | 1 Hz tick engine, baro pre-filter + scale factor, stream watchdog, vehicle/idle guards, Swift watchdog, diagnostics bundle, battery estimate, live==offline test, synthetic day generator, LocationAccuracy.best, state chip |
| P3 Delight-first | 32 / 31 / 33 | Tagesbilanz screen, run-committed haptic, Signalverlust bucket, contextual notification opt-in, permission matrix QA, Dynamic Type check, season key Jul–Jun, reserved piste/lift name columns; **rejected**: dropping the Motion & Fitness prompt (CMAltimeter needs it), piste map-matching pipeline, first-name/units onboarding step, confetti, Live Activity |

## 6. Keep / drop matrix for v1

| Keep (v1) | Drop (v1) | Deferred (v1.1+) |
|---|---|---|
| Locked-phone tracking, crash-safe autosave, silent resume, recovery card | Manual pause, second timer, Kalman filters | Live Activity / Dynamic Island |
| Auto run/lift/stop/other/signal-loss segmentation, per-run stats | Slope-angle map colouring, avalanche wording, ski-style | Piste naming via OpenSkiMap (columns reserved) |
| Barometer-fused altitude, Doppler speed, hysteresis vertical | Achievements, photos, audio, heart rate, 3D replay | Cloud backup behind Sign in with Apple |
| Heute (idle+live), Tage, Tag detail, Tagesbilanz, map sheet | Live lift status / scraper, resort details, resort picker | Apple Watch companion (WP-13, second TestFlight build); HealthKit workouts |
| Personal bests + season totals by SQL | Segments/leaderboards, deep links, analytics | Opt-in social: resort/country leaderboards + group days ≤ 3 (v1.5, Supabase); ARB migration of strings |
| Share PNG card + GPX export, delete day, delete all | GPX import, JSON export, units/theme toggles | Android device QA, Play Store |
| Resort auto-detect (bundled list), weather one-liner (lowest priority) | fr/it/es | WeatherKit or paid Open-Meteo before store release |
| Sentry crash reporting, hidden diagnostics | CSRF, rate limiter, encryption, service worker | Offline map regions |

## 7. Additional competitor benchmarks (added 2026-09-22 by the lead)

Full notes: `docs/competitors/bergfex-ski.md`, `docs/competitors/slopes.md`, `docs/competitors/skiline.md`.

| App | Positioning | What we match in v1 | What we skip |
|---|---|---|---|
| bergfex Ski | Austrian portal: resort info, webcams, snow reports, precipitation maps, community rankings, whole-day recording | Whole-day model, time split, altitude profile, resort auto-naming, lifts/snow/forecast numbers (v1.1 'Gebiet') | Webcams, precipitation maps, 5-tab portal, community |
| Slopes | Apple Design Award 2022; premium tracker with Watch, replays, 3D/AR, friends, trips, share cards | Day summary information set, ski/lift/rest split, GPS-quality pill, share card, Watch-first recording (WP-13), per-run slope stats | Friends on map, trips, 3D/AR, community conditions |
| Skiline | Ski-pass based vertical tracking with Top-100 rankings, photo points, speed checks | Season bar chart per day, 'skyline' altitude-over-time chart (v1.1) | Pass integration; rankings become our opt-in social (v1.5) |
