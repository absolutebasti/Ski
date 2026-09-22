# Competitor notes — Skiline (Skidata), App Store screenshots 2026-09-22

Source: 3 App Store screenshots (IMG_1908–1910). Skiline tracks lift rides via the **ski pass** (RFID gate
data), not GPS, and is strong on gamification: Top-100 rankings per resort and season, photo points,
speed checks. Slogan: "Sammle Höhenmeter — gib deinen Skipass ein & erhalte deine persönliche SKILINE!"

## Feature inventory

| Area | What Skiline offers | Notes for us |
|---|---|---|
| Today | Altitude-over-time "skyline" line chart (lift rides as dots), three numbers: Vertical meters 890 m, Downhill dist. 10,3 km, Lift rides / dist. 12 / 5.8 km. Timeline list of lifts with times (Sedrun Station 08:25 → Summit Skyline Station 09:03 → …), plus events (Nassfeld Riesenslalom photo/speed event). Tabs: Today · Feed · Skiing days · All time. | The "skyline" altitude-vs-time chart with lift dots is a charming, very readable day visual. Cheap for us from GPS. |
| Skiing days / season | Season bar chart (vertical meters per day, highlighted days), trip grouping ("Journey to Arosa 26–28 December"), per-day rows: resort · 1,878 vm · 12 km · 8 lifts, sub-events: Photo Point, Speed check 48 km/h, Top-100 3rd place 11,624 m. | Season bar chart per day → our "Season" screen. |
| Top-100 | "Top 100 – Vertical meters in Andermatt Sedrun Disentis 2022/2023": ranked list with avatar, username, country flag, date, value and delta to leader; podium rows tinted gold / silver / bronze; own row highlighted pink. Global comparisons, per resort, per season. | This is the model for the founder's opt-in social idea (see below). |
| Profile / passes | Account per person ("Paul ▾"), wallet icon for ski passes, avatar. | We do not need pass entry; GPS gives us the data without a partner integration. |

## Visual language

- **Dark navy UI** (#1F2733-ish) with white text, **hot pink/magenta accent** (#E6007E) for highlights, own row, CTA (+) button; light cards (#EEF1F6) for lists.
- Marketing: full-bleed magenta gradient over mountain photo, white bold headline + lighter subline.
- Tab bar: 5 items with a central pink "+" action.
- Rankings: rows as pills, medal tints, big right-aligned value, small grey delta below.

## Founder's social concept (2026-09-22, from chat)

Opt-in only ("nur wenn man Social aktiviert und Daten teilen möchte"):
1. **Leaderboards** per ski resort or per country: Top-1 (Top-N) skied kilometres, top speed, (vertical) — per day / season.
2. **Group rides up to 3 people**: who skied the most km, who has the best average speed, most runs, etc. — a small private comparison for a ski day with friends.

Implications: needs a backend identity (anonymous Supabase auth is enough), a `leaderboard_entries` table
(user, resort, day/season, metric values) and a `groups` table with invite codes; privacy toggle in settings;
speed leaderboards need plausibility filtering (GPS spikes) or they become a cheating contest.
Position: **v1.5**, after TestFlight v1 (local-first). Data model in v1 must already store per-day, per-resort
aggregates so they can be published later with one switch.
