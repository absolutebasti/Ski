# SlopeTrack — App Store Connect (fill-in sheet, 2026-09-27)

**Bundle ID** `de.torchtechnology.slopetrack` · **Team** 5GDU97KSQU · **SKU** slopetrack-ios · **Primary language** German (de-DE), localisation en-US · **Category** Health & Fitness, secondary Sports · **Devices** iPhone only, portrait · **Price** free, no IAP · **Availability** all countries **except Switzerland** (Suva holds the CH mark "SLOPE TRACK", founder decision 2026-10-09; can be added later in Pricing and Availability) · **Copyright** 2026 TORCHTECHNOLOGY LTD.

## URLs (live via GitHub Pages from `docs/`)
| Field | URL |
|---|---|
| Privacy Policy | https://absolutebasti.github.io/Ski/privacy.html |
| Support | https://absolutebasti.github.io/Ski/support.html |
| Marketing | https://absolutebasti.github.io/Ski/ |
| Terms (EULA: Apple standard) | https://absolutebasti.github.io/Ski/terms.html |
| Imprint (DE law) | https://absolutebasti.github.io/Ski/imprint.html — **founder must fill in the address before submission** |

## Names
Limits checked 2026-10-09: name and subtitle ≤ 30 characters, keywords ≤ 100 and without words already in name or subtitle (Apple indexes those anyway).

| Field | DE | EN |
|---|---|---|
| Name (30) | SlopeTrack – Ski-Tracker | SlopeTrack – Ski Tracker |
| Subtitle (30) | Duelle, Rangliste, Höhenmeter | Duels, leaderboards, vertical |
| Promotional text (170) | Ein Tipp startet den Skitag. Abfahrten, Höhenmeter und Tempo automatisch – dazu Ranglisten pro Land und Skigebiet, Duelle mit Freunden, Level und Medaillen. | One tap starts the ski day. Runs, vertical and speed automatically – plus leaderboards per country and resort, duels with friends, levels and medals. |
| Keywords (100) | skifahren,abfahrten,piste,snowboard,skitag,gps,skigebiet,speed,freunde,wettkampf,lift,winter,alpen | skiing,runs,slope,snowboard,ski day,gps,resort,speed,friends,competition,lift,winter,alps |

## Description (DE)
SlopeTrack zeichnet deinen ganzen Skitag mit einem Tipp auf. iPhone in die Jacke, Sperre an – die Aufnahme läuft weiter. Am Abend siehst du, was zählt: Abfahrten, Höhenmeter, Top-Speed, deine beste Abfahrt und wie viel Zeit du auf der Piste, im Lift und in der Pause warst.

Und dann geht es um mehr als Zahlen:
• Rangliste – pro Land, pro Skigebiet oder alle: Saison, Monat, Woche
• Tagesduell – bis zu drei Freunde, ein Code, ein Tag, live gegeneinander
• Wochen-Challenge – jede Woche ein neues Ziel für alle
• Level und Medaillen – Punkte für Höhenmeter, Kilometer und Abfahrten, Streak für Skitage am Stück
• Dein Land ist dein Team – Länder-Wertung jede Saison

Die Basis bleibt ehrlich:
• Ein Start, ein Ende – Lift, Pause und Abfahrt erkennt SlopeTrack selbst
• Höhenmeter über den Luftdrucksensor, Tempo direkt vom GPS
• Nichts geht verloren – jeder Punkt landet sofort auf dem Gerät
• Tagesbilanz zum Teilen, GPX-Export für andere Apps
• Ohne Konto funktioniert alles lokal. Mit Apple-Login: Backup in der EU und Ranglisten – nur wenn du sie einschaltest.

Hinweis: SlopeTrack nutzt den Standort im Hintergrund, solange ein Skitag aufgezeichnet wird. Das kann den Akku stärker beanspruchen.

## Description (EN)
SlopeTrack records your whole ski day with one tap. Phone in the jacket, screen locked – recording keeps going. In the evening you see what matters: runs, vertical, top speed, your best run and how long you spent skiing, riding lifts and resting.

Then it is about more than numbers:
• Leaderboards – per country, per resort or everyone: season, month, week
• Day duel – up to three friends, one code, one day, live against each other
• Weekly challenge – a new goal for everyone every week
• Levels and medals – points for vertical, kilometres and runs, streaks for consecutive ski days
• Your country is your team – a country ranking every season

The basics stay honest:
• One start, one end – lifts, breaks and runs are detected automatically
• Vertical from the barometer, speed straight from GPS
• Nothing is lost – every point is saved to the device immediately
• Day summary to share, GPX export for other apps
• Everything works locally without an account. With Apple sign-in: backup in the EU and leaderboards – only if you switch them on.

Note: SlopeTrack uses background location while a ski day is being recorded, which increases battery use.

## What's New (1.0)
DE: Erste Version – Aufnahme mit einem Tipp, Ranglisten, Duelle, Challenges, Level und Medaillen.
EN: First release – one-tap recording, leaderboards, duels, challenges, levels and medals.

