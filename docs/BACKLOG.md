# Build backlog (audit 2026-09-27)

Source: `.context/plan/backlog-2026-09-27.json` (five auditors, one skeptic each, planner). Wave 1 runs in parallel; wave 2 after it. Founder items at the end.


## Status 2026-09-28/29 (lead)
- **Backlog v2 wave 1 (2026-09-29) — done** (SOC-LOOP, SOC-RANGLISTE-2, TODAY-LIVE, UX-POLISH-1, TF-PLIST, BE-14): migration 0014 live + tests 0007/0008/0013/0014, Edge Function `report-notify` deployed (Vault secrets still founder), InfoPlist.strings variant group wired, `[functions.report-notify]` in config.toml, badge count from `pendingRequestsProvider`. 914 tests green. Next: wave 2 of `BACKLOG-2.md`.
- Wave 1 — **done** (BE-01, BE-02, SOC-FRIENDS, SOC-RIDER, UX-01); migrations 0005–0008 + 0006b live; Edge Function v2 deployed.
- Wave 2a — SOC-MODERATION **done**; SOC-RANGLISTE **mostly done** (friends scope, tappable rows → RiderSheet, my_rank strip, Länder card, 0013 live; review pending); SOC-CHALLENGE **partial** (module + 0010 live, no Dart tests, UI unreviewed); SHARE-CARDS **mostly done** (medal/level/rank/duel cards + goldens, wired into header/sheet/banner); SOC-DEEPLINK **partial** (parser + pages + entitlements done, listener not working, not mounted, app_links not added — listener tests skipped). Agents were cut off by the spend limit; the lead repaired compile errors and tests (453 green).
- Wave 2b, done by the lead on 2026-09-28 while agents were unavailable: DATA-RESORTS **done** (4.929 areas), SETTINGS-RELEASE **mostly done** (privacy manifest, bilingual plist strings, Support/Impressum rows, review note; InfoPlist.strings variant group skipped on purpose), UX-ONBOARDING **done** except the hook-card layout golden, TRACKING-GUARDS **partial** (rollover 03:00 + 16 h cap + resort retry done; permission-revoked handling, motion hint, Low Power hint, per-module tests, bundle fixture, QA.md §F open), SOC-DEEPLINK **mostly done** (app_links adapter, listener mounted, shell follows joins; listener widget tests still @Skip — handler unit-verified), SYNC-HARDENING **open** except the P0004/P0005 retry-later fix.
- Wave 2c (2026-09-28, two runs): UX-DAYS, SOC-CHALLENGE, SOC-DEEPLINK, SYNC-HARDENING, TRACKING-GUARDS, SOC-LIVE-DUEL (0009 live), PROFILE-PAGE — **all done** and wired by the lead (live-duel host, track restore bridge, image_picker avatar picker, flutter_timezone, profile page from settings, access/altitude chips, hint toasts, low-power diagnostics). 861 tests green.
- Still open (later): SOC-COMPARE, SOC-SEASONS, NOTIF-LOCAL, BE-TZ; lead items: theme-aware thumbnail PNGs at End, drift v3 schema (sync_outbox.next_attempt_at, days.track_path), Konto 'Bitte neu anmelden' line for SyncStatus.needsSignIn, live_days cleanup cron, duel member count from my_duels, uploader midnight guard.

## Wave 1

### BE-01 — Backend: RPCs als security definer, Grants, Team-Land, my_rank, Blocks, SQL-Smoke-Test
*testflight1 · M · backend* · depends on: —

Fixes the blocker that leaderboard/country_board/group_board only see the caller's own days (public.days has a single owner-only policy; all three RPCs are security invoker). Migration 0005_rpc_security.sql: (1) recreate leaderboard, country_board, group_board as `security definer set search_path = public`, group_board raises 42501 unless is_group_member(auth.uid()); (2) for every public function `revoke execute … from public, anon, authenticated`, then grant only join_group/leaderboard/country_board/group_board/my_rank to authenticated; ensure_weekly_challenges, is_group_member, shares_group_with get no client grant and ignore their user-id parameters (use auth.uid()); (3) team semantics: leaderboard(p_country) and country_board rank by coalesce(p.country_code, d.country_code) (the country the rider chose in onboarding, as GAMIFICATION §5 promises; days.country_code stays 'skied in'); (4) leaderboard additionally returns country_code, last_day (max started_at) and day_count; `limit least(greatest(p_limit,1),200)`; unknown p_metric raises 'bad_metric'; (5) new RPC my_rank(p_resort_id, p_season_key, p_metric, p_country) → (rank, total, value) from the same CTE for auth.uid(); (6) table blocks(user_id, blocked_id, created_at) with own-row RLS, excluded from leaderboard rows and group_board for the caller. Also supabase/config.toml ([functions.delete-account] verify_jwt = true) and tools/supabase-test.sh: `supabase start` + migrations + seed (two users, one opted in, one duel) + psql assertions with `set role authenticated; set request.jwt.claims`. docs/BACKEND.md: applied-migration snapshot section, definer pattern, my_rank documented as real. asks_lead: none. Other wave-1 migrations (0006–0008) must not redefine these three functions.

**Owns:** `supabase/migrations/0005_rpc_security.sql`, `supabase/config.toml`, `supabase/tests/**`, `tools/supabase-test.sh`, `docs/BACKEND.md`

**Acceptance:**
- SQL test: user A (opted in) calls leaderboard → sees own row AND user B's opted-in row; B not opted in is absent; anon call → permission denied
- group_board as a non-member → 42501; as member returns all members' totals (not 0 hm for partners)
- ensure_weekly_challenges/is_group_member/shares_group_with not callable via /rpc as authenticated (permission denied)
- German rider with days in Austria appears under p_country='DE' and scores for DE in country_board
- my_rank returns (rank,total,value) for a rider outside the top 100; p_limit 10^9 is clamped to 200; bad metric raises
- Blocked user's rows vanish from leaderboard/group_board for the blocker only
- tools/supabase-test.sh runs green locally; docs/BACKEND.md lists 0001–0005 as applied and the founder's dashboard check command

### BE-02 — Backend: Datenintegrität, Moderations-Schema, Profile-Härtung, Delete-Account-Fix
*store · M · backend* · depends on: —

