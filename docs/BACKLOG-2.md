# Build backlog v2 (audit 2026-09-29)

Second audit after waves 1–2c (four auditors, skeptics, planner). Source JSON: `.context/plan/backlog-2026-09-29.json`. Status is kept at the top of `BACKLOG.md`.


## Wave 1

### SOC-LOOP — Rangliste → Rider → Freund: den Board-Loop schließen (addFriend, Avatare, Herausfordern-Erwartung)
*store · S · code* · depends on: —

Close the dead ends in the board→rider→action loop. (1) riderActionsProvider default gets `addFriend: (ctx, rider) => addFriendFromRider(ref, ctx, rider.userId)` (handler already exists in leaderboard_providers.dart:127, RPC add_friend_by_id live in 0013); toast friendRequestSent/nowFriends, invalidate friends providers. (2) Pass `avatarUrl:` to AvatarCircle in rider_sheet.dart:208, friends_sheet.dart:344, challenge_board_sheet.dart:171. (3) 'Herausfordern' in RiderSheet: caption under the button and toast 'Duell-Code an <Name> senden' so the share-sheet behaviour matches expectations (in-app invites come in SOC-DUEL-INVITES). (4) InviteStrings: drop the 'App laden' line while InviteLinks.appStoreUrlPlaceholder is id0000000000; keep link + scheme button; FriendsStrings.shareText routed through InviteStrings.friendShareText so friends have one text source. (5) Pending-request count exposed as `pendingRequestCountProvider` (int) in friends_providers.dart for SOC-RANGLISTE-2's badge. asks_lead: none.

**Owns:** `app/lib/features/social/rider/**`, `app/lib/features/social/friends/**`, `app/lib/features/social/moderation/**`, `app/lib/features/social/invite/**`, `app/lib/features/social/challenge/challenge_board_sheet.dart`, `app/test/features/social/rider/**`, `app/test/features/social/friends/**`, `app/test/features/social/moderation/**`, `app/test/features/social/invite/**`

