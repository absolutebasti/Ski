# Schwung — device QA protocol (before every TestFlight build)

Physical iPhone, Release build (`flutter run --release` or the TestFlight build itself). Tick every box.

## A. Permissions and start
- [ ] Fresh install → onboarding shows 3 steps; step 3 triggers exactly: Location (While Using) → "Change to Always" → Motion & Fitness.
- [ ] Start with **Always**: Start works, blue location indicator appears when backgrounded.
- [ ] Start with **While Using** only: Start works; tracking continues when locked (day started in foreground).
- [ ] **Allow Once** / **Denied**: Heute shows the inline card with "Einstellungen öffnen"; Start blocked.
- [ ] **Precise Location off**: Start shows the "Genau ein" card; after enabling, Start works.
- [ ] Motion & Fitness denied: day records with `hasBarometer=false` (Diagnose page shows "Barometer: aus").

## B. Background continuity (the product)
- [ ] 60 min locked in a jacket pocket walking/cycling → Diagnose: points every ~1 s, no gap > 5 s, 0 stream restarts.
- [ ] Swipe-kill the app mid-day → relaunch within 30 min → recording resumes silently (pill visible, same day).
- [ ] Swipe-kill, wait > 30 min → Heute shows the recovery card; "Beenden & speichern" produces a finished day.
- [ ] With Always: swipe-kill, move ≥ 500 m → app relaunches in background (check Diagnose "watchdog relaunch" counter after opening).
- [ ] Airplane mode: tracking unaffected; map shows cached tiles or grey.
- [ ] Battery: 3 h locked → ≤ 8 %/h (note the value here: ____ %/h).

## C. Numbers
- [ ] Car ride: day auto-ends with the vehicle notification; no run recorded.
- [ ] Stairs/elevator: no run, no lift (validity thresholds).
- [ ] Mountain day (glacier/October) or the founder's 27.12.2025 fixture: runs ± 1, drop ± 5 %, top speed ± 3 km/h.
- [ ] Tag detail: ski-km and lift-km shown separately; gradient only on runs; Signalverlust bucket appears for tunnels/gondolas without barometer gain.

## D. UI
- [ ] Heute idle / live at 375 pt width and Dynamic Type xxL: nothing truncated.
- [ ] Hold-to-end needs 1.2 s; a tap does nothing.
- [ ] Tagesbilanz count-up runs once; PB chips only on real bests.
- [ ] Share: PNG card and GPX both arrive in Files/Messages; GPX opens in another app.
- [ ] Delete day and "Alle Daten löschen" really remove data (Tage empty, Diagnose counts 0).
- [ ] Language switch DE ↔ EN updates every screen without restart.

## E. Release
- [ ] Icon without alpha, launch screen cream/ink matches system theme.
- [ ] `tools/testflight.sh` builds; build number increases; Privacy manifest in bundle.
- [ ] TestFlight notes mention: background location, the three prompts, outdoor testing, how to send the diagnostics bundle.