Migration 0006_integrity.sql (independent of 0005: no redefinition of leaderboard/country_board/group_board): days check constraints (all metrics ≥ 0, ended_at ≥ started_at, started_at ≤ now()+1 day, elapsed_ms ≤ 20 h, season_key ~ '^\d{4}-\d{2}$'); `suspicious` extended with cross-field rules (drop_m > run_count×1500+500, ski_distance_m > drop_m×20, run_count > elapsed_ms/120000, max_speed_ms > 0 with ski_ms = 0); before-insert trigger raising 'too_many_days' at the 4th non-deleted day per user per local date and 'rate_limited' at > 30 upserts/hour; profiles: check char_length(display_name) between 1 and 24, avatar_url null or ~ '^https://'; 'profiles limited read' replaced by own-row only (verify with grep that profile_api.dart never selects other ids; other users are reached only via definer RPCs); challenges: drop policy 'challenges create', check char_length(title) ≤ 60; challenge_progress 'progress read' → own rows or opted-in users; groups.max_members check between 2 and 3 default 3; groups.created_by nullable `on delete set null`; policy 'groups delete own' for the creator; join_group raises 'duel_expired' when g.day < current_date - 1; storage: bucket tracks file_size_limit 20 MB + allowed_mime_types application/gzip, new public-read bucket avatars (own-folder write, 2 MB, image/jpeg|png); table reports(id, reporter, target_user_id, reason text ≤ 200, created_at) with insert-own RLS and no client read. Edge Function delete-account: paginate storage.list until empty, check remove() errors and return 500 before deleteUser, remove avatars/<uid>, set created_by null is automatic. asks_lead: update GAPS.md #8/#24 wording after merge.

**Owns:** `supabase/migrations/0006_integrity.sql`, `supabase/functions/delete-account/index.ts`

**Acceptance:**
- Insert of a day with drop_m = -1, ended_at < started_at, or season_key 'x' fails; 4th day on the same local date fails with too_many_days
- display_name of 25 chars rejected; 200-char name impossible server-side
- Signed-in user B cannot select A's profile row directly (only via RPC); own row fully readable
- Insert into challenges as authenticated → permission denied; join_group with a code from last week → duel_expired
- reports insert own works, select denied; avatars bucket: own path writable, public readable, 3 MB file rejected
- delete-account with 1500 track objects removes all of them and only then deletes the auth user; remove() error → 500 and auth user kept
- Migration applies cleanly after 0005 in tools/supabase-test.sh

### SOC-FRIENDS — Freunde: Freundescode, Anfragen, Freundesliste, Freunde-Rangliste (Server + Client-Modul)
*store · L · code* · depends on: —

The competition core has no social graph; boards are empty for early users. Migration 0007_friends.sql: profiles.friend_code char(6) unique (trigger on insert + backfill, alphabet without 0/O/1/I), friendships(user_id, friend_id, status enum pending|accepted, created_at) with own-row RLS (either side), RPCs add_friend_by_code(p_code) (creates pending, self-add and duplicates raise), accept_friend(p_user_id), remove_friend(p_user_id), friends_board(p_season_key, p_metric) security definer returning the leaderboard row shape (rank, user_id, display_name, avatar_url, country_code, value, total, last_day, day_count) over accepted friends + self, no share_leaderboards gate (friendship is explicit consent); all functions revoke from public/anon, grant to authenticated. Client module app/lib/features/social/friends/: FriendsApi (abstract) + SupabaseFriendsApi + FakeFriendsApi, models, friendsProvider/pendingRequestsProvider/friendsBoardProvider(query), FriendsSheet (AppSheet: my code big + 'Teilen' share text 'Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2 · https://slopetrack.app/f/KMJ4F2', code entry field with LengthLimiting 6, pending requests with accept/decline, friend list with remove via swipe), friends_strings.dart DE/EN. Exposes `FriendsSheet.show(context)` and `friendsBoardProvider` for SOC-RANGLISTE (which adds the 'Freunde' chip and empty-state CTA). Does NOT edit social_models/social_screen/social_strings.

**Owns:** `supabase/migrations/0007_friends.sql`, `app/lib/features/social/friends/**`, `app/test/features/social/friends/**`

**Acceptance:**
- SQL test: A adds B by code → pending; B accepts → friends_board for A lists B even when B has share_leaderboards = false; C (not a friend) sees neither
- Wrong code → 'code_not_found'; own code → 'self'; duplicate → 'already_friends'; friend_code is unique across 10k inserts (test loop)
- Widget tests with FakeFriendsApi: sheet shows code, share button builds the text with link, entering a code calls addFriend, pending request accept updates list, remove friend
- Strings DE/EN complete; analyzer clean; existing 334 tests unaffected

### SOC-RIDER — Rider-Profil: rider_profile RPC + RiderSheet (Level, Medaillen, Saison, Herausfordern)
*store · M · code* · depends on: —

Leaderboard rows are dead ends – a rider cannot see who is above them. Migration 0008_rider_profile.sql: rider_profile(p_user_id) security definer returning display_name, avatar_url, country_code, home_resort_id, season_key, season drop_m/ski_distance_m/run_count/day_count/points, lifetime ski_distance_m (for levelFor), medal-relevant totals (lifetime drop_m, run_count, day_count, max_speed_ms), last_day; visible only if target has share_leaderboards, shares a group with the caller, or an accepted friendship exists (friendships table may not exist yet → check via `to_regclass('public.friendships')` guard or make the friendship clause a later ALTER in SOC-RANGLISTE; document choice); revoke from public/anon, grant authenticated. Client app/lib/features/social/rider/: RiderApi + Supabase + Fake, RiderProfile model, riderProfileProvider(userId), RiderSheet (AppSheet: AvatarCircle/initials, CountryFlag, 'LEVEL n · title' from achievements levelFor(lifetime distance), 4 numerals (hm, km, Abfahrten, Tage), medal count from medal_catalog thresholds on the returned totals, 'Herausfordern' → existing socialApiProvider.createDuel(resortId: null) + share text, 'Freund hinzufügen' placeholder slot that SOC-RANGLISTE/SOC-FRIENDS fill later), rider_strings.dart DE/EN, `RiderSheet.show(context, userId)` as the only public entry. Leaves rider_sheet.dart with a clearly marked `actions` slot for SOC-MODERATION (Melden/Blockieren).

**Owns:** `supabase/migrations/0008_rider_profile.sql`, `app/lib/features/social/rider/**`, `app/test/features/social/rider/**`

**Acceptance:**
- SQL test: rider_profile for an opted-in stranger returns the row; for a non-opted-in stranger → null/empty; for a duel partner → row
- Widget test with FakeRiderApi: sheet renders name, flag, level title, 4 numerals, medal count; loading skeleton; error state with retry
- 'Herausfordern' calls createDuel and opens the share sheet (fake SharePlus in test) with the duel code
- Semantics label on the sheet ('Profil von Lena B.'); DE/EN strings; analyzer clean

### UX-01 — Tagesbilanz- und Gamification-Politur (TestFlight-Kosmetik in einem Paket)
*testflight1 · M · code* · depends on: —