**Acceptance:**
- Widget test with FakeRiderApi + FakeFriendsApi: RiderSheet for a stranger shows 'Freund hinzufügen'; tap → addFriend called with userId, toast friendRequestSent; for self/blocked the button is absent
- Golden/widget test: RiderSheet, friends _Identity row and ChallengeBoardRow render a network image when the fixture carries avatar_url, initials when null
- RiderSheet 'Herausfordern' shows the caption and the toast text DE/EN; share text still contains the duel code
- No share text in friends/** or invite/** contains 'id0000000000'; grep test in invite tests
- pendingRequestCountProvider returns 2 for a fake with two pending requests
- Analyzer clean, all existing tests green

### SOC-RANGLISTE-2 — Rangliste-Politur: Gebiet-Picker statt 4.929 Chips, Freunde-Button mit Badge, 'noch nicht gewertet', Rank-Share
*testflight1 · M · code* · depends on: —

Make the signed-in Rangliste usable and complete. (1) Replace the resort SocialChipRow (social_screen.dart:395-403 _resortOptions → all resorts) with one chip 'Gebiet: Kitzbühel ›' opening the existing ResortPicker sheet (features/days/resort_picker.dart, read-only import); default = home resort, else resort of the last local day, else hide the Gebiet scope; never `resorts.all.first`. (2) Header action 'Freunde' (glyph + pending badge from pendingRequestCountProvider, fallback to pendingRequestsProvider.length until SOC-LOOP merges) that calls FriendsSheet.show — reachable with ≥1 friend. (3) _PinnedOwnRow: render OwnRankStrip(rank: null → s.notRankedYet) when the board has loaded, the user is opted in and my_rank is null; hide only while loading/error. (4) Share glyph on OwnRankStrip building RankCardData(MyRank + scope name) via ShareService. (5) SocialChipRow: 16 pt edge fade (ShaderMask) so off-screen metric chips read as scrollable; max three selector rows. (6) Copy: signedOutLine → 'Melde dich an und fahr gegen {resort}.' (no second 'Platz 1'). asks_lead: none.

**Owns:** `app/lib/features/social/social_screen.dart`, `app/lib/features/social/social_controls.dart`, `app/lib/features/social/leaderboard_view.dart`, `app/lib/features/social/leaderboard_providers.dart`, `app/lib/features/social/social_strings.dart`, `app/lib/features/social/country_card.dart`, `app/test/features/social/*.dart`

**Acceptance:**
- Widget test: scope Gebiet with a 4.929-entry fake repository renders exactly one resort chip; tapping opens the ResortPicker; choosing a resort re-queries the board with that id
- Without home resort and without days the Gebiet scope chip is absent; with a last day in Ischgl the default is Ischgl
- Freunde header button visible with 1 friend on the board; badge shows '2' with two pending requests; tap opens FriendsSheet
- Opted-in user, board loaded, my_rank null → 'Du bist noch nicht gewertet' visible; while loading nothing
- OwnRankStrip share tap calls ShareService with a RankCardData (fake share in test)
- Metric chip row golden shows the edge fade; signed-out line contains no 'Platz 1'
- Analyzer clean, existing tests green

### TODAY-LIVE — Heute/Live: Duell-Stand beim Fahren, Saisonziel editierbar, Saison-Share, Bedingungen-Strip ohne Dublette
*store · M · code* · depends on: —

(1) live_view.dart: one caption line in _LiveBody from myDuelProvider + groupBoardProvider(duel.id) — 'Duell: Platz 2 · Lena +120 hm' (own place, delta to leader), refreshed by the existing 60 s poll; hidden without a duel. (2) Season goal: tap on the SAISON goal line opens a small sheet (hm stepper 5.000–100.000, optional 'kein Ziel') calling settings.setSeasonGoal; line hidden when unset. (3) Long-press/share glyph on the SeasonCard builds SeasonCardData(SeasonTotals) via ShareService. (4) Conditions strip: WeatherLine.format drops the resort name when the header caption shows it; layout as up to three value/overline pairs ('−4° / BERG', '12 cm / NEUSCHNEE', 'Sonnig / HEUTE') using Open-Meteo snowfall + snow_depth (free fields, add to data/weather client); hide the strip when no snow data and temperature > 10 °C. (5) Copy: emptyLine → 'Noch kein Skitag. Ein Tipp auf Tag starten genügt.' (no first person). asks_lead: EmptyState (lib/app/widgets/empty_state.dart) still defaults to assets/mascot/toni-still.jpg (Arc'teryx logo) — rebuild as the Rider pattern (SurfaceCard + Rider hero 132 + RiderLine + optional PrimaryButton), delete toni-* assets from pubspec; MetricStrip in lib/app/widgets/numbers.dart to accept (value, unit?, label) so the Saison footer reads '69 km/h / TOP-SPEED'.

**Owns:** `app/lib/features/today/**`, `app/lib/features/weather/**`, `app/lib/data/weather/**`, `app/test/features/today/**`, `app/test/features/weather/**`, `app/test/data/weather/**`

**Acceptance:**
- Widget test: LiveView with a fake duel board (3 members, own rank 2) shows 'Duell: Platz 2 · <leader> +<delta> hm'; without duel the line is absent
- Tap on the goal line opens the sheet; saving 30.000 updates settings.seasonGoalHm and the line reads 'ZIEL 30.000 HM'; 'kein Ziel' hides the line
- SeasonCard share calls ShareService with SeasonCardData (fake share)
- WeatherLine.format(r, w, includeResort: false) omits the name; strip golden shows value/overline pairs; strip hidden for 15 °C without snow data
- Open-Meteo parser test reads snowfall and snow_depth from a fixture JSON
- today_strings emptyLine contains no 'ich'; analyzer clean

### UX-POLISH-1 — Tagesbilanz/Tage/Medaillen-Kosmetik: REKORD-Karte, Route unter Plate, ZEIT-Summe, Höhenprofil-Achsen, Medaillen-Titel
*testflight1 · M · code* · depends on: —

All confirmed visual defects in summary/days/profile/achievements. (1) RecordCard: wrap the Row in Center (or Align centerLeft) so content is vertically centred in the 76 pt card; golden at 76 pt. (2) RoutePainter inset as EdgeInsets (top 34, right 34, bottom 110, left 34) so the route never runs under the date plate; glow centred on route bounds. (3) Move timeLegendSegments (remainder pause) into features/summary/time_legend.dart exported from summary.dart and use it in day_detail_screen.dart StackedTimeBar so 16+18+3 = total. (4) AltitudeProfile: 'm' suffix on the top y-label, x-axis in clock time (Fmt.timeOfDay at 3 ticks), 10 pt legend row 'Abfahrt · Lift · Signalverlust'. (5) Medal tiles: title at fixed 11.5 pt Inter 600 with ellipsis (no FittedBox); real names for numeric medals in medal_catalog.dart (Höhenmeter: Zehntausender/Fünfzigtausend/Hunderttausend/Halbe Million; Kilometer: Hundert/Fünfhundert/Tausend/Fünftausend; EN equivalents); suppress the threshold row when equal to the title; NewMedalsBanner caption = hint ('3 Skitage in Folge') instead of a bare '3'. (6) days_strings avgSkiSpeedShort 'Ø Speed' → 'Ø Tempo'. (7) Tage empty state: three 6 %-opacity skeleton rows behind the state block per DESIGN §5 (uses EmptyState as is; Rider swap comes from the lead). asks_lead: SurfaceCard `alignment` parameter (lib/app/theme/surfaces.dart) and MetricStrip triples (lib/app/widgets/numbers.dart) — day rows then '1.849 hm / HÖHENMETER', level card '42 km / SKI-KM'.

**Owns:** `app/lib/features/summary/**`, `app/lib/features/days/**`, `app/lib/features/profile/**`, `app/lib/features/achievements/**`, `app/test/features/summary/**`, `app/test/features/days/**`, `app/test/features/profile/**`, `app/test/features/achievements/**`, `docs/GAMIFICATION.md`

**Acceptance:**
- RecordCard golden at 76 pt: text vertically centred (no top-hugging)
- Route golden with the date plate: no route pixel inside the plate rect (test samples the painter bounds)
- DayDetail ZEIT legend segments sum exactly to the total for skiMs 16m10s / liftMs 18m40s / pauseMs 3m10s
- AltitudeProfile golden shows '2.000 m' top label, clock-time ticks and the legend row
- Medals sheet golden: all SERIE titles same size; no tile shows the same string as title and threshold; banner shows '3 Skitage in Folge'
- medal_catalog test: every def has a non-numeric titleDe/titleEn
- days_strings has 'Ø Tempo'; analyzer clean; existing goldens updated deliberately

### TF-PLIST — TestFlight-Blocker: Foto-Purpose-Strings, Privacy-Label Fotos, InfoPlist.strings, testflight.sh ohne Stale-Archive, Doku-Fixes
*testflight1 · S · code* · depends on: —

Everything that would bounce or embarrass the first upload, no Dart. (1) Info.plist: NSPhotoLibraryUsageDescription, NSCameraUsageDescription, NSMicrophoneUsageDescription (image_picker static scan, ITMS-90683); English base values. (2) de.lproj/en.lproj InfoPlist.strings for all usage keys so prompts are single-language. (3) PrivacyInfo.xcprivacy: NSPrivacyCollectedDataTypePhotosorVideos (linked, not tracking, App Functionality); APP-STORE.md nutrition table row; PRIVACY.md + privacy.html §2 sentence (profile photo optional, EU, public by URL, deleted with the account); qualify heart-rate/Watch sentence as 'planned'. (4) tools/testflight.sh: `rm -rf "$ARCHIVE"` before build, drop `|| true`, assert archive CFBundleVersion == $BUILD_NUMBER before export. (5) HANDOVER.md: bundle id de.torchtechnology.slopetrack, SLOPETRACK_* dart-defines, 'Known blockers' rewritten to 'create the ASC app record, then tools/testflight.sh --upload with the signed-in Xcode account (Apple Distribution 5GDU97KSQU present)'; GAPS.md #1 same; APP-STORE.md review note 'reviewed promptly' until BE-14 ships the report notification. asks_lead: none.

**Owns:** `app/ios/Runner/Info.plist`, `app/ios/Runner/PrivacyInfo.xcprivacy`, `app/ios/Runner/de.lproj/**`, `app/ios/Runner/en.lproj/**`, `tools/testflight.sh`, `docs/APP-STORE.md`, `docs/PRIVACY.md`, `docs/privacy.html`, `docs/HANDOVER.md`, `docs/GAPS.md`

**Acceptance:**
- plutil -lint passes; Info.plist contains the three new NS*UsageDescription keys with English base text
- InfoPlist.strings de/en contain every NS*UsageDescription key present in Info.plist (script check in the PR description)
- PrivacyInfo.xcprivacy lists NSPrivacyCollectedDataTypePhotosorVideos; APP-STORE.md table and PRIVACY.md/privacy.html mention Profilbild/profile photo
- tools/testflight.sh exits non-zero when flutter build ipa fails; no export of an archive whose CFBundleVersion differs from BUILD_NUMBER (dry-run with a fake archive)
- HANDOVER.md has no 'dropline'/'DROPLINE_' occurrences; GAPS #1 rewritten

### BE-14 — Migration 0014: Meldungen benachrichtigen, Block beidseitig, Grant-Hygiene, group_members-Policy
*store · M · backend* · depends on: —

Store-relevant backend fixes in one migration + tests. (1) reports: trigger via pg_net (or Database Webhook config documented) calling Edge Function `report-notify` that e-mails hello@torchtechnology.de with reporter/target/reason; limit max 10 reports/day per reporter and unique (reporter, target_user_id, day); SQL view for the founder 'open reports last 7 days' documented in BACKEND.md. (2) Block = invisible both ways: extend private.board (0005), group_board (0009), challenge_board (0010) to both directions; trigger on blocks insert deletes the friendships row of the pair; decision written in BACKEND.md. (3) revoke execute on is_opted_in(uuid) from authenticated; revoke select on challenges from anon. (4) drop policy 'members join self'; new insert policy only for the group creator (user_id = auth.uid() and groups.created_by = auth.uid()); new definer RPC create_duel(p_name, p_day, p_tz, p_resort_id) creating group + member in one transaction (client switch in SOC-DUEL-INVITES). (5) SQL tests 0014 after the 0005 pattern plus missing tests for 0007/0008/0013 block visibility. BACKEND.md: add 0009b and 0014 rows. asks_lead: none; migration numbers 0015–0019 are reserved for the wave-2 packages.

**Owns:** `supabase/migrations/0014_moderation_blocks.sql`, `supabase/functions/report-notify/**`, `supabase/tests/0014_moderation_blocks.sql`, `supabase/tests/0007_friends.sql`, `supabase/tests/0008_rider_profile.sql`, `supabase/tests/0013_rangliste.sql`, `docs/BACKEND.md`

**Acceptance:**
- SQL test: A blocks B → B no longer sees A in leaderboard, group_board and challenge_board; friendships row of the pair is gone; unblock does not resurrect it
- 11th report of a reporter on one day raises rate_limited; duplicate report same day raises
- authenticated call to is_opted_in → permission denied; anon select on challenges → permission denied
- Non-creator insert into group_members with a known group id → RLS violation; create_duel returns group id + code and the creator is a member; 4th member via join_group still max_members
- report-notify Deno test: payload → mail request built (fake fetch); missing secret → 500
- tools/supabase-test.sh green locally with all test files; BACKEND.md lists 0009b and 0014 with the dashboard check commands


## Wave 2

### SOC-TEASER — Rangliste ohne Login: öffentliche Top-10 + Duell/Challenge-Vorschau statt einer Sign-in-Karte
*store · M · code* · depends on: SOC-RANGLISTE-2, BE-14

Migration 0016_public_teaser.sql: `public_board_teaser(p_resort_id, p_season_key)` security definer, grant to anon + authenticated, returns rank/display_name/avatar_url/value (points) for the top 10 opted-in riders, no user_id, limited 1 call/s via statement timeout note. Client: new social/teaser/** (TeaserApi + Supabase + Fake, provider) and social_screen signed-out body: segment tabs + chips disabled, teaser rows (ghost BoardSkeleton when empty), locked DuelCard/ChallengeCard preview ('Duell mit bis zu 3 Freunden · Code teilen'), sign-in CTA pinned where the own-rank strip sits; create/join/opt-in stay gated. Tapping a teaser row shows a toast 'Anmelden, um Profile zu sehen'. asks_lead: none.

**Owns:** `supabase/migrations/0016_public_teaser.sql`, `supabase/tests/0016_public_teaser.sql`, `app/lib/features/social/teaser/**`, `app/lib/features/social/social_screen.dart`, `app/lib/features/social/social_strings.dart`, `app/lib/features/social/social_api.dart`, `app/test/features/social/teaser/**`, `app/test/features/social/social_screen_test.dart`

**Acceptance:**
- SQL test: anon call returns ≤10 rows, only opted-in riders, no user_id column; non-opted-in rider absent
- Widget test signed out with FakeTeaserApi: 10 rows, locked duel and challenge previews, CTA present, chips non-interactive
- Empty teaser → skeleton rows + CTA, no 'Platz 1' repetition
- Signed-in path unchanged (existing social tests green)

### SOC-DUEL-INVITES — Duell-Einladungen in-app (duel_invites), create_duel-RPC im Client, ein Share-Text
*store · M · code* · depends on: SOC-LOOP, BE-14

Migration 0017_duel_invites.sql: table duel_invites(id, from_user, to_user, group_id, day, status pending|accepted|declined, created_at) with own-row RLS, RPCs invite_to_duel(p_user_id, p_group_id), respond_duel_invite(p_id, p_accept) (accept = join_group path incl. max_members/duel_expired), my_duel_invites(); grants authenticated only. Client duel/**: RiderSheet 'Herausfordern' now creates/reuses today's duel via create_duel RPC (BE-14) and calls invite_to_duel, then still offers 'Code teilen'; DuelCard shows 'Duell-Einladung von Lena' with Annehmen/Ablehnen fed by the existing 60 s poll; DuelCardShare.text routed through InviteStrings.duelShareText (single source, App Store line only when kAppStoreUrl set). asks_lead: none.

**Owns:** `supabase/migrations/0017_duel_invites.sql`, `supabase/tests/0017_duel_invites.sql`, `app/lib/features/social/duel/**`, `app/lib/features/social/duel_card.dart`, `app/lib/features/social/rider/rider_sheet.dart`, `app/test/features/social/duel/**`

**Acceptance:**
- SQL test: A invites B → B's my_duel_invites lists it; B accepts → member of the group; C cannot read A→B invite; accept on a 4th member → max_members
- Widget test: pending invite renders the card with sender name; Annehmen calls respond and refreshes myDuel; Ablehnen removes the card
- RiderSheet 'Herausfordern' calls create_duel + invite_to_duel (fakes) and shows the toast 'Einladung an Lena gesendet'
- DuelCardShare.text equals InviteStrings.duelShareText output; no 'id0000000000' in any share text

### SOC-NAME-FALLBACK — 'Skifahrer'-Fallback lokalisieren (DE/EN) statt fünf Literale in den Parsern
*store · S · code* · depends on: SOC-LOOP, SOC-RANGLISTE-2

Keep displayName nullable in RiderProfile, Friend, ChallengeBoardEntry, LeaderboardRow/GroupBoardRow and Profile; add `riderName(BuildContext, String?)` in social/rider_name.dart resolving 'Skifahrer'/'Skier' via Localizations.localeOf; all AvatarCircle/name call sites use it (leaderboard_view, duel cards, rider_sheet, friends_sheet, challenge_board_sheet, profile page). Extend the 'no German literal in features/**' test to cover *_models.dart and profile_service.dart. asks_lead: none.

**Owns:** `app/lib/features/social/rider_name.dart`, `app/lib/features/social/social_models.dart`, `app/lib/features/social/rider/rider_models.dart`, `app/lib/features/social/friends/friends_models.dart`, `app/lib/features/social/challenge/challenge_models.dart`, `app/lib/features/account/profile_service.dart`, `app/test/features/social/rider_name_test.dart`, `app/test/features/no_literals_test.dart`

**Acceptance:**
- grep 'Skifahrer' over app/lib/features/**/*_models.dart and profile_service.dart → 0 hits
- Widget test: null display_name renders 'Skifahrer' under de and 'Skier' under en in a leaderboard row and the rider sheet
- Literal-guard test fails when a German literal is added to a models file

