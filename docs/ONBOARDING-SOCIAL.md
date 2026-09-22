# Onboarding + competition core (founder direction, 2026-09-22 afternoon)

Founder: "cooles, kurzes Onboarding, das die App sehr gut beschreibt; sehr catchy, sehr interaktiv; Social — Rennen gegeneinander, Leaderboard — ist fast interessanter als Auskunft über Gondeln; wir brauchen ein Maskottchen." Consequence: **competition moves from v1.5 into the core**, the onboarding sells it, and the mascot carries it.

## Product spine (what the app is now)
1. **Track** — one tap, whole day, locked phone, honest numbers (unchanged, already built).
2. **Compete** — the reason to open the app in the evening: Gebiets-Rangliste (per resort, season / month / week), **Tagesduell** (private race with friends for the day: km, hm, runs, top speed, Ø speed), **Wochen-Challenge** (one target per week), season goal with progress.
3. **Show** — Tagesbilanz + share card, personal bests, mascot reactions.
Resort info (lifts open, snow) stays a one-liner on Heute; no "Gebiet" tab.

## Onboarding (4 screens, < 60 s, all interactive)
| # | Screen | Interaction | Copy (DE) |
|---|---|---|---|
| 1 | **Hook** — mascot on graphite, a route draws itself, a 92 pt numeral counts up to 1.849 hm, three chips pop in (7 Abfahrten · 61 km/h · Platz 3 in Kitzbühel) | Drag the slider "Wie viele Höhenmeter schaffst du an einem Tag?" → the numeral follows the finger; haptic ticks | "Fahr. Zähl. Gewinn." · "Ein Knopf zeichnet deinen Skitag auf – Abfahrten, Höhenmeter, Top-Speed. Und du siehst sofort, wo du stehst." |
| 2 | **Dein Revier** — searchable resort list (52 Alpine resorts, nearest first if location allowed); picking one reveals a live Top-10 teaser card for that resort (real data if any, else "Sei der Erste in Kitzbühel") and the season goal stepper (default 20.000 hm) | Tap resort, drag goal stepper; mascot comments ("20.000 hm? Mutig. Gefällt mir.") | "Wo fährst du meistens?" |
| 3 | **Freunde fordern** — Sign in with Apple (needed for duels + rankings), display name pre-filled from Apple, "Dein Code: KITZ-4F2" with share button, optional "Code eingeben" | Sign in, share code (share sheet), or "Später" | "Rangliste und Duelle brauchen einen Namen. Kein Passwort, kein Spam." |
| 4 | **Startklar** — permissions explained by the mascot: Standort (Immer), Bewegung & Fitness; one button | System prompts; on grant the Start button pulses once on Heute | "Zwei Fragen vom iPhone, dann geht's los." |
Skip is possible on 2 and 3; 4 is required for tracking. Progress = 4 line-pager bars. Every screen: mascot in a fixed position, one headline, one sentence, one primary button.

## Rangliste tab (v1 scope, agents WP-16)
- Segmented Saison · Monat · Woche; resort selector (home resort default, "Alle Gebiete").
- Podium block (2nd / 1st / 3rd, avatars with champagne ring on #1), rows below, own row pinned in a glass strip ("Du · Platz 14 · 12.480 hm").
- Metric chips: Höhenmeter (default), Abfahrten, Ski-km, Top-Speed, Skitage. Top-Speed only counts days with `suspicious = false`.
- **Tagesduell** card on top when active: members with live numbers (60 s polling), leader champagne, "Duell teilen". Create → code + share; join → code field. Max 3 in v1 (server-side check later).
- **Wochen-Challenge** card: target, own progress bar, participants count, "Mitmachen".
- Empty/signed-out state: mascot + "Melde dich an und hol dir Platz 1 in Kitzbühel" + Sign in with Apple.

## Mascot
Flat sticker-style character, 3 colours (graphite, cream, champagne), goggles on the forehead. Candidates in `design/mascot/candidates/` (Steinbock, Murmel, Gams, Schneehase, Yeti, Eule). Used: onboarding (every screen), empty states, Tagesbilanz reaction line, share card corner, app icon variant, push copy. It never appears on the live screen.

## Name — process
- Brand = short coined or animal name, App Store title = **"Brand – Ski-Tracker & Duelle"** (30 chars) for discoverability, subtitle "Abfahrten, Höhenmeter, Rangliste" (founder's rule: not only a short name).
- Clearance before the App Store Connect record: App Store exact-name search (DE + US, done in chat), **DPMA + EUIPO + WIPO trademark search in classes 9, 41, 42** (TMview blocked scripted queries — do it in the browser: https://www.tmdn.org/tmview), domain check, social handles. Coined names clear more easily than dictionary words.