All confirmed UX defects in features/summary and features/achievements. Summary: notification opt-in sheet only on 'Fertig' tap (before pop) and dismissible; TIME card uses Fmt.durationCompact and the legend's last segment = total − others so it sums; RecordCard + medal banner never stack as solid slabs (medals rendered as CardTone.accent wash cards when a record exists); CircularProgressIndicator → shared skeleton rows (local widget in summary until the lead promotes it); 'Bis zum nächsten SlopeTrack.' → 'Bis zum nächsten Tag.' / 'See you next time.' and $kAppName interpolation in summary strings. Achievements: LevelRing disc c.isDark ? c.ink : c.surfaceRaised so the numeral is visible in light; MedalTile fixed height (~132) with a 14 pt footer slot for date OR progress rule, titles one line; header: replace Wrap with a 3-column fixed row (SERIE · KM · MEDAILLEN) and move the points formula caption into the Medaillen sheet header; streak chip mark → small chevron glyph instead of the 10×2 bar; level caption states 'Level nach km · Punkte für die Rangliste' with 'noch 8 km bis Level 3' next to the ring; drop the +25 streak bonus from dayPoints so device points equal server points (update docs/GAMIFICATION.md §1 and the formula caption); Semantics on LevelRing ('Level 2 Einsteiger, 38 % bis Level 3') and MedalTile (title, threshold, earned date or 'offen, 40 %'); selectionClick haptics on medal sheet open. asks_lead: shell.dart tab-state fix (drop KeyedSubtree(ValueKey(_index)) around IndexedStack, fade per page) + app/test/app/shell_state_test.dart; add level ring + day card to the light golden set.

**Owns:** `app/lib/features/summary/**`, `app/lib/features/achievements/**`, `app/test/features/summary/**`, `app/test/features/achievements/**`, `docs/GAMIFICATION.md`

**Acceptance:**
- tagesbilanz_screen_test: NotificationsOptInSheet is absent while the count-up animates and appears after tapping Fertig; sheet can be dismissed
- Legend minutes sum to the header value for a fixture with 37.6 min total; TIME card shows '38 min' not '0:38:12'
- Fixture with record + 2 new medals renders exactly one solid champagne card
- Light-theme golden/widget test: LevelRing numeral color != disc color; MedalTile heights equal within a row
- achievements_engine test: points for a streak day == dayPointsOf formula (no +25); GAMIFICATION.md §1 updated
- Header has no Wrap; formula string not rendered on the Rangliste header; streak chip has no 2 pt bar
- All existing 334 tests green, analyzer clean


## Wave 2

### SOC-RANGLISTE — Rangliste-Kern: Freunde-Chip, tippbare Zeilen, Flaggen/Delta, eigener Rang, Refresh, Opt-in inline, Fehler-Copy
*store · L · code* · depends on: BE-01, SOC-FRIENDS, SOC-RIDER

Owns the shared social files and wires wave-1 results into the board. (1) LeaderboardScope.friends chip first in the row → friendsBoardProvider (SOC-FRIENDS); empty board state CTA 'Freunde einladen' → FriendsSheet.show; Konto/Rider 'Freund hinzufügen' slot filled via FriendsApi. (2) LeaderboardEntry gains countryCode, lastDayMs, dayCount (BE-01 columns); rows show CountryFlag 16 pt after the name, caption 'zuletzt Sa · 7 Tage', delta to leader in tertiary; podium winner flag ring; AvatarCircle accepts avatarUrl (network image with initials fallback). (3) LeaderboardRow, _PodiumColumn, duel rows wrapped in Pressable → RiderSheet.show(userId) (SOC-RIDER); combined Semantics label '<rank>. <name>, <value> <unit>'. (4) myRankProvider(query) via my_rank RPC; own-row strip always renders (rank/total or notRankedYet copy); 'Zu mir springen' loads the window around the own rank (add p_offset to LeaderboardQuery, RPC already clamps). (5) Explainer button calls profileService.update(shareLeaderboards: true) directly and invalidates; Konto switch remains for opt-out. (6) Refresh: invalidate leaderboard/country/friends/myRank providers when syncStatus pending drops to 0 after a push, on tab re-entry > 5 min, and via CupertinoSliverRefreshControl. (7) Error copy per kind ('Hat nicht geklappt. Versuch es gleich noch einmal.'), _BoardSkeleton while auth loads, signed-out button relabelled 'Anmelden' (opens Konto); DE/EN title consistency; selectionClick haptics on segment/chip taps; kAppName interpolation in social strings; duel create with resortId: null (Gebiet filter informational only). asks_lead: shell.dart EN tab label 'Leaderboard'; optional Glyph additions.

**Owns:** `app/lib/features/social/social_screen.dart`, `app/lib/features/social/social_models.dart`, `app/lib/features/social/social_api.dart`, `app/lib/features/social/social_strings.dart`, `app/lib/features/social/social_controls.dart`, `app/lib/features/social/leaderboard_providers.dart`, `app/lib/features/social/leaderboard_view.dart`, `app/lib/features/social/country_card.dart`, `app/lib/features/social/fake_social_api.dart`, `app/lib/features/social/social.dart`, `app/test/features/social/social_screen_test.dart`, `app/test/features/social/social_models_test.dart`, `app/test/features/social/leaderboard_total_test.dart`, `app/test/features/social/country_card_test.dart`, `app/test/features/social/social_fixtures.dart`

**Acceptance:**
- social_screen_test: 'Freunde' chip present and first; selecting it shows friends board from the fake; empty friends board shows 'Freunde einladen' which opens FriendsSheet
- Tapping a leaderboard row or podium column opens RiderSheet with that userId (fake)
- Row renders flag, 'zuletzt …' caption and delta for entries with countryCode/lastDayMs; entry parsing test for the new RPC columns
- Own-row strip renders 'Platz 140 von 900' from myRankProvider when the user is outside the fetched slice; 'Du bist noch nicht gewertet' when my_rank returns null
- Explainer action sets shareLeaderboards = true via FakeProfileApi and the board loads without opening the Konto sheet
- After a fake sync completion tick the leaderboard provider refetches (test counts fake API calls); pull-to-refresh present
- Non-offline error shows the new copy, not the offline line; auth loading shows the skeleton; signed-out button label 'Anmelden'/'Sign in'
- Analyzer clean, all tests green

### SOC-LIVE-DUEL — Tagesduell live + Ergebnis + Historie + Tagesbilanz-Hook
*store · L · code* · depends on: BE-01, BE-02, UX-01, SOC-DEEPLINK, SHARE-CARDS

Duel numbers appear only after a member ends the day; no result, no history, no Tagesbilanz mention. Migration 0009_live_duel.sql (after 0005/0006): live_days(user_id pk, day date, resort_id, drop_m, run_count, ski_distance_m, max_speed_ms, updated_at) with own-write RLS and read via is_group_member; groups.tz text (IANA from creator, default 'Europe/Vienna'); group_board redefined (sole redefiner in wave 2) to coalesce the live row when no finished day exists, match by (started_at at time zone g.tz)::date = g.day, drop the resort filter, and return is_live + updated_at; RPC my_duels(p_limit) returning the caller's groups ordered by day desc with final board. Client app/lib/features/social/duel/ (move duel_card.dart, group_providers.dart, duel_card_test here): DuelApi + Supabase + Fake (createDuel with name, tz, resortId null; upsertLive; myDuels; retry once on 23505 code collision), LiveDuelUploader (listens to liveStateProvider while myDuelProvider != null, upserts every 120 s or on finished run, stops at endDay, tiny payload), duel card header '2 / 3', 'live' dot + 'vor 2 min', optional name field on create (duelName string), duel_history.dart list under the card ('Gestern · Platz 2 von 3 · 1.849 hm') with result sheet, DuelResultCard for the Tagesbilanz (final board, winner ringed, 'Teilen' via SHARE-CARDS duel card) and RankTeaser line ('Platz 14 in Kitzbühel · Saison' from my_rank) inserted into tagesbilanz_screen.dart (owned here in wave 2, after UX-01). mediumImpact haptic on duel created/joined. Share text uses InviteLinks.duel(code) from SOC-DEEPLINK.