### SETTINGS-ACCOUNT-2 — Konto/Einstellungen: Blockierte Nutzer, eine Sign-in-Fläche, Einheiten-Zeile, Konto-Benennung
*testflight1 · M · code* · depends on: SOC-LOOP, TODAY-LIVE

(1) Settings › Konto › 'Blockierte Nutzer': list from blockedIdsProvider + rider_profile names (fallback riderName), unblock per row via moderation api; empty line 'Niemand blockiert.'. (2) Signed-out ProfilePage filled: three benefit rows (Backup · Ranglisten & Duelle · Freunde), device-computed level card, Apple button, 'Ohne Konto weiter' secondary; AccountSheet retired from the app path (body kept for tests or deleted with tests). (3) Remove the dead 'Einheiten — Folgt der Sprache' row until a units setting exists. (4) Signed-out Konto row title 'Konto' with caption 'Anmelden – Sichern, Ranglisten, Freunde' so row and page match. (5) Season goal row 'Saisonziel' on the profile page reusing the TODAY-LIVE sheet. asks_lead: router.social() (lib/app/router.dart) should open ProfilePage instead of AccountSheet.show.

**Owns:** `app/lib/features/settings/**`, `app/lib/features/account/** (except profile_service.dart)`, `app/test/features/settings/**`, `app/test/features/account/**`

