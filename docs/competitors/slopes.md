# Competitor notes — Slopes (Breakpoint Studio), App Store screenshots 2026-09-22

Source: 10 App Store marketing screenshots supplied by the founder (IMG_1898–1907). Apple Design Award
Winner 2022. The founder rates this app very highly → it is our quality benchmark, especially for the
day summary, the Apple Watch experience and the share card.

## Feature inventory

| Area | What Slopes offers | Notes for us |
|---|---|---|
| Recording on interactive piste map | Mapbox map with pistes (colour-coded), lifts (named: "GONDOLA", "FOURRUNNER"), POIs (restaurants, patrol), live track as red dotted line, **GPS quality pill** (green bars), layers + **3D** toggle, big "Pausieren" pill, search "Wo ist …? Was ist geöffnet …?", quick actions Freunde / Statistiken / **Bergwacht** (red, emergency) / …, stats strip: 7 Abfahrten (aufgezeichnet) · 4.307 m Höhenmeter · 626 m Höhe · ♥ 60–61 (10 min). Friends' avatars live on the map. | GPS-quality indicator and an emergency/patrol button are cheap, high-trust details. |
| Friends nearby | List with "zuletzt vor 1 Min gesehen", paused state, "5 Freunde zeichnen heute hier auf", add friends. | Needs accounts → not v1. |
| Day overview ("Dein gesamter Tag") | Header: date, resort (auto), "Auf der Apple Watch verfolgt". Actions: Replay (primary), Vergleichen, AR, …. Stats row: 12 Abfahrten · 5.296 m Höhenmeter · 31,2 km Distanz · 5h 37 Gesamt. Highlight note (yellow quote bubble), photo strip, 2×2 cards: Top-Speed 68,9 km/h, höchste Abfahrt 933 m, Absolute Höhe 3.504 m, längste Abfahrt 5,5 km. **Time split** as three coloured circles: Ski 2h 3min (red), Lift 1h 19min (dark), Pause 2h 14min (grey "Zz"). | This is the screen to beat. Copy the information set, present it calmer. Time split ski/lift/rest is a must. |
| Detailed statistics | "Trends" vs 2024/25 · 2023/24 · 2022/23 with **season goals** (Tage Ziel 36, Höhenmeter Ziel 143.652 m, Abfahrten Ziel 339), cumulative line vs last season, "Besser +3". Categories: Top Speed, Liftzeit vs Abfahrten, Höhenmeter, Distanz, Insgesamte Abfahrten, Kalorien, Höhendaten, Herzfrequenz, Saisonüberblick, Allzeit-Gesamtwerte. | Season goals + "vs last season" is motivating and local-only → good v1.5 candidate. |
| Fitness | Ø HR bei Abfahrten 121 bpm, Max 176, 1.287 kcal; HR zones bar + 5-zone list with minutes. | Needs Watch/HealthKit. Phase 2 with the Watch app. |
| Apple Watch app | Black screen, one metric per line in colour: ↓ 4.245 m (green), → 18,4 km (blue), 🔥 89,8 km/h (orange), ♥ 145 bpm (red), ⏱ 2:45:09 (yellow); page dots; ski icon + clock. "Unsere Favoriten für Apple Watch" (Apple editorial). | Founder wants a Watch app "auf jeden Fall". Watch app = SwiftUI/WatchKit; standalone HKWorkoutSession gives GPS + HR + background on the wrist. |
| Replays | Map playback with play button, clock 10:40:35, Ø-Tempo 7,5 km/h, Gesamtzeit 8min 50s, Absolute Höhe 2.806 m, timeline scrubber with red (runs) / dark (lifts) segments, "Day Break" label, tabs Überblick / Analysieren / Vitalwerte; friends replayed too. | A 2D replay with a run/lift timeline is feasible in v1.5; 3D/AR is not. |
| 3D & AR | Mapbox 3D terrain; run sheet: "Angel's Rest" (blue difficulty), lift "Peak 7", Geöffnet, 257 m Höhenmeter, 17° max / 10° avg slope, Höhenprofil. | Per-run slope angle + profile are cheap and impressive. Piste-name matching needs piste geometry (OpenSkiMap data). |
| Trips & conditions | "Rockies Roadtrip 19.–26.02.2027": Mitfahrende, auto location sharing during trip, Reiseplan per resort, community condition tags histogram (Pulverschnee, kompakt, eisig, präpariert …), OpenSnow forecast. | Skip. |
| Share card | Stylised relief map with track (blue) + lifts (black), resort logo, date, 12 RUNS / 17,376 FT vertical / 19.4 MI distance, "Made with Slopes"; Save / Messages / IG Story / More. | Must-have for v1: a clean 9:16 share card. |

## Visual language

- **Light, calm, premium**: off-white surfaces, cards with 16–20 pt radius, generous whitespace; marketing alternates white and **dark navy (#1B2130-ish)** panels.
- **Type**: bold geometric sans for headlines (dark navy), SF for UI. Stat pattern = `number UNIT` (unit in small caps) over an icon + label line (`↓ Höhenmeter`, `→ Distanz`, `↻ aufgezeichnet`).
- **Colour semantics**: red = skiing/run, dark = lift, grey = rest; blue = primary action; green = GPS good / open; yellow = highlight note.
- **Map**: Mapbox outdoors style with piste colours and lift lines; track in red dotted (live) or blue (share card).
- **Watch**: pure black, big colourful numerals, one metric per row, swipe pages.
- **Feel**: playful but tidy; strong iconography; nothing is crowded even though there is a lot of data.

## What we take from Slopes

1. Day-summary information set and the ski/lift/rest time split.
2. Share card as a first-class output.
3. GPS-quality indicator during recording.
4. Watch-first recording: start on the wrist, phone stays in the pocket.
5. Season trends vs last season (later).
6. Per-run stats: vertical, length, max/avg slope, top speed, profile.

## What we deliberately do not copy

Friends on map, community conditions, trips, AR, 3D terrain, replay with friends — all need accounts/backends or paid map SDKs and add tabs. We stay at 3 tabs and local-first.
