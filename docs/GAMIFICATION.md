# Gamification — points, levels, streaks, medals (decided 2026-09-27)

Founder brief: streak of consecutive ski days, kilometres, top speed, average speed; medals; levels by kilometres; points. Everything is computed on the device from finished days (`DaySummary`), so it works offline and signed-out; points travel with `days` sync so leaderboards can rank by them later. Contract: `app/lib/features/achievements/achievement_models.dart`.

## 1. Points (lifetime, integer)
Per finished, non-suspicious day:
- vertical: `drop_m / 10` (1.849 hm → 185)
- distance: `ski_distance_m / 100` (14,1 km → 141)
- runs: `run_count × 5`
- day bonus: `+50`
Rounded per day, summed. No streak bonus (dropped 2026-09-27): the device formula is identical to the server's generated column `days.points` (migration 0004), so the points shown on the device equal the leaderboard points. Streaks are rewarded through the streak medals (§4) only. Transparent enough to print in the Medaillen sheet header: "Punkte = hm ÷ 10 + km × 10 + Abfahrten × 5 + 50 pro Tag".

## 2. Level (by lifetime ski distance)
| Level | km | Title DE / EN |
|---|---|---|
| 1 | 0 | Rookie / Rookie |
| 2 | 25 | Einsteiger / Starter |
| 3 | 50 | Pistenfahrer / Piste rider |
| 4 | 100 | Carver / Carver |
| 5 | 200 | Vielfahrer / Regular |
| 6 | 350 | Allrounder / All-rounder |
| 7 | 500 | Ausdauerfahrer / Endurance |
| 8 | 750 | Höhenjäger / Vert hunter |
| 9 | 1.000 | Tausender / Thousand |
| 10 | 1.500 | Veteran / Veteran |
| 11 | 2.000 | Elite / Elite |
| 12 | 3.000 | Pro / Pro |
| 13 | 5.000 | Legende / Legend |
| 14 | 10.000 | Black / Black |
`progress` = position inside the current band (0…1).

## 3. Streak
Consecutive calendar days (device time zone) with at least one finished day. `current` counts back from the most recent day; a gap of one day breaks it. `longest` over the whole history.

## 4. Medals (tiers bronze · silver · gold · black)
| Metric | bronze | silver | gold | black |
|---|---|---|---|---|
| days (lifetime) | 1 | 10 | 25 | 100 |
| streak (days) | 3 | 5 | 7 | 14 |
| vertical (lifetime hm) | 10.000 | 50.000 | 100.000 | 500.000 |
| distance (lifetime km) | 100 | 500 | 1.000 | 5.000 |
| top speed (km/h, single day, not suspicious) | 60 | 80 | 100 | 120 |
| avg ski speed (km/h, lifetime) | 25 | 35 | 45 | 55 |
| runs (lifetime) | 50 | 250 | 1.000 | 5.000 |
| day vertical (single day hm) | 2.000 | 3.000 | 4.000 | 6.000 |
| day runs (single day) | 10 | 20 | 30 | 40 |
| countries (distinct) | 2 | 3 | 4 | 5 |
| resorts (distinct) | 3 | 10 | 25 | 50 |
| points (lifetime) | 1.000 | 5.000 | 20.000 | 100.000 |
Medal ids: `<metric>-<tier>` (e.g. `streak-gold`). Titles are short, adult ("Sieben am Stück", not "Super!") and never bare numbers — the tile shows the threshold on its own row, the Tagesbilanz banner captions a new medal with its hint ("3 Skitage in Folge"). Names (de / en):

| Metric | bronze | silver | gold | black |
|---|---|---|---|---|
| days | Erster Tag / First day | Zehn Tage / Ten days | Fünfundzwanzig / Twenty-five | Hundert Tage / Hundred days |
| streak | Drei am Stück / Three straight | Fünf am Stück / Five straight | Sieben am Stück / Seven straight | Zwei Wochen / Two weeks |
| vertical | Zehntausender / Ten thousand | Fünfzigtausend / Fifty thousand | Hunderttausend / Hundred thousand | Halbe Million / Half a million |
| distance | Hundert / Hundred | Fünfhundert / Five hundred | Tausend / Thousand | Fünftausend / Five thousand |
| top speed | Sechziger / Sixty | Achtziger / Eighty | Hunderter / Hundred | Hundertzwanzig / One-twenty |
| avg ski speed | Gleichmäßig / Steady | Zügig / Brisk | Schnell / Fast | Rennlinie / Race line |
| runs | Fünfzig Abfahrten / Fifty runs | Zweihundertfünfzig / Two-fifty | Tausend Abfahrten / Thousand runs | Fünftausend / Five thousand |
| day vertical | Zweitausender / Two-thousander | Dreitausender / Three-thousander | Viertausender / Four-thousander | Sechstausender / Six-thousander |
| day runs | Zehn am Tag / Ten a day | Zwanzig am Tag / Twenty a day | Dreißig am Tag / Thirty a day | Vierzig am Tag / Forty a day |
| countries | Grenzgänger / Border crosser | Drei Länder / Three countries | Vier Länder / Four countries | Fünf Länder / Five countries |
| resorts | Drei Gebiete / Three resorts | Zehn Gebiete / Ten resorts | Fünfundzwanzig / Twenty-five | Fünfzig Gebiete / Fifty resorts |
| points | Tausend Punkte / Thousand points | Fünftausend Punkte / Five thousand points | Zwanzigtausend Punkte / Twenty thousand points | Hunderttausend Punkte / Hundred thousand points |
 A medal is earned by the first day that crosses the threshold; `newMedalIds` lists the medals earned by the most recent day so the Tagesbilanz can show them once.

## 5. Where it shows
- Rangliste tab, top: level ring + points + streak chip + medal count → tap opens the Medaillen sheet (grid by metric, locked medals dimmed with progress).
- Tagesbilanz: "Neue Medaille" banner(s) under the record card.
- Heute season card: streak chip when ≥ 2.
- Team = country: onboarding v3 asks for the country you ride for; leaderboards can be scoped to the country and a country-vs-country board sums points (migration 0004).