**Owns:** `supabase/migrations/0009_live_duel.sql`, `app/lib/features/social/duel/**`, `app/lib/features/social/duel_card.dart`, `app/lib/features/social/group_providers.dart`, `app/lib/features/summary/tagesbilanz_screen.dart`, `app/test/features/social/duel/**`, `app/test/features/social/duel_card_test.dart`, `app/test/features/summary/duel_result_card_test.dart`

**Acceptance:**
- SQL test: member A has only a live_days row (1200 hm), B a finished day → group_board shows both values, A flagged is_live; after A's day is finished the finished value wins
- group_board ignores resort_id; a member in a Colorado tz group is matched by g.tz
- Widget test: with a live state and an active duel the fake DuelApi receives an upsertLive within the 120 s tick; none after endDay
- Duel card shows '2 / 3' and 'live · vor 2 min'; history list renders three past duels from the fake with place and hm
- Tagesbilanz fixture with a duel for that day shows DuelResultCard with the winner ringed; RankTeaser renders 'Platz 14 in Kitzbühel · Saison'
- createDuel retries once on unique violation; duel_expired error maps to a readable toast
- Analyzer clean, tests green

### SOC-CHALLENGE — Wochen-Challenge: Teilnehmer, Server-Fortschritt, Board, Historie, zweisprachige Titel
*store · M · code* · depends on: BE-01, BE-02, SOC-RIDER

Challenge progress is a client-trusted snapshot written once; no participants count, no board, no history, German-only titles. Migration 0010_challenges.sql (after 0005/0006): challenge_participants(challenge_id, user_id, joined_at) with own-row RLS (replaces challenge_progress; migrate existing rows, keep the old table read-only until the next release); challenges.title_de/title_en + metric/target so the client can localise; ensure_weekly_challenges writes both titles; RPC challenge_board(p_challenge_id) security definer computing each participant's value from days within starts_on…ends_on (same filters as leaderboard, blocked users excluded), returning rank, user_id, display_name, avatar_url, value, done, participants (count over()) and done_count; RPC my_challenge_history(p_limit) for ended challenges the caller joined with final value/rank. Client app/lib/features/social/challenge/ (move challenge_card.dart, challenge_providers.dart, challenge_card_test here): ChallengeApi + Supabase + Fake (join, leave, board, history), card shows 'n dabei · m geschafft', 'Mitmachen' inserts the participant row only (no value), progress still shown from local days, tap → ChallengeBoardSheet (rows tappable → RiderSheet.show), challengeHistoryProvider list under the card, mediumImpact haptic on join, title picked by locale. Completion medal deferred (medal_catalog owned elsewhere; note in goal).

**Owns:** `supabase/migrations/0010_challenges.sql`, `app/lib/features/social/challenge/**`, `app/lib/features/social/challenge_card.dart`, `app/lib/features/social/challenge_providers.dart`, `app/test/features/social/challenge/**`, `app/test/features/social/challenge_card_test.dart`

**Acceptance:**
- SQL test: two participants, one with 2 days inside the window (done), one without → challenge_board returns participants = 2, done_count = 1, correct values; non-participant A's days do not count
- A user cannot write a progress value anywhere (no client-supplied value column reachable)
- Card renders 'n dabei · m geschafft' from the fake; tapping opens ChallengeBoardSheet; history lists ended challenges with result
- Titles render DE on a German locale and EN on English (fixture with both columns)
- Analyzer clean, tests green

### SOC-MODERATION — Melden / Blockieren / Namensregeln (Apple 1.2 UGC)
*store · M · code* · depends on: BE-01, BE-02, SOC-RIDER

Display names are public UGC with no report, block or filter path – a review-rejection risk. Client module app/lib/features/social/moderation/: ModerationApi + Supabase + Fake (report(targetUserId, reason) → reports insert from BE-02; block/unblock → blocks table from BE-01; blockedIdsProvider), ReportSheet (reason chips: 'Anstößiger Name', 'Betrug/unrealistische Werte', 'Sonstiges' + optional text ≤ 200; toast 'Danke, wir schauen uns das an'), BlockConfirmSheet, name_rules.dart (pure functions: maxLength 24, trim, collapse whitespace, small DE/EN word list → `NameCheck.reject(reason)`; used by PROFILE and ONBOARDING packages), moderation_strings.dart. Adds 'Melden' and 'Blockieren' to the actions slot of rider_sheet.dart (owned here in wave 2, after SOC-RIDER); after a block, invalidate leaderboard/group providers (they exclude server-side) and show 'Blockiert'. Settings 'Blockierte Nutzer' list is out of scope (later). Also writes the review-note paragraph for docs/APP-STORE.md into a text block the SETTINGS-RELEASE package pastes (put it in moderation_strings.dart as a doc comment, not in APP-STORE.md).

**Owns:** `app/lib/features/social/moderation/**`, `app/lib/features/social/rider/rider_sheet.dart`, `app/test/features/social/moderation/**`

**Acceptance:**
- RiderSheet shows 'Melden' and 'Blockieren'; Melden opens ReportSheet and the fake API receives (targetUserId, reason); Blockieren asks for confirmation then calls block and the sheet shows 'Blockiert'
- name_rules tests: 25 chars → rejected, ' Lena  B. ' → 'Lena B.', a listed word → rejected, normal names pass, umlauts/emoji length counted by characters
- blockedIdsProvider refreshes after block/unblock; leaderboard providers invalidated (test counts calls)
- DE/EN strings complete; analyzer clean

### PROFILE-PAGE — Eigenes Profil: Avatar-Upload, Team-Land ändern, Level/Medaillen/Saison, Namensfeld-Limit
*store · M · code* · depends on: BE-02, SOC-MODERATION, SOC-FRIENDS

Konto sheet shows only name, home resort, opt-in and sync; country cannot be changed after onboarding; avatar_url is never set or rendered. In features/account: ProfilePage (or extended AccountSheet) with header AvatarCircle (tap → image_picker → square crop/resize ≤ 512 px → upload to bucket avatars/<uid>.jpg → profiles.avatar_url), display name field with maxLength 24 + LengthLimitingTextInputFormatter + NameCheck from SOC-MODERATION (inline error), CountryFlag + 'Team ändern' (own CountryPickerSheet in account/ built from onboarding_countries list; calls settings.setCountry + profileService.pushCountry), home resort row, LevelRing + points + StreakChip + 'n / 48 Medaillen' → MedalsSheet, season and lifetime numerals from achievementsProvider, friend code row with 'Freunde' → FriendsSheet.show (SOC-FRIENDS), support/contact row (mailto kSupportEmail). Consolidate the Apple button: account's private _AppleButton adopts the onboarding AppleSignInButton look (black in dark, white in light, Apple glyph) – onboarding file stays untouched. ProfileApi/ProfileService gain avatarUrl update and pushCountry. Settings 'Konto' row opens this page (account_row.dart). asks_lead: add image_picker + cached_network_image to pubspec; NSPhotoLibraryUsageDescription only if image_picker requires it on iOS 17+ (verify).