**Acceptance:**
- Widget test with a fake moderation api: two blocked ids render two rows with names; unblock removes the row and calls the api
- Signed-out ProfilePage golden: benefit rows + level card + Apple button + 'Ohne Konto weiter'; no empty lower half
- settings_sheet has no units row; Konto row shows 'Konto' + caption when signed out
- Saisonziel row opens the goal sheet and persists 25.000

### SYNC-2 — Sync/Auth-Härtung: Konto-Löschung ehrlich, Profil-Reparatur, throttled statt offline, Zwei-Geräte-Merge
*store · M · code* · depends on: —

(1) deleteAccount: remove the partial client fallback; on Edge Function failure show 'Löschen hat nicht geklappt, bitte später erneut', keep the session, return false (no 'Konto gelöscht' toast). (2) Profile repair: on app start/sync tick, if a user exists and profileProvider is null → profiles.upsert({id, display_name: cached Apple name or fallback}); cache the Apple full name in SharedPreferences until the insert succeeds. (3) SyncState gains `throttled` for P0005 (UI text 'Sync pausiert, geht gleich weiter'); send track_path inside the day upsert when the track is already uploaded to halve writes. (4) device_updated_at = local row.updatedAt (last-edit-wins); pull as keyset paging (updated_at, id); markSynced removes only outbox rows with id ≤ the pushed one; softDeleteFromRemote deletes points/segments. asks_lead: none.

