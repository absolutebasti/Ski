# SlopeTrack — Handover (2026-09-30)

## What this is
The ski-day tracker rebuilt from the 2025 PWA as a Flutter app (iOS first, Android builds, native Apple Watch companion). One tap records the whole day; runs, lifts and stops are detected automatically; tracking keeps running with the phone locked. Brand: **SlopeTrack**, bundle id `de.torchtechnology.slopetrack`, Team 5GDU97KSQU.

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
Onboarding (3 steps, mascot hero + cards, two-step Always flow) · Heute idle/live · Tagesbilanz (count-up, PB chips, notification opt-in) · Tage list + Tag detail (map, altitude profile, stats grid, run list, share/delete) · altitude profile, share card PNG, GPX 1.1, diagnostics bundle · Settings sheet + hidden Diagnose page · Apple Watch SwiftUI app sources + WatchConnectivity bridge + heart-rate source (target is added with `python3 app/ios/SlopeTrackWatch/tools/add_watch_target.py` once the watchOS SDK is installed; see docs/WATCH.md) · router/main wiring, thumbnail + weather written at End · review fixes (hold-button dispose, autoDispose day detail, resting-state permission cards) · debug launch switches for the simulator (`--dart-define=SLOPETRACK_SKIP_ONBOARDING=1`, `SLOPETRACK_DEMO=1`, `SLOPETRACK_TAB=tage`; also `SLOPETRACK_ROUTE`, `SLOPETRACK_APPEARANCE`, `SLOPETRACK_LOCALE`, see `app/lib/app/demo.dart`). 150 tests, analyzer clean, `main` = ce6782b.

## Also done since 14:00 (this branch)
Onboarding v2 (4 interactive pages: self-drawing route + vertical slider, home resort + season goal, Sign in with Apple + invite code, permissions) · snow-leopard mascot "Leo" as transparent cut-outs (`tools/assets/cutout_leopard.py`, poses in `app/assets/mascot/`) · design v2 on every remaining screen (Tag detail with collapsing map hero, Tagesbilanz with route reveal, live view in glare theme, settings sheet, share card in three formats, altitude profile, map sheet) · Konto sheet (`features/account`) · Rangliste tab (`features/social`: Saison/Monat/Woche leaderboard, Tagesduell with codes, Wochen-Challenge; fake API for tests) · appearance setting · Supabase migration 0002 (join_group RPC, membership helper, month/week leaderboard keys) applied · screenshot tooling `tools/shots.sh` (writes `demo.json` into the app container, no rebuild per screen; screens in `.context/shots/`). 258 tests, analyzer clean.

