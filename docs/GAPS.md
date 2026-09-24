# Gaps — what is still missing (audit 2026-09-24)

Evidence-based audit of the merged state (main = PR #4, 258 tests green). Owner: **founder** = needs the founder's account, decision or money · **code** = Claude can do it now · **backend** = Supabase change · **device-qa** = needs a real iPhone · **legal** · **design**. Effort S/M/L.

## 1. Before TestFlight build 1

| # | Gap | Why it blocks | Owner | Effort | Ref |
|---|---|---|---|---|---|
| 1 | No Apple access on this Mac: no Apple ID for team 5GDU97KSQU in Xcode and no App Store Connect API key; no App Store Connect app record | Archive signs, but export/upload is impossible | founder | S | tools/testflight.sh, docs/APP-STORE.md |
| 2 | Name not cleared: "Dropline" is held by Oberalp/Salewa (EUTM cl. 18/25) and Bell Sports/Giro (cl. 9, ski goggles); bundle id becomes permanent with the first upload | Rename after upload means a new app record | founder + legal | S | docs/NAMING.md |
| 3 | Nothing proven on a real device: background continuity with the screen locked, kill → resume, watchdog relaunch, barometer fusion, battery per hour, car auto-end | The whole value proposition is untested outside the simulator (`Location is off` even in the simulator screenshots) | device-qa | M | docs/QA.md (14 checks) |
| 4 | Sign in with Apple never exercised end-to-end: 0 users, 0 profiles, 0 days in the Supabase project; the Apple client secret Supabase needs is a JWT that expires after ≤ 6 months and must be renewed | First real sign-in may fail; sync is untested against the live project | founder + device-qa | S | supabase project svzmmpzevmpodcelzvit › Auth › Apple |
| 5 | Wochen-Challenge card is empty: `challenges` table has 0 rows and nothing creates weekly challenges | The third competition feature shows nothing | backend | S | supabase/migrations, features/social/challenge_card.dart |
| 6 | Season goal from onboarding is stored but shown nowhere (only `settings.dart` and `onboarding_flow.dart` reference it) | The onboarding promise ("your goal") has no follow-through on Heute/Tage | code | S | features/today/season_card.dart |
| 7 | Simulator screenshots still show the location-denied card on Heute; the permission grant via `simctl privacy` does not reach the app | Demo/screenshot flow shows a warning card instead of the last day | code | S | tools/shots.sh |

## 2. Before App Store submission

| # | Gap | Why | Owner | Effort | Ref |
|---|---|---|---|---|---|
| 8 | Account deletion only deletes rows; the `auth.users` entry stays (`auth_service.dart` TODO). Apple 5.1.1(v) requires full deletion for apps with sign-in | Review rejection risk | backend | M | Edge Function with service role |
| 9 | Privacy policy is not hosted (URL `dropline.torchtechnology.de/privacy` planned), no support URL/email, no Impressum (mandatory in DE for an app with a provider) | App Store Connect requires privacy URL + support URL; DE law requires Impressum | founder + legal | S | docs/PRIVACY.md, docs/APP-STORE.md |
| 10 | `profiles public read` policy exposes display name and home resort of every user, including users who did not opt in to leaderboards | Privacy leak; GDPR minimisation | backend | S | supabase/migrations/0001 line 101 |
| 11 | No attribution / licences screen: OpenTopoMap + OpenSnowMap (OSM, ODbL/CC-BY-SA), Open-Meteo (CC-BY), Inter font (OFL) require visible credit; `showLicensePage` is not used | Licence breach; map providers may block tiles | code | S | features/settings |
| 12 | VoiceOver: custom glyph buttons have almost no `Semantics` labels (2 in the whole widget library) | Accessibility rejection risk, unusable with VoiceOver | code | M | app/widgets/* |
| 13 | Text scaling is only clamped on the live screen; other screens are unverified at 1.3× Dynamic Type | Overflows for users with larger text | code + design | M | features/** |
| 14 | Light appearance exists as a setting but no screen was ever checked in light mode | Setting can expose broken colours | design | M | tools/shots.sh with appearance=light |
| 15 | iPad: `TARGETED_DEVICE_FAMILY = "1,2"` while the store plan says iPhone only | Either iPad screenshots + layouts, or set to iPhone only | code | S | ios/Runner.xcodeproj |
| 16 | Resort database has 52 Alpine resorts; per-resort leaderboards and the home-resort picker depend on it (competitors list thousands) | Users outside the 52 get "Alle Gebiete" only | code + data | M | assets/data/resorts.json (OpenSkiMap import) |
| 17 | Store assets: no screenshots (6.9"/6.5"), no preview; DE/EN copy exists only as a draft | Cannot submit | design + founder | M | docs/APP-STORE.md |
| 18 | Legacy Mapbox token and old anon key are in the legacy PWA docs and git history | Must be rotated before the repo or app goes public | founder | S | legacy-pwa/reviews/initial-assessment.md |
| 19 | Leftover "Schwung"/"Toni" names in docs/PLAN.md, migration filename, Watch files (`SchwungWatchApp.swift`, `SchwungWatch.entitlements`), two widget comments | Cosmetic, but confusing for review and for the Watch target script | code | S | grep -ri schwung |
| 20 | `MyRank.total` is the fetched slice (limit 100), not a server-side participant count | "Platz 14 von 100" is wrong for big resorts | backend | S | features/social/social_models.dart |
| 21 | Material icons still used instead of custom glyphs (onboarding 10, account 7, settings 6, live 5 places); one `Icons.*` per remaining screen | Design v2 consistency | design | S | grep "Icons\." |

## 3. Later (v1.1+)

| # | Gap | Owner | Effort |
|---|---|---|---|
| 22 | Apple Watch: SwiftUI sources exist but the target is not in the Xcode project (watchOS SDK missing on this Mac), no complications, no standalone recording, untested | founder (SDK) + code | L |
| 23 | Invite code in onboarding (concept page 3) — joining works only in the Rangliste tab | code | S |
| 24 | Abuse: any signed-in user can insert fake days; only the `suspicious` thresholds (45 m/s, 15.000 hm, 80 runs) filter leaderboards; no rate limit | backend | M |
| 25 | Live Activity / lock-screen widget, HealthKit workout on the phone, Siri/Shortcuts | code | L |
| 26 | Lift/resort info one-liner (open lifts, snow depth) — no data source wired | code | M |
| 27 | Imperial units, English-first copy for non-DACH markets, more languages | code | M |
| 28 | Android: project builds but is untested and out of scope for TestFlight | code | L |
| 29 | Real-track regression fixtures (GPX from device days) for the engine; currently synthetic only | device-qa + code | M |
| 30 | Mascot pose set: 6 of 9 poses are head variants; full-body poses for celebrate/thumbs/point would carry the Tagesbilanz better | design | M |

## Founder decisions
1. Name: keep Dropline (risk) or switch (Dropcount / Vertdrop / Droprun / Pistelab; SlopeTrack rejected: CH cl. 9 mark, collides with "Slopes"). Recommendation: switch now.
2. Apple access: Xcode sign-in with the team Apple ID, or an App Store Connect API key for `tools/testflight.sh`.
3. Hosting for privacy policy + Impressum + support page (one static page under torchtechnology.de is enough).
4. Watch app in build 1 (delays by ~1–2 weeks and needs the watchOS SDK) or build 2. Recommendation: build 2.
5. Resort coverage: 52 hand-picked resorts or an OpenSkiMap import (thousands, less curated). Recommendation: import for the picker, curated list for leaderboards.
6. Agent budget: the monthly spend limit for parallel agents is exhausted; raise it at claude.ai/settings/usage or accept slower solo work.

## Device QA plan (first real day)
1. Fresh install on the founder's iPhone via TestFlight; run onboarding, grant Always + Motion.
2. Sign in with Apple; check a profile row appears in Supabase.
3. One hour locked in a jacket pocket walking/cycling; then Diagnose page: points every ~1 s, 0 restarts.
4. Swipe-kill mid-recording, relaunch after 5 min and after 40 min (silent resume vs recovery card).
5. Car ride: day auto-ends with the vehicle notification.
6. Battery: note %/h over 3 h locked.
7. First mountain day: compare runs/vertical against a lift ticket or Skiline; export the diagnostics bundle → engine fixture.
8. Tagesbilanz → Teilen → the share card looks right on Instagram/WhatsApp.