## App Privacy (nutrition label) — answers
| Data type | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| Precise Location | yes (while recording) | **yes when signed in** (days synced to the account), no otherwise | no | App Functionality |
| Fitness (workout figures; heart rate only once the Watch app ships — planned, not in 1.0) | yes | yes when signed in | no | App Functionality |
| Photos or Videos (profile photo, optional, picked from the library) | yes (signed in, only if the user sets one) | yes | no | App Functionality |
| User ID (Apple sign-in id) | yes (signed in) | yes | no | App Functionality |
| Name (from Apple, optional) | yes (signed in) | yes | no | App Functionality |
| Email (Apple relay, optional) | yes (signed in) | yes | no | App Functionality |
| User Content (display name, country, home resort, profile photo) | yes (signed in) | yes | no | App Functionality |
| Other: none. No advertising, no analytics SDKs, no ATT prompt. Third parties: Supabase (processor, EU), Apple Maps (satellite image of the day: map area + IP), Open-Meteo (weather, resort coordinates + IP). |

## Age rating questionnaire
None of the mature categories. **Unrestricted web access: No. Gambling/contests: No (no prizes). User-generated content: display names in leaderboards → answer the "User Generated Content" questions truthfully:** users can report via support e-mail and the in-app "Melden" action (in the build: SOC-MODERATION — Melden/Blockieren on every rider profile), names are filtered client-side. Expected rating 4+.

## Sign in with Apple / account checklist (Apple 5.1.1 v, 4.8)
- Sign in with Apple is the only third-party login → compliant with 4.8.
- Account deletion in-app: Einstellungen › Konto › Konto löschen (Edge Function removes auth user + data). ✔
- App is fully usable without an account. ✔

## Review notes (paste into "Notes for Reviewer")
SlopeTrack works fully without an account; Sign in with Apple is optional and only needed for backup and leaderboards. No demo credentials are required. The core feature needs GPS while skiing, which cannot be reproduced indoors; to evaluate:
1. Complete the 3-page onboarding (choose a country; Location "Always" is requested so recording survives a relaunch; "While Using" also works when the day is started in the foreground).
2. Tap "Tag starten". Walk outside for a few minutes with the phone locked; the blue location indicator shows recording is active.
3. Hold "Tag beenden" for one second. Very short days are discarded on purpose; a normal ski day produces the summary with runs and vertical.
4. Rangliste tab: level, points and medals are computed on-device from recorded days; leaderboards need an account and the opt-in "In Ranglisten erscheinen".
5. Settings → tap the version 7 times to open "Diagnose" (GPS points, sensor status).
Background location is used only while a ski day is being recorded. ITSAppUsesNonExemptEncryption = false (HTTPS only). Account deletion: Settings › Account › Delete account.

User-generated content: limited to display names (max. 24 characters, filtered on device against a DE/EN word list before they are saved) and avatars. Every rider profile reached from a leaderboard, duel or friends list offers "Melden" (Report) with a reason and "Blockieren" (Block). Reports are stored server-side with reporter, target and reason and are reviewed promptly by the operator (an e-mail notification per report is planned, backlog BE-14); the support address is in Settings › Support. Blocking hides the blocked rider from the user's leaderboards, duel boards and friends list immediately and ends an existing friendship; the user can undo it from the same profile. No messaging, comments or free-text posts exist in the app.


## Screenshots (6.9" 1320×2868 required; 6.5" 1284×2778 optional)
Captured on the iPhone 17 Pro Max simulator with demo data via `OUT=.context/shots/store UDID=<pro-max> tools/shots.sh build`, captioned by `tools/store_shots.py` → `.context/shots/store/framed/*.png`. Order: 1 Heute (streak, goal), 2 Rangliste (level card), 3 Medaillen, 4 Tag-Detail (map), 5 Tagesbilanz, 6 Tage, 7 Onboarding (Team). Captions DE/EN in the script.

## TestFlight "What to test" (internal group)
- Ganzer Skitag mit dem iPhone in der Jacke: läuft die Aufnahme bis zum Abend durch?
- Stimmen Abfahrten, Höhenmeter und Top-Speed ungefähr mit Skipass/anderen Apps überein?
- Apple-Login, Rangliste einschalten, Duell mit einem Freund per Code.
- Akku pro Stunde (Einstellungen › Diagnose zeigt Punkte und Neustarts).
- Am Abend "Diagnosepaket teilen" an hello@torchtechnology.de.

## Founder to-do before submission
1. Create the App Store Connect app record "SlopeTrack – Ski-Tracker" with bundle id `de.torchtechnology.slopetrack`; paste this sheet.
   In "Pricing and Availability" untick **Switzerland** before the first release.
2. `tools/testflight.sh --upload` with the signed-in Xcode account of team 5GDU97KSQU (Apple Distribution certificate is present on this Mac) **or** an App Store Connect API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`). The script refuses stale archives (CFBundleVersion must equal `BUILD_NUMBER`).
3. ~~Fill in `docs/imprint.html`~~ done 2026-10-09 (TORCHTECHNOLOGY LTD).
4. Optional: custom domain for the pages (e.g. slopetrack.app → GitHub Pages CNAME).
5. Apple provider secret in Supabase expires every 6 months — set a calendar reminder.
