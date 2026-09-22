# Competitor notes — bergfex Ski (App Store screenshots, 2026-09-22)

Source: 8 App Store marketing screenshots supplied by the founder (IMG_1890–1897).
Identification: tab bar "Skigebiete · Tagebuch · Aufzeichnen · Community · Mehr", Geosphere Austria
precipitation maps, "5.000+ Live-Einblicke", "2 Mio. User pro Jahr" → bergfex Ski (Austria).

## Feature inventory

| Area | What they offer | Notes for us |
|---|---|---|
| Recording ("Aufzeichnen") | Full-screen topo map with piste overlay (blue/red/black pistes, dotted lift lines), live track in red, position puck with heading cone, layer + locate buttons. 2×2 live stats: Dauer, Distanz, Abstieg (hm), Top Speed. Big red "Skitag beenden" button, ski-mode toggle (left), "…" menu (right). | Whole-**day** model (one session = one ski day), not per-run start/stop. Copy this mental model. |
| Day summary ("Tagebuch") | Map of the entire day with labelled peaks; bottom sheet: auto-generated title "Sellaronda - Dolomiten/Sellaronda", date/time, visibility globe, activity type row ("Ski — Tippen zum Ändern"), "Statistiken" 2×3 grid: Abfahrten (13), In Bewegung (04:13), Höhenmeter (7.805 hm), Abfahrt-Distanz (46,6 km), max. Höhe (2.518 m), Top Speed (54,9 km/h); altitude-vs-distance area chart. | Auto-naming by resort + region is a great touch. Altitude profile is table stakes. |
| Community | Tabs Aktivitäten / Ranglisten; "Rangliste mit Freunden 2025/26" with filter chips (Skitage, Abfahrten, Zeit, Distanz, …); avatar ranking list; head-to-head "Vergleich – Saison" sheet with mirrored bars for Skitage, Abfahrten, Zeit, Distanz, Höhenmeter, max. Geschwindigkeit. | Not for v1 (needs accounts/backend). Season totals per user ARE for v1 (local). |
| Resort detail ("Skigebiete") | Map + card: name, altitude range (1.304–2.811 m), favourite heart, lift counts by type (chair 25, drag 43, gondola 16, cable car 1) as grey icon tiles, piste-km bar by difficulty (blue 129 / red 121 / black 50 / yellow ski routes 200 / total 500 km), season dates, operating hours, panoramic piste map image (expandable), Schneebericht: snow depth 40–80 cm (+10 cm neu), timestamp, "85/85 Lifte offen" green bar. | Lifts-open + snow depth + hours are the 3 numbers skiers check in the morning. Piste-map panorama is licensed content (they have partnerships). |
| Favourites ("Merkliste") | Per resort collapsible card: logo, name, altitude, 4 webcam thumbnails, 5-day forecast (icon, max/min temp, sun-hours yellow bar, fresh-snow cm), snow depth + lifts open. Tabs Übersicht / Webcams / Wetter. | Our resort card can be a lighter version: forecast (open-meteo), snow (open-meteo snowfall), lifts open (scraper) — no webcams. |
| Precipitation ("Mehr → Niederschlag") | Analyse / Prognose / Summen tabs, daily precipitation raster maps of the Alps, source Geosphere Austria, next-update time. | Skip; power-user feature. |
| Webcams | "5.000+" webcams, grid per resort, collapsible. | Skip for v1; licensed feeds. |
| Marketing | Hero: photorealistic skier in red jacket, blue sky, 2×2 stats overlay; social proof "2 Mio. User pro Jahr". Screens: bright blue (#1A8CFF-ish) background, white bold two-line headline, iPhone mockup. | Our screenshots must look calmer and more premium than this. |

## Visual language (what to remember)

- **Stock-iOS look**: white / light-grey (#F2F2F7) cards, ~16 pt corner radius, SF system font, black bold headings, grey secondary text.
- **Accent**: bright system blue for selection/CTA/links, **red** for "end ski day" and the live track line, green bar for lifts-open ratio, yellow for sun hours and ski routes.
- **Stat tiles**: small uppercase grey label → large bold number → smaller unit (e.g. `06:12 h`, `5.195 hm`, `48,5 km/h`). Always 2 columns.
- **Metrics vocabulary (German)**: Dauer, Distanz, Abstieg/Höhenmeter (hm), Top Speed / max. Geschwindigkeit, Abfahrten, In Bewegung, max. Höhe, Skitage.
- **Map style**: grey-shaded topographic relief with piste colours (OpenSnowMap-like), lifts as dotted black lines, peaks with elevation labels.
- **Navigation**: 5-tab floating pill bar, centre tab = record. Bottom sheets over maps for details.
- **Density**: high. Many numbers, many sections, many tabs. Reads as "portal app", not "companion".

## Where we can be clearly better

1. **Reliability & accuracy** as the headline: tracking that survives a locked phone all day, clean run segmentation, honest speeds. bergfex is a portal first, tracker second.
2. **Simplicity**: 3 tabs instead of 5; one "Today" screen; no community/webcam/precipitation clutter.
3. **Identity**: warm minimal brand (snow-cream + ink, sibling of ShapeMe) vs. generic iOS blue; mascot/coach for onboarding and encouragement.
4. **Day story**: after the day, a single beautiful summary card (runs, vertical, top speed, longest run, altitude profile) that is shareable.
5. **Season at a glance**: ski days, vertical, runs, top speed — personal, no accounts needed.

Things to *keep parity on* (users will expect them): whole-day recording with automatic run/lift detection, altitude profile, resort auto-detection and naming, lifts-open + snow depth + hours for the chosen resort, 5-day forecast with fresh snow.