**Owns:** `app/lib/features/account/**`, `app/test/features/account/**`

**Acceptance:**
- Widget test: signed-in page shows avatar/initials, name, flag with 'Team ändern', home resort, level ring, medal count, season numerals, friend code row
- Changing the team country calls settings.setCountry and FakeProfileApi.update(countryCode); the flag updates
- Name field cannot exceed 24 chars; a rejected name shows the inline hint and does not call update
- Avatar pick (fake picker) uploads to 'avatars/<uid>.jpg' and updates avatar_url in the fake; AvatarCircle shows the network image
- Existing account_sheet_test/profile_service_test adapted and green; analyzer clean

### SOC-DEEPLINK — Einladungslinks: URL-Scheme + Universal Links, Join-Flow, Web-Fallback
*store · M · code* · depends on: SOC-FRIENDS

Invites are plain text with a 6-char code and no link. Module app/lib/features/social/invite/: InviteLinks (duel(code) → 'https://slopetrack.app/d/<CODE>', friend(code) → '/f/<CODE>', plus scheme fallback 'slopetrack://d/<CODE>'), InviteLinkHandler (app_links stream + initial link; parses /d and /f; if signed in → joinDuel / add_friend_by_code and toast + navigate to Rangliste; else store the pending code in SharedPreferences and resume after sign-in), invite_strings.dart, share text builders that include the link and the App Store URL placeholder from brand. iOS: Runner.entitlements adds com.apple.developer.associated-domains = applinks:slopetrack.app; Info.plist adds CFBundleURLTypes (slopetrack) and FlutterDeepLinkingEnabled. Web fallback pages docs/d/index.html and docs/f/index.html (GitHub Pages; read the code from the hash/query, show it big, 'In SlopeTrack öffnen' → slopetrack://…, store badge placeholder) and docs/apple-app-site-association template for the founder's domain. asks_lead: app_links in pubspec; call InviteLinkHandler.start(ref) from app.dart; kAppStoreUrl constant in brand.dart once the ASC record exists.

**Owns:** `app/lib/features/social/invite/**`, `app/ios/Runner/Runner.entitlements`, `app/ios/Runner/Info.plist`, `docs/d/**`, `docs/f/**`, `docs/apple-app-site-association`, `app/test/features/social/invite/**`

**Acceptance:**
- Unit tests: InviteLinks.duel('KMJ4F2') and parse round-trip for https, scheme and /f links; malformed links ignored
- Handler test with a fake auth state: signed in → joinDuel called with the code and a toast shown; signed out → code persisted, then consumed once on sign-in
- plutil -lint passes for Info.plist and Runner.entitlements; entitlement contains applinks:slopetrack.app; URL type slopetrack registered
- docs/d/index.html renders the code from '#KMJ4F2' and offers the scheme link (manual check in a browser)
- Analyzer clean

### SYNC-HARDENING — Sync: Outbox-Backoff, 401-Handling, Cursor pro Nutzer, Pull bei Resume, Spur-Restore, Storage-Löschung
*store · L · code* · depends on: —

Outbox entries are stranded after 3 failures, cursor is per device, pull only on start, tracks are upload-only, soft-deleted days keep their points and storage objects. In lib/data/sync + days_repository: replace the hard attempt cap with nextAttemptAt exponential backoff (max 1 h) and reset attempts on app start and sign-in; AuthException/401 → refreshSession once, retry, else SyncState.error(needsSignIn) exposed for the Konto sheet; cursor key 'sync.lastSyncAt.<uid>' and reset on user change (unsynced local days stay local and are re-queued under the new uid only after an explicit confirm flag — default: not migrated); syncNow on AppLifecycleState.resumed debounced 5 min; fetchDays paginated with .range() 500 rows, cursor advanced after the last page; SyncApi.downloadTrack + removeTrack; trackRestoreProvider(dayId) that downloads and decodes the DiagnosticsBundle into points/segments when the local day has 0 points and track_path is set (UX hook wired by UX-DAYS); pushDelete also calls removeTrack; softDeleteDay deletes local points/segments; DaysRepository.updateResort(dayId, resortId) re-enqueues the day (used by UX-DAYS). Tests in app/test/data/sync and db_test.

**Owns:** `app/lib/data/sync/**`, `app/lib/data/db/days_repository.dart`, `app/test/data/**`

**Acceptance:**
- outbox_test: entry failing with a 500 three times is retried after backoff instead of skipped forever; attempts reset on start
- 401 from the fake API triggers refreshSession; a second 401 yields SyncState.error(needsSignIn) and no attempt bump
- Switching uid A → B: cursor for B starts at epoch, A's cursor preserved; A's unsynced outbox entries are not pushed under B by default
- fetchDays with 1200 fake rows pulls all three pages and sets the cursor to the last row
- Restore test: pulled day with track_path and 0 points → after trackRestoreProvider, points and segments exist and day detail fields (signalLossMs etc.) are recomputed
- softDeleteDay removes points/segments locally; pushDelete calls removeTrack on the fake storage
- All sync/db tests green; analyzer clean

### UX-DAYS — Tage/Heute/Detail-Politur: Skeletons, Toast, Heute-Caption, Skigebiet ändern, Spur laden, Light-Thumbs
*testflight1 · M · code* · depends on: SYNC-HARDENING

In features/days, features/today and features/map: CircularProgressIndicator on Tage and Tag detail → skeleton rows; heute_screen 'Zu kurz' SnackBar → showToast; Heute caption reads the active day's resortName while recording and falls back to lastResortId when idle (rename the misnamed variable); Tag detail gets a 'Skigebiet ändern' action (resort picker sorted by distance to the day's first point) calling DaysRepository.updateResort (SYNC-HARDENING); Tag detail shows 'Spur wird geladen' and a 'Spur laden' button when points are empty and a track_path exists (trackRestoreProvider); PB tile overlines shortened ('LÄNGSTE'/'LONGEST', 'BESTER TAG'/'BEST DAY') so the row keeps one baseline; season card passes a ≥ 14-slot padded value list so the sparkline never shows three fat blocks; MetricStrip callers pass real labels ('ABFAHRTEN', 'HÖHENMETER', 'TOP-SPEED') ready for the lead's overline-first flip; light theme: DayThumb, thumbnail renderer and TrackThumbnailPainter use a `routeGround` colour (dark #101216, light #EDEAE2 with darker champagne route) provided locally until the lead adds the token; kAppName interpolation in today strings. asks_lead: MetricStrip overline-above-numeral flip + PbTile fixed 64 pt in lib/app/widgets/numbers.dart; Sparkline fixed 6 pt bars; c.routeGround token in theme.

