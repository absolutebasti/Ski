# SlopeTrack — device QA protocol (before every TestFlight build)

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
- [ ] Backend smoke test green against the live project: `tools/supabase-test.sh --live` (read-only, every file rolls back; token from the keychain item "Supabase CLI").

## F. Edge cases
Each line: what to do → what must happen. "Diagnose" = hidden page in Einstellungen.
- [ ] **Midnight:** start a day at ~22:00, leave the phone recording → at 03:00 local the day ends by itself, the "Skitag beendet" notification arrives, Tage shows the day with the trailing idle time trimmed. A day longer than 16 h ends at 16 h even before 03:00.
- [ ] **Time-zone change:** start a day, change the time zone in Settings by ≥ 1 h (or fly), come back → recording continues, elapsed time and run times stay consistent (epoch-based), the 03:00 rollover follows the *new* local time.
- [ ] **Reboot mid-day:** power-cycle the phone while recording → after unlock, opening the app within 30 min resumes silently (same day, same totals); after > 30 min the recovery card appears; "Beenden & speichern" finishes the day from the stored points.
- [ ] **Permission revoked mid-day (Settings → Location → Never):** back in the app within a few seconds the live view shows the "Kein Zugriff" chip and the pill says "Kein GPS"; a persistent notification "Kein Zugriff auf den Standort" is shown; granting again clears chip + notification. Left revoked for 30 min → the day ends and is saved with the dead time trimmed.
- [ ] **Location services switched off mid-day (Control Centre / Settings → Privacy → Location Services):** same as above, chip text "Ortung aus", without any app switch.
- [ ] **Motion & Fitness denied:** Start shows the one-line hint once; the live view carries the "GPS-Höhe" badge; Diagnose shows Barometer: nein; runs are still detected, vertical is within ±8 %.
- [ ] **Low Power Mode on before Start:** the one-line hint appears once at Start; Diagnose shows "Stromsparmodus: ja"; points still arrive ≈ 1 Hz (iOS keeps GPS for active navigation-style apps); switching it off mid-day flips the Diagnose row within 5 min.
- [ ] **Resort not detected (start in the valley car park > 12 km from the resort centre, or a resort missing from resorts.json):** the day starts without a resort name; once a fix inside a known area arrives (checked once a minute) the name appears on the day; a day that never enters a known area keeps "Freies Gelände" and syncs without a resort id.
- [ ] **Restore on a second device (same Apple account, signed in):** finished days appear in Tage after sync, with thumbnails regenerated locally; an *active* day never transfers — it lives on the recording phone only; ending it there syncs the finished day to the second device within one sync cycle.

## G. Delete account (end to end)
- [ ] Sign in, record or sync at least one day, join a group or send a friend request so rows exist in `days`, `profiles`, `group_members`/`friendships`.
- [ ] Einstellungen → Konto → "Konto löschen" → confirm (hold) → the app signs out and returns to the signed-out state; local days stay on the phone.
- [ ] Supabase Dashboard → Authentication: the user is gone; `select count(*) from public.profiles where id = '<uid>'` = 0; `days`, `group_members`, `friendships`, `blocks`, `reports` hold no rows for the uid (cascade from the Edge Function).
- [ ] Leaderboards no longer list the display name; a group the user owned either has a new owner or is gone (document which).
- [ ] Sign in again with the same Apple ID → a fresh profile with a new friend code; nothing from before is restored from the server.
