# Dropline — Handover (2026-09-22, 16:00)

## What this is
The ski-day tracker rebuilt from the 2025 PWA as a Flutter app (iOS first, Android builds, native Apple Watch companion). One tap records the whole day; runs, lifts and stops are detected automatically; tracking keeps running with the phone locked. Brand: **Dropline**, bundle id `de.torchtechnology.dropline`, Team 5GDU97KSQU.

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

## Also done since 12:40 (merged in PR #2)
Onboarding (3 steps, mascot hero + cards, two-step Always flow) · Heute idle/live · Tagesbilanz (count-up, PB chips, notification opt-in) · Tage list + Tag detail (map, altitude profile, stats grid, run list, share/delete) · altitude profile, share card PNG, GPX 1.1, diagnostics bundle · Settings sheet + hidden Diagnose page · Apple Watch SwiftUI app sources + WatchConnectivity bridge + heart-rate source (target is added with `python3 app/ios/DroplineWatch/tools/add_watch_target.py` once the watchOS SDK is installed; see docs/WATCH.md) · router/main wiring, thumbnail + weather written at End · review fixes (hold-button dispose, autoDispose day detail, resting-state permission cards) · debug launch switches for the simulator (`--dart-define=DROPLINE_SKIP_ONBOARDING=1`, `DROPLINE_DEMO=1`, `DROPLINE_TAB=tage`). 150 tests, analyzer clean, `main` = ce6782b.

## Also done since 14:00 (this branch)
Onboarding v2 (4 interactive pages: self-drawing route + vertical slider, home resort + season goal, Sign in with Apple + invite code, permissions) · snow-leopard mascot "Leo" as transparent cut-outs (`tools/assets/cutout_leopard.py`, poses in `app/assets/mascot/`) · design v2 on every remaining screen (Tag detail with collapsing map hero, Tagesbilanz with route reveal, live view in glare theme, settings sheet, share card in three formats, altitude profile, map sheet) · Konto sheet (`features/account`) · Rangliste tab (`features/social`: Saison/Monat/Woche leaderboard, Tagesduell with codes, Wochen-Challenge; fake API for tests) · appearance setting · Supabase migration 0002 (join_group RPC, membership helper, month/week leaderboard keys) applied · screenshot tooling `tools/shots.sh` (writes `demo.json` into the app container, no rebuild per screen; screens in `.context/shots/`). 258 tests, analyzer clean.

**Name warning:** the trademark screen in `docs/NAMING.md` shows "Dropline" is held by Oberalp/Salewa (EU, cl. 18/25) and Bell Sports/Giro (cl. 9, ski goggles). Rename before the first upload is recommended; pre-screened alternatives are listed there.

## Next steps, in order
1. Founder: Xcode account for Team 5GDU97KSQU **or** App Store Connect API key; create the App Store Connect record "Dropline"; confirm the name. Then `tools/testflight.sh --upload`.
2. Device QA (`docs/QA.md`): one locked-phone hour, one kill/resume, one mountain day → diagnostics bundle → engine fixture.
3. TestFlight build 2: Watch app, Live Activity, `Gebiet` info card.
4. Backend open items (`docs/BACKEND.md`): server-side participant count for `MyRank.total`, Edge Function so `deleteAccount` also removes the `auth.users` row, seed weekly challenges (table `challenges` is empty), rate limits.
5. Founder decisions: name (see `docs/NAMING.md`), map provider, Watch target once the watchOS SDK is installed.

## Decisions still open
- Name "Dropline" is not free (Oberalp cl. 18/25, Bell Sports cl. 9) — decide before the first upload; bundle id becomes permanent then.
- Stack note: Flutter phone app + native SwiftUI Watch app (as built). A fully native rewrite would drop Android; not recommended now.
- Social is in v1 now (founder's call); server-side count and challenge seeding still open.
- Map provider for the store release (Mapbox/MapTiler key); TestFlight uses OpenTopoMap + OpenSnowMap without a key.

## Known blockers / risks
- No Apple account on this Mac for the team → export/upload blocked (archive itself signs fine).
- Background continuity and battery can only be proven on a real device.
- Segmenter thresholds are tuned on synthetic days; first real fixtures will move them (raw points are stored, `Neu berechnen` re-runs the engine).
- The legacy Mapbox token in `legacy-pwa/reviews/initial-assessment.md` is public → rotate.
- The Fable model tier hit its spend limit twice today; agents run on Opus.