**Owns:** `app/lib/features/days/**`, `app/lib/features/today/**`, `app/lib/features/map/**`, `app/test/features/days/**`, `app/test/features/today/**`, `app/test/features/map/**`

**Acceptance:**
- No CircularProgressIndicator or ScaffoldMessenger.showSnackBar left in days/today (grep in test)
- heute_screen_test: recording an unresolved day shows no stale resort name; idle shows lastResortId's name
- day_detail test: 'Skigebiet ändern' updates the day via the fake repository; 'Spur laden' triggers the restore provider and the map appears
- season_card_test: 3-day season renders 14 slots; PB tiles share one baseline in a golden at 375 pt width
- Light golden: day thumbnail background is not near-black
- Analyzer clean, tests green

### UX-ONBOARDING — Onboarding-Politur: P1-Layout, Weiter ohne Chevron, Top-Speed-String, Rangliste-Opt-in, Namenslimit
*testflight1 · S · code* · depends on: —

In features/onboarding: P1 anchors the hook card in the lower third (Column with spaceBetween, rider full height beside it) instead of ending at 48 % height; 'Weiter' without the leading chevron (drop glyph until PrimaryButton has trailingGlyph); p1TopSpeed localised ('Top-Speed'/'Top speed'); ReadyPage after a successful sign-in shows a champagne switch row 'In Ranglisten erscheinen' (default on, hint 'Name und Tageswerte, nie die Spur') calling profileService.update(shareLeaderboards:) so new accounts are visible on day 1; name TextField maxLength 24 + LengthLimitingTextInputFormatter; AppleSignInButton made public (export) so PROFILE-PAGE can reuse the look later; Material Icons in onboarding replaced by Glyph where a glyph exists (list the remainder in a comment for the lead). Tests in onboarding_flow_test.

**Owns:** `app/lib/features/onboarding/**`, `app/test/features/onboarding/**`

**Acceptance:**
- onboarding_flow_test: after fake sign-in the ReadyPage shows the opt-in switch on by default and FakeProfileApi receives shareLeaderboards = true on 'Los geht's'; toggling off sends false
- 'Next'/'Weiter' button has no leading chevron; EN P1 shows 'Top speed'
- Golden at 393×852: hook card bottom edge within the lower third
- Name field rejects the 25th character
- Analyzer clean, tests green

### SETTINGS-RELEASE — Release-Paket: Privacy-Manifest, InfoPlist.strings DE/EN, Impressum/Support-Row, Doku-Abgleich
*store · S · code* · depends on: —

