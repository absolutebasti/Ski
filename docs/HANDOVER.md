# Schwung — Handover (2026-09-22, 12:40)

## What this is
The ski-day tracker rebuilt from the 2025 PWA as a Flutter app (iOS first, Android builds, native Apple Watch companion). One tap records the whole day; runs, lifts and stops are detected automatically; tracking keeps running with the phone locked. Brand: **Schwung**, bundle id `de.torchtechnology.schwung`, Team 5GDU97KSQU.

Read in this order: `docs/PLAN.md` (§0 amendments first), `docs/ANALYSIS.md`, `app/lib/CONTRACTS.md`, `docs/QA.md`, `docs/APP-STORE.md`.

## Built, tested, committed
| Layer | Where | Tests |
|---|---|---|
| Design system, widgets, 2-tab shell, settings, locale DE/EN | `app/lib/app/**`, `app/lib/core/settings.dart` | smoke |
| Tracking engine: gate → Doppler speed → barometer fusion → run/lift/stop segmenter → day stats; offline replay == live | `app/lib/tracking/**` | 14 (synthetic days) |
| Data layer (drift/SQLite), 52 Alpine resorts | `app/lib/data/db/**`, `app/lib/data/resorts/**`, `app/assets/data/resorts.json` | 4 |
| Platform: geolocator background config, barometer, permissions (two-step Always), notifications, Swift relaunch watchdog, Info.plist/PrivacyInfo/Android manifest | `app/lib/platform/**`, `app/ios/Runner/**` | 1 |
| Recording controller: start/end, batch writes every 10 pts / 5 s, guards (idle, vehicle, 4 h, battery), kill → resume, recovery card logic | `app/lib/features/recording/**` | 5 |
| Map: track map, live sheet, tile cache, thumbnails | `app/lib/features/map/**` | 19 |
| Weather line (Open-Meteo) | `app/lib/data/weather/**`, `app/lib/features/weather/**` | 3 |
| Assets: logo + launcher icons + splash, mascot "Toni" clips/stills, Inter fonts | `design/**`, `app/assets/**` | — |
| Release tooling: `tools/testflight.sh` (archive, API-key export/upload), `app/ios/ExportOptions.plist` | | archive verified |

`cd app && flutter analyze && flutter test` → 0 issues, all green at the last lead commit. The app runs on the iPhone 17 Pro simulator (placeholder screens until WP-12 wiring).

## In progress (agents, Opus) — not yet committed by the lead
WP-10 altitude profile / share card / GPX / diagnostics, WP-06 onboarding, WP-08 Tage + Tag detail (done, awaiting review), WP-07 Heute + Tagesbilanz + Einstellungen, WP-13 Apple Watch companion (running). A review agent then checks analyzer, tests and contracts. The lead (WP-12) wires the real screens into `app/lib/app/router.dart`, runs the app, commits, merges.

## Next steps, in order
1. WP-12 integration + simulator run-through + screenshots.
2. Founder: Xcode account for Team 5GDU97KSQU **or** App Store Connect API key; create the App Store Connect record "Schwung"; confirm the name. Then `tools/testflight.sh --upload`.
3. Device QA (`docs/QA.md`): one locked-phone hour, one kill/resume, one mountain day → diagnostics bundle → engine fixture.
4. TestFlight build 2: Watch app, Live Activity, `Gebiet` info card.
5. Backend (Supabase, see `docs/BACKEND.md`): Sign in with Apple, cloud backup of days, opt-in leaderboards, group days ≤ 3, weekly challenges.

## Decisions still open
- Name "Schwung" (bundle id becomes permanent with the first upload).
- Stack note: Flutter phone app + native SwiftUI Watch app (as built). A fully native rewrite would drop Android; not recommended now.
- Social in v1 (delays TestFlight) vs. v1.5 (recommended).
- Map provider for the store release (Mapbox/MapTiler key); TestFlight uses OpenTopoMap + OpenSnowMap without a key.

## Known blockers / risks
- No Apple account on this Mac for the team → export/upload blocked (archive itself signs fine).
- Background continuity and battery can only be proven on a real device.
- Segmenter thresholds are tuned on synthetic days; first real fixtures will move them (raw points are stored, `Neu berechnen` re-runs the engine).
- The legacy Mapbox token in `legacy-pwa/reviews/initial-assessment.md` is public → rotate.
- The Fable model tier hit its spend limit twice today; agents run on Opus.