**Name:** SlopeTrack (founder's decision 2026-09-24; residual trademark risk documented in `docs/NAMING.md`). Renamed in code on 2026-09-24.

## Also done 2026-09-24 → 2026-09-27
Rename to SlopeTrack · gap audit (`docs/GAPS.md`) with most code items closed · Supabase 0003/0004 (weekly challenges via pg_cron, profile read policy, leaderboard participant count, `country_code` on profiles/days, server points, `country_board` RPC) · Edge Function `delete-account` · **Onboarding v3** (3 pages: hook → Team = country you ride for → sign-in + permissions; season goal no longer asked) · **Gamification** (`docs/GAMIFICATION.md`, `features/achievements`): points, 14 levels by km, streak, 48 medals; level card on Rangliste, medal banner on Tagesbilanz, streak chip on the season card, Medaillen sheet · **Country teams** in the Rangliste tab (scope Mein Land / Gebiet / Alle, metric Punkte, Länder card) · **Mascot v4**: faceless rider in black with gold seams and a mirrored gold visor (founder's pick: the 'point' image; pose set via FLUX Kontext, `tools/assets/generate_pointer.py`; the leopard is deleted). 334 tests, analyzer clean; screenshots in `.context/shots/` incl. `medals.png`.

## Also done 2026-09-28
Audit → `docs/BACKLOG.md`; three agent waves + lead work: RPC security fix (leaderboards saw only own days), integrity + moderation schema, friends, rider profiles, report/block, Rangliste core (friends scope, own rank, tappable rows), challenges module, share cards, invite links (URL scheme + Universal Links via GitHub Pages), OpenSkiMap resort import (4.929 areas), release package (privacy manifest, bilingual permission texts, Support/Impressum rows, hosted legal pages at https://absolutebasti.github.io/Ski/), onboarding opt-in, recording guards (03:00 rollover, 16 h cap, access loss, low power), sync hardening (backoff, 401 refresh, per-user cursor, paged pull, track restore), live duel (0009), profile page with avatar and team change. 861 tests green. Store screenshots DE/EN in `design/store`.

## Also done 2026-09-29
TestFlight blockers (TF-PLIST): photo/camera/microphone purpose strings for the image_picker static scan (ITMS-90683), English base values in Info.plist with DE/EN `InfoPlist.strings`, privacy manifest lists Photos or Videos, nutrition table + privacy policy mention the optional profile photo, Watch/heart-rate wording qualified as planned, `tools/testflight.sh` hardened (no stale archive, build failure aborts, CFBundleVersion assertion, empty-auth fix for bash 3.2).

## Also done 2026-09-30 (backlog v2 wave 2a + founder feedback)
Wave 2a on Opus (Fable's monthly limit stopped two runs; partial work was continued, not restarted): **Rangliste without login** (public top 10 via anon RPC `public_board_teaser`, locked duel/challenge previews, sign-in strip; 0016) · **duel invites in-app** (`duel_invites`, invite/respond/my_invites RPCs, `create_duel` RPC in the client, block check on accept; 0017) · **Konto/Einstellungen 2** (blocked users page fed by `blocked_riders()`, signed-out profile page with benefits + Apple button + 'Ohne Konto weiter', season goal row, units row removed, AccountSheet retired) · **sync 2** (honest account deletion `Future<bool>`, profile repair on start/auth/tick, `SyncState.throttled`, keyset paging, drift v3 `days.track_path`) · **backend limits** (0015: track_path-only updates free, live_days window ± 1 day + 20 s throttle, `join_group` on the group's tz, CI workflow for SQL + Deno tests) · **resorts deduplicated** (4.748 areas, 186 aliases, `resort_aliases` + canonicalising triggers, 0018; achievements count canonical ids) · **onboarding a11y** (P1 centred layout, reduce motion via `Tokens.reduced/motion`, 1.3× text-scale tests for four screens, WCAG contrast test — light tertiary token fixed) · **widget layer** (11 new glyphs, MetricStrip units, SurfaceCard alignment, semantics on sheets/tiles/bars/toasts/hold button, static pulses under reduced motion) · **founder feedback**: day cards and the Tagesbilanz hero show an **Apple Maps satellite image of the skied area** with the route (native `MKMapSnapshotter` via `ios/Runner/MapSnapshot.swift`, files `thumbs/<id>_map.png` / `_hero.png`, background render at End + retry once per session, attribution 'Karten: © Apple', path thumbnail stays as offline fallback) · **buttons polish pass** (inventory in `.context/plan/buttons-audit.md`) · review follow-ups (uploader respects the 20 s throttle, opt-in copy says name + avatar are public, privacy pages updated). SQL suite: 71 tests live across 12 files (`tools/supabase-test.sh --live`).

**Lift detection** is being rebuilt in the parallel Conductor session "bern-fb" (cable-ride signature: station-to-station evidence, full-resolution straightness and gradient rigidity, speedAcc-derived constancy; `TrackingConfig.engineVersion` 1 → 2; docs/TRACKING.md) and lands in its own commit on top of this one, followed by `test/tracking/lift_scenarios_test.dart` + `docs/ENGINE.md` from this session. Top speed, Ø ski speed, ski km and drop only ever count run segments — that was already true; the rebuild makes descending gondola rides and fast lifts robust.

## Next steps, in order
1. Founder: create the App Store Connect app record "SlopeTrack" (bundle id `de.torchtechnology.slopetrack`), then `tools/testflight.sh --upload` with the signed-in Xcode account (Apple Distribution 5GDU97KSQU present) or an ASC API key. Vault secrets for `report-notify` (docs/BACKEND.md §Reports). Impressum address in `docs/imprint.html`. Domain slopetrack.app → GitHub Pages, then `customDomainLive = true`.
2. Merge the lift-detection commit from session bern-fb (regenerates the share + day_thumb goldens), then lift_scenarios_test + docs/ENGINE.md.
3. Device QA (`docs/QA.md`): one locked-phone hour, one kill/resume, one mountain day → diagnostics bundle → engine fixture; check the satellite thumbnails and permission prompts on the device.
4. Remaining backlog v2 packages (`docs/BACKLOG-2.md`): SOC-NAME-FALLBACK, DEMO-SHOTS (signed-in demo fixtures + store screenshots with podium/duel), then SOC-SEASONS-COMPARE, NOTIF-LOCAL, LIVE-ACTIVITY, LATER-IMPORT-UNITS.
5. Founder decisions: automatic silent recompute of stored days on an engine version change (recommended), map provider for the day detail (tiles), Watch target once the watchOS SDK is installed, app icon.

## Decisions still open
- Name is SlopeTrack; register slopetrack.app and file the word mark (docs/NAMING.md).
- Stack note: Flutter phone app + native SwiftUI Watch app (as built). A fully native rewrite would drop Android; not recommended now.
- Social is in v1 now (founder's call); server-side count and challenge seeding still open.
- Map provider for the store release (Mapbox/MapTiler key); TestFlight uses OpenTopoMap + OpenSnowMap without a key.

## Known blockers / risks
- Two Conductor sessions worked on the same worktree on 2026-09-30 and nearly overwrote each other's engine edits; run one session per worktree, or agree file ownership first (this session: everything except `lib/tracking`, `core/constants.dart`, `test/tracking`, `docs/TRACKING.md`). A full tree copy from before the overlap is in `.context/snapshot-20260930-095843` (gitignored).
- Apple Maps snapshots carry the Apple wordmark; it is kept visible (never cropped) plus the 'Karten: © Apple' line — re-check against Apple's MapKit attribution terms before the store submission.
- First upload: create the App Store Connect app record for `de.torchtechnology.slopetrack`, then run `tools/testflight.sh --upload` with the signed-in Xcode account (Apple Distribution certificate for 5GDU97KSQU is present on this Mac; an ASC API key via `ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH` works too). The script deletes stale archives before the build and refuses to export when the archive's CFBundleVersion differs from `BUILD_NUMBER`.
- `de.lproj/en.lproj/InfoPlist.strings` are referenced from `Runner.xcodeproj` as a variant group (2026-09-29) → permission prompts follow the device language.
- Background continuity and battery can only be proven on a real device.
- Segmenter thresholds are tuned on synthetic days; first real fixtures will move them (raw points are stored, `Neu berechnen` re-runs the engine).
- The legacy Mapbox token in `legacy-pwa/reviews/initial-assessment.md` is public → rotate.
- The Fable model tier hit its spend limit twice on 2026-09-28; agents ran on Opus.