PrivacyInfo.xcprivacy still declares only Location + Fitness 'not linked'; purpose strings German-only; Datenschutz row launches a dead URL; docs carry stale bundle ids. iOS: PrivacyInfo.xcprivacy → PreciseLocation (linked, AppFunctionality), Fitness (linked), UserID, EmailAddress, Name, OtherUserContent (display name), CoarseLocation (country/home resort), Tracking = false, matching the table in docs/APP-STORE.md; add de.lproj/InfoPlist.strings and en.lproj/InfoPlist.strings with the four usage keys + temporary-accuracy entry (Info.plist itself is owned by SOC-DEEPLINK — coordinate: keys stay, values move to .strings only if Info.plist edit is not needed; otherwise leave literals and add en.lproj only). Settings: new group rows 'Impressum' and 'Support' (bundled offline text with the founder's address placeholder + mailto kSupportEmail), Datenschutz row opens the hosted GitHub Pages URL (via a local constant until the lead fixes kPrivacyUrl), remove the dead 'Einheiten' row, Icons.build_outlined → build_rounded, Diagnose page shows local DB size, $kAppName interpolation in settings strings. Docs: APP-STORE.md review notes updated (Sign in optional, leaderboards opt-in, Melden/Blockieren mechanism from SOC-MODERATION, video link placeholder, Konto löschen path), 'Release checklist' section with the founder items; HANDOVER.md/PLAN.md stale bundle ids replaced. asks_lead: kPrivacyUrl → https://absolutebasti.github.io/Ski/privacy.html; pubspec version 1.0.0+N before store submission; GAPS.md refresh.

**Owns:** `app/ios/Runner/PrivacyInfo.xcprivacy`, `app/ios/Runner/de.lproj/**`, `app/ios/Runner/en.lproj/**`, `app/lib/features/settings/**`, `app/test/features/settings/**`, `docs/APP-STORE.md`, `docs/HANDOVER.md`, `docs/PLAN.md`

**Acceptance:**
- plutil -lint PrivacyInfo.xcprivacy passes; it lists 7 collected data types with Linked = true and Tracking = false, identical to the APP-STORE.md nutrition table
- InfoPlist.strings DE and EN contain NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, NSMotionUsageDescription (+ temporary accuracy key)
- settings_sheet_test: Impressum and Support rows present and open a sheet / mailto; Einheiten row gone; Datenschutz opens the hosted URL
- grep for 'dropline' and 'schwung' bundle ids in docs/ → none outside NAMING history; APP-STORE.md has a Release checklist
- Analyzer clean, tests green

### TRACKING-GUARDS — Tracking: Mitternachts-/Maximaldauer-Guard, Resort-Retry, Berechtigungen im Tag, Low-Power-Hinweis, Modul-Tests, Fixture-Importer
*store · L · code* · depends on: —

In lib/tracking, features/recording, platform and their tests: GuardAction.autoEndMidnight (local 03:00 or 24 h after start) and maxDayH = 16 (constants live in core → asks_lead to add TrackingConfig fields; use local constants until then); _resolveResort only marks resolved when a resort was found and retries every 60 s of accepted fixes; subscribe to Geolocator.getServiceStatusStream and re-check permission on resume → LiveState gps 'kein Zugriff' + persistent local notification, auto-end after 30 min without access; motion permission checked in startDay with a one-line hint and a 'GPS-Höhe' badge in the live view when the barometer is missing; Battery().isInBatterySaveMode polled with the 5-min sample → one-time hint at Start + diagnostics field; per-module tests (gate, segmenter, vertical, speed, finalize, guards, batch_writer, gps_quality) table-driven per threshold; test/support/bundle_fixture.dart decoding a DiagnosticsBundle .json.gz and a minimal GPX reader (package:xml) so device days become fixtures; a 10 h synthetic stress test asserting per-tick time and no quadratic growth. docs/QA.md: section F 'Edge cases' (midnight, tz change, reboot mid-day, permission revoked mid-day, Low Power Mode, resort not detected, restore on second device) + delete-account end-to-end steps + backend smoke-test line.

**Owns:** `app/lib/tracking/**`, `app/lib/features/recording/**`, `app/lib/platform/**`, `app/test/tracking/**`, `app/test/features/recording/**`, `app/test/platform/**`, `app/test/support/bundle_fixture.dart`, `app/test/fixtures/**`, `docs/QA.md`

**Acceptance:**
- guards_test: a day started 09:00 auto-ends at 03:00 next day; a day > 16 h auto-ends; existing idle/vehicle behaviour unchanged
- recording_controller_test: first fix outside any resort leaves _resortResolved false and a later fix inside sets the resort
- Service status 'disabled' mid-day → LiveState shows the access state and a notification is scheduled (fake notification service)
- Motion denied → hint shown once and hasBarometer false flows to live view badge
- 8 new test files, each module ≥ 5 cases; stress test 36k points < 5 ms/tick average on CI machine
- bundle_fixture decodes a committed sample bundle into TrackPoints; QA.md has section F
- Analyzer clean, tests green

### SHARE-CARDS — Share-Karten für Medaille, Level, Rang, Duell (Show-Säule)
*store · M · code* · depends on: UX-01

ShareCard renders only a day. In features/share: ShareCardKind { day, medal, level, season, rank, duel } with a ShareCardData union; painters reuse the graphite/champagne/grain system: medal card (TierRing 320 px + title + threshold + date), level card (LevelRing + 'Level 4 · Carver' + km), season card (4 numerals + days), rank card (mini podium + 'Platz 3 in Kitzbühel · Saison 26/27'), duel card (three rows, winner ringed); ShareService.shareCard(kind, data) with 1080×1920 and 1080×1080 formats; entry points owned here: NewMedalsBanner tap and MedalTile long-press (achievements ui files, after UX-01), AchievementsHeader level tap. Rank and duel entry points are wired by SOC-RANGLISTE (OwnRankStrip) and SOC-LIVE-DUEL (DuelResultCard) via depends_on. Golden tests per kind in both formats; share strings DE/EN with $kAppName.

**Owns:** `app/lib/features/share/**`, `app/lib/features/achievements/ui/new_medals_banner.dart`, `app/lib/features/achievements/ui/medals_sheet.dart`, `app/lib/features/achievements/ui/achievements_header.dart`, `app/test/features/share/**`

**Acceptance:**
- Golden tests for medal, level, season, rank, duel cards in 9:16 and 1:1; existing day card goldens unchanged
- share_service_test: shareCard(kind.medal, data) writes a PNG and calls SharePlus with the file
- Tapping a NewMedalsBanner card or long-pressing an earned MedalTile calls ShareService.shareCard(medal)
- Only one accent element per card; text never clipped for the longest DE title
- Analyzer clean, tests green

### DATA-RESORTS — Skigebiets-Datenbank: OpenSkiMap-Import (~5k Gebiete), Grid-Index, Aliase für die 52 IDs
*store · L · code* · depends on: —

52 hand-picked Alpine resorts; everything else is 'Freies Gelände' with no weather or resort board. tools/data/import_resorts.py: OpenSkiMap ski_areas.geojson + lifts.geojson → app/assets/data/resorts.json.gz (id, name + alt names, country ISO-2, centroid, radiusKm = max(1.5, sqrt(area/π)·1.3) clamped 20, baseAltM/summitAltM from lift stations, curated flag), alias table mapping openskimap ids to the 52 existing slugs (name + distance ≤ 3 km) so days.resort_id / profiles.home_resort_id stay valid, new ids 'osm-<uuid>', resorts.meta.json with source version + licence. ResortRepository: gzip loader, 0.5° grid bucket index for nearest(), search sorted by distance to the current fix then alphabetically, curated first in pickers. Licence line 'OpenSkiMap.org · © OpenStreetMap contributors · ODbL' delivered as a constant for the settings package (licences_page owned by SETTINGS-RELEASE → add there after merge or via asks_lead). asks_lead: register the .gz asset in pubspec; add the licence line to licences_page if SETTINGS-RELEASE already merged.

**Owns:** `tools/data/**`, `app/assets/data/**`, `app/lib/data/resorts/**`, `app/test/data/resorts/**`

**Acceptance:**
- Import script runs offline from a cached geojson and produces ≥ 4000 resorts; all 52 legacy ids present with unchanged slugs and countries
- nearest() for 20 known coordinates (Kitzbühel, Whistler, Niseko, Aspen …) returns the expected resort; a point 30 km from any resort returns null
- Load time of the gz asset < 50 ms in a unit test; nearest() < 2 ms
- resorts.meta.json carries source date and ODbL licence; existing resort tests green

### SOC-COMPARE — Head-to-head-Vergleich (später)
*later · M · code* · depends on: SOC-RIDER, SOC-MODERATION

CompareSheet(userId) using rider_profile for the other side and local Achievements for self: six mirrored bars (Skitage, Abfahrten, Zeit, Distanz, Höhenmeter, Top-Speed), 'Du führst bei 4 von 6'. Entry point: a 'Vergleichen' button in RiderSheet (rider_sheet.dart edited after SOC-MODERATION merged, sequential via depends_on) and from DuelResultCard via a callback exposed to SOC-LIVE-DUEL later.

**Owns:** `app/lib/features/social/rider/compare_sheet.dart`, `app/lib/features/social/rider/compare_strings.dart`, `app/lib/features/social/rider/rider_sheet.dart`, `app/test/features/social/rider/compare_sheet_test.dart`

**Acceptance:**
- Widget test: six bars with correct proportions for a fixture; 'Du führst bei n von 6' correct
- RiderSheet shows 'Vergleichen' opening the sheet
- Analyzer clean

### SOC-SEASONS — Saisonwahl und All-time-Rangliste (später)
*later · S · code* · depends on: SOC-RANGLISTE, SOC-LIVE-DUEL, SOC-FRIENDS

Migration 0011_alltime.sql: leaderboard/country_board/my_rank/friends_board accept p_season_key = 'all' (sole redefiner after 0005/0007/0009 merged; sequential via depends_on). Client: LeaderboardPeriod.allTime and LeaderboardQuery.seasonKey override in social_models.dart, SeasonPickerSheet (this season, previous seasons present in days, all-time) behind the caption in social_screen.dart – both files edited only after SOC-RANGLISTE merged.

**Owns:** `supabase/migrations/0011_alltime.sql`, `app/lib/features/social/season/**`, `app/lib/features/social/social_models.dart`, `app/lib/features/social/social_screen.dart`, `app/test/features/social/season/**`

**Acceptance:**
- SQL test: p_season_key 'all' aggregates across seasons; '2025-26' still filters
- Picker lists seasons derived from local days; selecting 'Alle Zeiten' reloads the board with 'all'
- Analyzer clean, social tests green

### NOTIF-LOCAL — Lokale Social-Benachrichtigungen (Phase 1, ohne Push)
*later · S · code* · depends on: SOC-CHALLENGE, SOC-LIVE-DUEL

No nudges exist. Module app/lib/features/social/notify/: schedule local notifications from openChallengesProvider ('Wochen-Challenge endet morgen – noch 1.200 hm' the evening before ends_on when not done), 'Duell läuft – Lena führt mit 1.849 hm' once per day when the app is opened with an active duel and the user is not first, and 'Neue Wochen-Challenge' on Monday morning when a new challenge appears. Uses LocalNotificationService.scheduleIn; respects the existing notifications opt-in; cancels on leave/end. Push (APNs, device_tokens, Edge Function notify) stays a founder item.

**Owns:** `app/lib/features/social/notify/**`, `app/test/features/social/notify/**`

**Acceptance:**
- Unit tests with a fake notification service: challenge ending tomorrow and not done → one schedule; done → none; duplicate runs → no double schedule
- Notifications not scheduled when the user declined the opt-in
- Analyzer clean

### BE-TZ — Lokales Datum statt Europe/Vienna für Perioden (später, vor globalem Resort-Import)
*later · M · backend* · depends on: BE-01, SOC-SEASONS, SYNC-HARDENING, SOC-CHALLENGE, SOC-FRIENDS

All period buckets use 'Europe/Vienna'. Migration 0012_local_date.sql: days.local_date date and days.tz text (device fills them at finish; backfill from started_at at Europe/Vienna), leaderboard/country_board/my_rank/friends_board/challenge_board bucket by local_date; remote_day.dart writes the two fields (lib/data/sync owned by SYNC-HARDENING → sequential via depends_on). Ship together with or right after DATA-RESORTS.

**Owns:** `supabase/migrations/0012_local_date.sql`, `app/lib/data/sync/remote_day.dart`, `app/test/data/sync/remote_day_test.dart`

**Acceptance:**
- SQL test: a day finished 22:00 in America/Denver lands in the local week bucket, not the Vienna one
- remote_day_test: local_date and tz serialised; backfilled rows keep their previous buckets
- Analyzer clean


## Founder items
- Apple-Zugang: Apple ID des Teams 5GDU97KSQU in Xcode oder App-Store-Connect-API-Key; App-Record 'SlopeTrack' mit Bundle-ID de.torchtechnology.slopetrack anlegen, Sign in with Apple auf der App-ID aktivieren; vorher Markencheck 'SlopeTrack' (docs/NAMING.md), denn die Bundle-ID ist nach dem ersten Upload fix.
- Supabase › Auth › Apple: Client-ID auf de.torchtechnology.slopetrack setzen, Client-Secret neu erzeugen; Key-ID, Erstell- und Ablaufdatum in docs/BACKEND.md eintragen, Kalender-Erinnerung 2 Wochen vor Ablauf.
- Supabase-Projekt svzmmpzevmpodcelzvit prüfen (MCP/CLI zeigt aktuell auf das Torch-Projekt): `supabase link --project-ref svzmmpzevmpodcelzvit`, Migrationen 0001–0004 angewendet?, `select * from cron.job` (weekly-challenges), Edge Function delete-account deployed?; danach Migrationen 0005 ff. der Pakete einspielen und den Security Advisor laufen lassen.
- Entscheidung Team-Land: BE-01 setzt 'Mein Land' auf das im Onboarding gewählte Land (nicht auf das Land des Skigebiets). Bitte bestätigen, bevor die erste echte Skitag-Zeile geschrieben wird.
- Domain slopetrack.app registrieren, DNS auf GitHub Pages (CNAME), /.well-known/apple-app-site-association aus docs/ hosten – ohne Domain fallen Einladungslinks auf slopetrack:// zurück.
- Impressum in docs/imprint.html ausfüllen (Adresse, Rechtsform, USt-ID); Privacy-/Support-/Marketing-URLs und den App-Privacy-Fragebogen (Linked: Location, Fitness, Contact Info, Identifiers, User Content; kein Tracking) sowie den Altersfreigabe-Fragebogen (UGC: Anzeigenamen, Melden/Blockieren vorhanden) in App Store Connect eintragen.
- Geräte-QA auf echtem iPhone (docs/QA.md A–F): Hintergrund mit gesperrtem Display, Kill → Resume, Barometer, Akku/h, Auto-Ende im Auto; 60–90 s Review-Video (Tag starten, sperren, laufen, beenden, Tagesbilanz) aufnehmen und in den Review-Notes verlinken; Diagnosepaket und erste echte Tage als Test-Fixtures abgeben.
- Delete-Account Ende-zu-Ende live prüfen: anmelden → ein Tag syncen → Konto löschen → in Supabase auth.users/profiles/days/storage leer → erneut anmelden = neue UID.
- Legacy-Mapbox-Token und ggf. alten Anon-Key rotieren, bevor Repo oder App öffentlich werden.
- Push-Benachrichtigungen (Phase 2, später): APNs-Auth-Key im Developer-Account, aps-environment, device_tokens-Tabelle, Edge Function 'notify' – erst nach Store-Launch.
- Apple Watch: watchOS-SDK auf dem Mac installieren, damit das Watch-Target ins Xcode-Projekt kann (unverändert offen, später).

## Summary (DE)
Stand: Tracking, Sync-Grundlage, Gamification und Store-Texte sind da; der Wettbewerbskern ist es noch nicht.
Größter Fehler: Rangliste, Länder-Wertung und Duell sehen serverseitig nur die eigenen Tage – jeder Nutzer wäre allein auf Platz 1. Wird als Erstes gefixt (BE-01).
Fehlend im Sozialen: Freunde (Code, Liste, Freunde-Rangliste), tippbare Zeilen mit Rider-Profil, Live-Duell mit Ergebnis und Historie, echte Challenges mit Teilnehmern, Melden/Blockieren (Apple-Pflicht), Einladungslinks, eigenes Profil mit Avatar und Team-Wechsel.
Welle 1 (parallel, 5 Agenten): RPC-Sicherheit + Team-Land, Datenintegrität/Moderations-Schema, Freunde, Rider-Profil, Tagesbilanz/Gamification-Politur.
Welle 2: Rangliste-Kern (verdrahtet alles), Live-Duell, Challenges, Moderation, Profilseite, Deep Links, Sync-Härtung, Tage/Heute-Politur, Onboarding, Release-Paket (Privacy-Manifest, Impressum), Tracking-Guards/Tests, Share-Karten, Resort-Import; „später“: Vergleich, Saisonwahl, lokale Nudges, Zeitzonen.
Beim Lead bleiben: Tab-Wechsel verliert Zustand (Shell), MetricStrip/PB-Tile, kPrivacyUrl auf die GitHub-Pages-Adresse, Version 1.0.0, neue Pakete in pubspec.
Nur du: Apple-Zugang und App-Record, Supabase-Apple-Client-ID + Secret, Supabase-Projekt verknüpfen und Migrationen einspielen, Domain slopetrack.app, Impressum-Adresse, ASC-Fragebögen, Geräte-QA mit Review-Video, Delete-Account live testen, Token rotieren.
Eine Entscheidung offen: „Mein Land“ = gewähltes Team-Land (Empfehlung, wie im Onboarding versprochen) oder Land des Skigebiets? Muss vor dem ersten echten Skitag feststehen.
Risiko: Ohne Domain funktionieren Einladungslinks nur per slopetrack://-Schema; ohne Melden/Blockieren droht Review-Ablehnung (Guideline 1.2).