**Owns:** `app/lib/data/** (except resorts/** and weather/**)`, `app/test/data/** (except resorts/** and weather/**)`

**Acceptance:**
- Unit test: Edge Function 500 → deleteAccount returns false, session intact, no local wipe
- Test: user without profile row → repair upsert called once with the cached name; success clears the cache
- P0005 → SyncState.throttled; retry after the window; no 'offline' label
- merge_test: older offline edit loses against a newer online edit; keyset paging fetches all rows when one changes mid-page; tombstone removes points
- Existing sync tests green; analyzer clean

### BE-15 — Migration 0015: Rate-Limit-Fix für track_path, live_days-Grenzen, join_group-Zeitzone, SQL-Tests 0006/0010, Deno-Test delete-account
*store · M · backend* · depends on: BE-14

(1) days_guard: early `return new` on UPDATE when new.device_updated_at = old.device_updated_at (track_path-only updates do not count, days_touch not bumped). (2) live_days: check day between current_date - 1 and current_date + 1; trigger raises rate_limited on UPDATE within 20 s; day_write_counters cleanup in the existing 05:00 cron. (3) join_group compares g.day against (now() at time zone g.tz)::date. (4) Tests: 0006_integrity.sql (constraints, too_many_days, rate_limited, reports, avatars policies), 0010_challenges.sql (join after ends_on, challenge_board, history), 0015. (5) supabase/functions/delete-account/index_test.ts with fake storage (paging > 1000 objects, remove error → 500). (6) .github/workflows/supabase.yml: supabase start + tools/supabase-test.sh on PRs touching supabase/**. asks_lead: none.

**Owns:** `supabase/migrations/0015_limits_tz.sql`, `supabase/tests/0015_limits_tz.sql`, `supabase/tests/0006_integrity.sql`, `supabase/tests/0010_challenges.sql`, `supabase/functions/delete-account/index_test.ts`, `.github/workflows/supabase.yml`

**Acceptance:**
- SQL test: 150 day upserts + 150 track_path updates in one hour succeed (only 150 counted)
- live_days insert with day = current_date - 5 fails; two updates within 20 s → rate_limited
- join_group for a group in America/Denver at 23:30 Vienna time on day+1 is still accepted
- All test files green via tools/supabase-test.sh; Deno test green; workflow runs on a PR

### DATA-RESORTS-2 — Skigebiete entdoppeln: Aliase, Verbund vor Teilgebiet, Höhen nachziehen, Server-Alias-Tabelle
*store · M · code* · depends on: BE-15

Importer tools/data/import_resorts.py: (1) child entries whose centre lies inside a larger entry's radius and share a name token become `aliases` of the parent (child removed); (2) exact name+country duplicates merged (larger radius wins); (3) missing base/summit altitudes filled from Open-Elevation for the centre or marked null and hidden in UI. resort_repository.nearest(): on overlap prefer the larger radius. Migration 0018_resort_aliases.sql: resort_aliases(alias_id → canonical_id) + backfill days.resort_id + leaderboard RPCs resolve through canonical. Document the counts in docs/BACKEND.md? no — in tools/data/README.md. asks_lead: none.

**Owns:** `tools/data/**`, `app/assets/data/resorts.json`, `app/lib/data/resorts/**`, `app/test/data/resorts/**`, `supabase/migrations/0018_resort_aliases.sql`, `supabase/tests/0018_resort_aliases.sql`

**Acceptance:**
- Unit test: St. Anton, Lech, Stuben coordinates → one resort id; Damüls three variants → one
- resorts.json: 0 exact name+country duplicates; count of entries without altitude reported in the PR and hidden in the picker
- SQL test: a day with an alias resort_id counts on the canonical board after backfill
- Home-resort picker shows no duplicates for 'Arlberg' (widget test with the real json)

### UX-ONBOARDING-A11Y — Onboarding P1-Layout, Reduce-Motion, Dynamic-Type-1.3-Tests, Kontrast-Guard
*testflight1 · M · code* · depends on: UX-POLISH-1, TODAY-LIVE

(1) Onboarding P1: Column with Rider at 160–200 pt overlapping the hook card top by 24 pt, centred via LayoutBuilder between pager and dock; P2/P3 keep the ListView. (2) RouteHook/HookPage: when MediaQuery.disableAnimationsOf → value 1, no count-up. (3) Tests: app/test/app/text_scale_test.dart pumps HeuteScreen, TageScreen, TagesbilanzScreen, SettingsSheet at TextScaler.linear(1.3) asserting no RenderFlex overflow; app/test/app/theme/contrast_test.dart computing WCAG ratios for AppColors dark/light/glare (primary/secondary ≥ 4.5 on bg/surface/surfaceRaised, accent ≥ 4.5, onAccent ≥ 4.5, tertiary ≥ 3.0). (4) Onboarding icons swapped to Glyph where a glyph exists. asks_lead: Motion.reduced(context) token in lib/app/theme/tokens.dart; RecordingPill/tab pulse static and Pressable Duration.zero when reduced; Semantics on AppSheet close (MaterialLocalizations.closeButtonLabel), PbTile/StatTile, StackedTimeBar, SpeedBar, showToast liveRegion, HoldToConfirmButton hint 'Halten'; Glyph enum + nine strokes (check, search, person, bell, lock, battery, walk, pause, satellite) with an Icons.-count guard test.

**Owns:** `app/lib/features/onboarding/**`, `app/test/features/onboarding/**`, `app/test/app/text_scale_test.dart`, `app/test/app/theme/**`

**Acceptance:**
- Onboarding P1 golden at 393×852: no dead band > 60 pt between card and dock; Rider ≥ 160 pt
- With disableAnimations true the route hook is fully drawn on first frame and the count-up shows the final value
- text_scale_test green at 1.3× for the four screens (fails today if an overflow exists → fix in owned files or report to lead)
- contrast_test green; any failing token listed in the PR for the lead

### DEMO-SHOTS — Demo-Fixture für angemeldete Social-States + Store-Screenshots neu (Rangliste mit Podium, Duell live)
*store · M · design* · depends on: SOC-RANGLISTE-2, SOC-LOOP, SOC-TEASER

New app/lib/features/social/demo/demo_social.dart: seeded FakeSocialApi/FakeFriendsApi/FakeDuelApi/FakeChallengeApi/FakeRiderApi (podium of 3, own rank 7, live duel 2/3, open challenge, 2 friends, 1 pending request) exposed as `demoSocialOverrides()` (list of provider overrides). tools/shots.sh: new targets rangliste-signed-in, duel-live, challenge-board, rider, profile-signed-in, in dark and light; re-shoot the 6.9" set with 2 = Rangliste podium + Freunde chip, 3 = Tagesduell live, run tools/store_shots.py; keep the founder's device screenshots as cross-check. asks_lead: demo.dart (lib/app/demo.dart) must apply demoSocialOverrides() when SLOPETRACK_DEMO=1 and a fake user session.

**Owns:** `app/lib/features/social/demo/**`, `app/test/features/social/demo/**`, `tools/shots.sh`, `tools/store_shots.py`, `design/store/**`

**Acceptance:**
- Widget test: SocialScreen with demoSocialOverrides() renders podium, own-rank strip 'Platz 7', duel card with 2/3 live rows and the challenge card
- tools/shots.sh produces the five new PNGs in dark and light without manual steps (documented command)
- design/store/2-* and 3-* show a board with rows and a live duel; no 'Punkte = hm ÷ 10' caption remains

### QA-DEVICE-1 — Erste Geräte-Session: QA.md A/B/G, Sign in with Apple, Screenshots angemeldet, Heute-Reshoot
*testflight1 · M · device-qa* · depends on: TF-PLIST

On the founder's iPhone with TestFlight build 1: (A) fresh install + onboarding prompts; (B) 60 min locked in a pocket, swipe-kill at 5 and 40 min, Diagnose bundle, battery %/h; Sign in with Apple → profiles row with friend_code visible in the dashboard; one synced day; (G) delete account end to end. Screenshots: Rangliste (Freunde/Gebiet/Alle), duel live, challenge board, rider sheet, profile signed in, Heute (verify the HM overline replaced 'HÖHENME…'), one at the largest non-accessibility text size, a 15-minute VoiceOver pass Heute → Tag starten → Tag beenden → Rangliste. Record ticks with device/iOS version in QA.md and put shots under .context/shots/device/. asks_lead: none.

**Owns:** `docs/QA.md`, `.context/shots/device/**`

**Acceptance:**
- QA.md sections A, B, G ticked or failed with a note, device + iOS version + battery %/h recorded
- Supabase dashboard shows the profiles row after sign-in and 0 rows after delete (screenshot in the PR)
- Signed-in screenshot set present; heute.png shows 'HM' overline
- VoiceOver findings listed as a short table for the lead

### SOC-SEASONS-COMPARE — Saisonwahl/All-time in der Rangliste und Kopf-an-Kopf-Vergleich
*later · M · code* · depends on: SOC-DUEL-INVITES, BE-15

Migration 0019_seasons_compare.sql: private.season_match accepts 'all'; leaderboard/friends_board/country_board/my_rank accept p_season_key 'all'; RPC compare_riders(p_user_id, p_season_key) returning six mirrored values for caller and target. Client: social/seasons/** SeasonPickerSheet behind the board caption (seasons derived from local days + 'Gesamt'); social/compare/** CompareSheet with six mirrored bars and 'Du führst bei n von 6'; 'Vergleichen' button in RiderSheet and DuelResultCard. asks_lead: none.

**Owns:** `supabase/migrations/0019_seasons_compare.sql`, `supabase/tests/0019_seasons_compare.sql`, `app/lib/features/social/seasons/**`, `app/lib/features/social/compare/**`, `app/test/features/social/seasons/**`, `app/test/features/social/compare/**`

**Acceptance:**
- SQL test: p_season_key 'all' ranks across two seasons; compare_riders respects the rider_profile visibility rules
- Widget test: picker lists 2025/26, 2026/27, Gesamt; choosing re-queries the board
- CompareSheet golden with six bars and the lead line; button present in RiderSheet and DuelResultCard

### NOTIF-LOCAL — Lokale Social-Hinweise: Challenge endet morgen, Duell läuft, neue Wochen-Challenge, Freundschaftsanfrage
*later · M · code* · depends on: SOC-DUEL-INVITES

features/social/notifications/**: SocialNudges service run on app resume and after the 60 s poll, behind the existing notification opt-in: (1) challenge ends tomorrow and the rider is not first, (2) duel running and not first on app open, (3) new weekly challenge on Monday, (4) pending friend request on resume; each at most once per day (local store). asks_lead: NotificationIds 7–10 in platform/notification_service.dart and a hook in the shell resume path.

**Owns:** `app/lib/features/social/notifications/**`, `app/test/features/social/notifications/**`

**Acceptance:**
- Unit tests with a fake notification service and fake clock: each of the four rules fires once per day and not when opted out
- No notification when the rider is first or has no duel/challenge

### LIVE-ACTIVITY — Live Activity / Sperrbildschirm: hm · Abfahrten · Top-Speed · Zeit während der Aufzeichnung
*later · L · code* · depends on: QA-DEVICE-1

Small ActivityKit extension app/ios/SlopeTrackLiveActivity (SwiftUI lock-screen + Dynamic Island compact), method channel from RecordingController (start/update every 30 s or on run end/stop); no new dependency if the channel suffices, else live_activities package. asks_lead: project.pbxproj target + entitlement, pubspec if a package is used.

**Owns:** `app/ios/SlopeTrackLiveActivity/**`, `app/lib/features/recording/live_activity/**`, `app/test/features/recording/live_activity/**`

**Acceptance:**
- Unit test: bridge sends start on day start, update on each run end, end on stop; no calls when the activity is unsupported
- Device check by the founder: lock screen shows the four numbers during a day (QA.md row)

### LATER-IMPORT-UNITS — GPX-Import, Saisonrückblick, Einheiten metrisch/imperial
*later · L · code* · depends on: SETTINGS-ACCOUNT-2, UX-POLISH-1

features/import/**: GPX 1.1 importer through the engine replay path (raw fixes → segmenter) with a 'Importieren' row; features/share season recap screen at season end reusing SeasonShareCard; units setting metric/imperial. asks_lead: Settings.units in core/settings.dart and Fmt unit threading (lib/core), settings row (after SETTINGS-ACCOUNT-2).

**Owns:** `app/lib/features/import/**`, `app/lib/features/share/**`, `app/test/features/import/**`, `app/test/features/share/**`

**Acceptance:**
- Import of a Slopes GPX fixture yields a day with runs, hm and distance within 5 % of the file's own summary
- Recap screen golden; share builds SeasonCardData
- Units toggle changes '1.849 hm' to '6,066 ft' in the day card (once Fmt supports it)


## Founder items
- App Store Connect: App-Eintrag 'SlopeTrack – Ski-Tracker & Duelle' mit Bundle-ID de.torchtechnology.slopetrack anlegen (Apple-Distribution-Zertifikat 5GDU97KSQU ist auf diesem Mac bereits vorhanden), dann tools/testflight.sh --upload; Apple-ID der App danach an Code geben für kAppStoreUrl und docs/d, docs/f.
- Supabase › Auth › Apple im Ski-Projekt (svzmmpzevmpodcelzvit): Client-ID = Bundle-ID, Team 5GDU97KSQU, Key-ID, frisches Secret; Key-ID und Ablaufdatum in docs/BACKEND.md eintragen, Kalender-Erinnerung 2 Wochen vor Ablauf. Ohne das gibt es keine Rangliste, kein Duell, keine Freunde.
- Impressum docs/imprint.html ausfüllen (Anschrift, Rechtsform, USt-ID), gelbe Platzhalter-Box entfernen, pushen – der Link steckt bereits in der App (§ 5 DDG, Store-Blocker).
- Live-Projekt abgleichen: 0009b und 0014/0015 per Management API einspielen, 'select jobname from cron.job' und 'supabase functions list' prüfen, supabase_migrations.schema_migrations einmalig reparieren (0001 ist nicht idempotent, 'db push' würde scheitern), MCP-Verbindung vom Torch- auf das Ski-Projekt umstellen.
- Erste Geräte-Session mit TestFlight-Build 1 nach dem Plan QA-DEVICE-1 (Onboarding, 60 min gesperrt in der Tasche, Swipe-Kill, Sign in with Apple, Konto löschen, angemeldete Screenshots). Tester bitten, 'Absturzdaten teilen' in TestFlight zu aktivieren.
- Domain slopetrack.app registrieren, CNAME auf GitHub Pages (docs/CNAME), damit die AASA an der Domain-Wurzel liegt; danach customDomainLive = true (Code). Universal Links funktionieren bis dahin nicht, der slopetrack://-Button auf der Fallback-Seite schon.
- Entscheidungen: Kartenanbieter (MapTiler/Mapbox Free-Tier statt OpenTopoMap ohne Key) vor dem Store-Build; Supabase-Plan mit Backups/PITR oder wöchentlicher db dump vor dem ersten echten Nutzer-Tag; Crash-SDK ja/nein (Privacy-Manifest-Folgen); Rohspur-Backup-Retention (Free-Tier 1 GB, Bundle-Größe eines 6-h-Tags einmal messen).
- watchOS-Plattform in Xcode installieren, dann ios/SlopeTrackWatch/tools/add_watch_target.py für Build 2 (Watch-Quellen sind fertig, Target fehlt).
- App-Icon: aktuell ein Chevron identisch mit dem Heute-Tab-Glyph – Entscheidung, ob ein eigener Icon-Auftrag (Gold-Akzent aus dem Maskottchen) vor dem Store-Launch kommt.

## Summary (DE)
Was fehlt (Top 5): 1) Der Board-Loop ist tot – 'Freund hinzufügen' aus dem Rider-Profil ist nicht verdrahtet, Avatare fehlen in drei Listen, Freunde-Sheet ist mit ≥1 Freund unerreichbar. 2) Rangliste 'Gebiet' zeigt 4.929 Chips, ohne Login nur eine Sign-in-Karte. 3) Erster Upload würde abgelehnt: Foto-Purpose-Strings fehlen (image_picker), Fotos nicht im Privacy-Label. 4) Meldungen landen unbeobachtet in reports; Block wirkt nur einseitig. 5) Nichts lief je auf einem echten iPhone, keine angemeldeten Screenshots.
Weitere Lücken: Empty States zeigen noch das Toni-Foto mit Arc'teryx-Logo (Lead-Aufgabe), REKORD-Karte/Route/ZEIT-Summe/Medaillen-Titel, Konto-Löschung meldet Erfolg bei Teil-Löschung, Duell-Herausforderung ist nur ein Share-Sheet, Saisonziel nicht editierbar.
Vollständig geprüft und in Ordnung: Live-Duell, Challenges, Freundescode, Moderation, Sync-Retry, Deep-Link-Parser, Share-Karten (Medaille/Level/Duell), Datenschutz-Manifest, 0005/0009 live verifiziert.
Welle 1 (parallel, 6 Pakete): SOC-LOOP, SOC-RANGLISTE-2, TODAY-LIVE, UX-POLISH-1, TF-PLIST, BE-14.
Welle 2: Teaser ohne Login, Duell-Einladungen in-app, Name-Fallback DE/EN, Konto/Einstellungen, Sync-Härtung, BE-15, Skigebiete entdoppeln, Onboarding/A11y-Tests, Demo-Screenshots, Geräte-QA; später Saisons/Vergleich, lokale Hinweise, Live Activity, GPX/Imperial.
Nur du: ASC-App-Eintrag + Upload, Apple-Provider in Supabase (Secret-Ablauf!), Impressum ausfüllen, Live-Migrationen abgleichen, Geräte-Session, Domain slopetrack.app, Entscheidungen Karten/Backup/Crash-SDK.
Warnung: Ohne den Apple-Provider in Supabase gibt es für Tester keinen einzigen Social-Pfad; ohne Backup-Plan ist ein Fehler bei manuellen Migrationen nicht rückgängig zu machen.
