-- SQL acceptance test for supabase/migrations/0010_challenges.sql (SOC-CHALLENGE).
--
-- One DO block that always ends in RAISE EXCEPTION, so everything it inserts is
-- rolled back — safe against the live project. On success the message starts
-- with CHALLENGE_TEST_OK; otherwise the failed assertion is the message.
-- (Handlers list SQLSTATEs explicitly: the management API's query endpoint does
-- not honour `when others`.)
--
-- Run: app/test/features/social/challenge/challenge_rpc_test.sh
--
-- Covers: A (not a participant, days inside the window) does not count; B
-- (participant, two days inside + one outside + one suspicious) is done; C
-- (participant, no days) has value 0 → participants = 2, done_count = 1;
-- blocks hide a participant for the blocker only; a client cannot write a
-- value anywhere (no column, joined_at not insertable, RLS for other users,
-- no joining an ended challenge); my_challenge_history lists the ended
-- challenge with final value and rank; grants (anon nothing, authenticated
-- board + history); titles in both languages.
do $t$
declare
  a uuid := gen_random_uuid(); -- opted-in rider with days, NOT a participant
  b uuid := gen_random_uuid(); -- participant, reaches the target
  c uuid := gen_random_uuid(); -- participant, no days
  ch uuid;                     -- running challenge
  old_ch uuid;                 -- ended challenge
  r record;
  n int;
  today date := (now() at time zone 'Europe/Vienna')::date;
  claims_b text;
  claims_c text;
begin
  -- Workaround (rolled back with the block): 0007's profiles_set_friend_code
  -- trigger runs with search_path = public but gen_random_bytes lives in
  -- extensions, so profile inserts fail on the live project without this shim.
  if to_regprocedure('public.gen_random_bytes(integer)') is null and to_regprocedure('extensions.gen_random_bytes(integer)') is not null then
    create function public.gen_random_bytes(integer) returns bytea language sql as 'select extensions.gen_random_bytes($1)';
  end if;

  insert into auth.users (id, instance_id, aud, role, email)
    values (a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@challenge.test'),
           (b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@challenge.test'),
           (c, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c@challenge.test');
  insert into public.profiles (id, display_name, share_leaderboards, country_code)
    values (a, 'Anna', true, 'AT'), (b, 'Ben', false, 'DE'), (c, 'Cem', true, 'CH');

  -- Challenges: one running this week (target 5.000 hm), one ended two weeks ago.
  insert into public.challenges (title, title_de, title_en, metric, target, starts_on, ends_on)
    values ('Test', private.challenge_title('drop_m', 5000, 'de'), private.challenge_title('drop_m', 5000, 'en'), 'drop_m', 5000, today - 3, today + 3)
    returning id into ch;
  insert into public.challenges (title, title_de, title_en, metric, target, starts_on, ends_on)
    values ('Test alt', private.challenge_title('run_count', 20, 'de'), private.challenge_title('run_count', 20, 'en'), 'run_count', 20, today - 20, today - 14)
    returning id into old_ch;

  if private.challenge_title('drop_m', 5000, 'de') <> 'Wochen-Challenge: 5.000 Höhenmeter' then raise exception 'FAIL: de title %', private.challenge_title('drop_m', 5000, 'de'); end if;
  if private.challenge_title('drop_m', 5000, 'en') <> 'Weekly challenge: 5,000 m vertical' then raise exception 'FAIL: en title %', private.challenge_title('drop_m', 5000, 'en'); end if;
  if private.challenge_title('day_count', 3, 'en') <> 'Weekly challenge: 3 ski days' then raise exception 'FAIL: en days title'; end if;

  -- Participants: B and C (as postgres — the RLS path is tested below).
  insert into public.challenge_participants (challenge_id, user_id) values (ch, b), (ch, c), (old_ch, b);

  -- Days. Window days start at 10:00 Vienna so the calendar day is unambiguous.
  insert into public.days (id, user_id, started_at, ended_at, resort_id, season_key, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at, country_code)
  values
    -- A: inside the window, but not a participant
    (gen_random_uuid(), a, ((today - 1)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 1)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'kitzbuehel', '2026/27', 10, 9000, 30000, 20, 3600000, 18000000, now(), 'AT'),
    -- B: two inside (3.000 + 2.500 = 5.500 ≥ 5.000), one before the window, one suspicious inside
    (gen_random_uuid(), b, ((today - 2)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 2)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'kitzbuehel', '2026/27', 12, 3000, 30000, 20, 3600000, 18000000, now(), 'AT'),
    (gen_random_uuid(), b, ((today - 1)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 1)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'ischgl',     '2026/27', 10, 2500, 25000, 22, 3600000, 18000000, now(), 'AT'),
    (gen_random_uuid(), b, ((today - 5)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 5)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'ischgl',     '2026/27', 10, 4000, 25000, 22, 3600000, 18000000, now(), 'AT'),
    (gen_random_uuid(), b, ((today - 0)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 0)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'ischgl',     '2026/27', 90, 20000, 50000, 50, 3600000, 18000000, now(), 'AT'),
    -- B inside the ended challenge: 14 runs of 20
    (gen_random_uuid(), b, ((today - 16)::timestamp + interval '10 hours') at time zone 'Europe/Vienna', ((today - 16)::timestamp + interval '15 hours') at time zone 'Europe/Vienna', 'ischgl',   '2026/27', 14, 2000, 20000, 20, 3600000, 18000000, now(), 'AT');
  -- days.suspicious is a generated column (0001/0006): 20.000 hm / 90 runs / 50 m/s trips it.
  if not exists (select 1 from public.days where user_id = b and drop_m = 20000 and suspicious) then raise exception 'FAIL: fixture day not flagged suspicious'; end if;
  if exists (select 1 from public.days where user_id = b and drop_m = 3000 and suspicious) then raise exception 'FAIL: plausible fixture day flagged suspicious'; end if;

  claims_b := json_build_object('sub', b, 'role', 'authenticated')::text;
  claims_c := json_build_object('sub', c, 'role', 'authenticated')::text;

  -- 1. signed out → 42501
  perform set_config('request.jwt.claims', '', true);
  begin
    perform * from public.challenge_board(ch);
    raise exception 'FAIL: signed-out board did not raise';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.my_challenge_history(10);
    raise exception 'FAIL: signed-out history did not raise';
  exception when insufficient_privilege then null;
  end;

  -- 2. board as C: two participants, one done, correct values, A absent
  perform set_config('request.jwt.claims', claims_c, true);
  select count(*) into n from public.challenge_board(ch);
  if n <> 2 then raise exception 'FAIL: board rows % (expected 2)', n; end if;
  select * into r from public.challenge_board(ch) x where x.user_id = b;
  if r.rank <> 1 or r.value <> 5500 or not r.done then raise exception 'FAIL: B row rank % value % done %', r.rank, r.value, r.done; end if;
  if r.participants <> 2 or r.done_count <> 1 then raise exception 'FAIL: participants % done_count %', r.participants, r.done_count; end if;
  if r.display_name <> 'Ben' or r.country_code <> 'DE' then raise exception 'FAIL: B identity %', r; end if;
  select * into r from public.challenge_board(ch) x where x.user_id = c;
  if r.rank <> 2 or r.value <> 0 or r.done then raise exception 'FAIL: C row rank % value % done %', r.rank, r.value, r.done; end if;
  select count(*) into n from public.challenge_board(ch) x where x.user_id = a;
  if n <> 0 then raise exception 'FAIL: non-participant A on the board'; end if;

  -- 3. unknown challenge → P0002
  begin
    perform * from public.challenge_board(gen_random_uuid());
    raise exception 'FAIL: unknown challenge did not raise';
  exception when sqlstate 'P0002' then null;
  end;

  -- 4. blocks: C blocks B → C's board has 1 participant; B's board still 2
  insert into public.blocks (user_id, blocked_id) values (c, b);
  select count(*) into n from public.challenge_board(ch);
  if n <> 1 then raise exception 'FAIL: blocked rider still on the blocker''s board (% rows)', n; end if;
  select * into r from public.challenge_board(ch) limit 1;
  if r.participants <> 1 or r.done_count <> 0 then raise exception 'FAIL: counts after block % / %', r.participants, r.done_count; end if;
  perform set_config('request.jwt.claims', claims_b, true);
  select count(*) into n from public.challenge_board(ch);
  if n <> 2 then raise exception 'FAIL: block leaked to the blocked rider''s view (% rows)', n; end if;
  delete from public.blocks where user_id = c and blocked_id = b;

  -- 5. history as B: the ended challenge with 14 runs, rank 1 of 1, not done; the running one absent
  select count(*) into n from public.my_challenge_history(10);
  if n <> 1 then raise exception 'FAIL: history rows % (expected 1)', n; end if;
  select * into r from public.my_challenge_history(10);
  if r.challenge_id <> old_ch then raise exception 'FAIL: history lists the wrong challenge'; end if;
  if r.value <> 14 or r.done or r.rank <> 1 or r.participants <> 1 or r.done_count <> 0 then raise exception 'FAIL: history row value % done % rank % n %', r.value, r.done, r.rank, r.participants; end if;
  if r.title_de <> 'Wochen-Challenge: 20 Abfahrten' or r.title_en <> 'Weekly challenge: 20 runs' then raise exception 'FAIL: history titles % / %', r.title_de, r.title_en; end if;
  perform set_config('request.jwt.claims', claims_c, true);
  select count(*) into n from public.my_challenge_history(10);
  if n <> 0 then raise exception 'FAIL: C has history rows (%)', n; end if;

  -- 6. no client-writable value: the column is gone …
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'challenge_participants' and column_name = 'value') then
    raise exception 'FAIL: challenge_participants has a value column';
  end if;
  -- … challenge_progress is read-only …
  if has_table_privilege('authenticated', 'public.challenge_progress', 'insert') or has_table_privilege('authenticated', 'public.challenge_progress', 'update') then
    raise exception 'FAIL: authenticated may still write challenge_progress';
  end if;
  -- … joined_at is not insertable, update is not granted …
  if has_column_privilege('authenticated', 'public.challenge_participants', 'joined_at', 'insert') then raise exception 'FAIL: joined_at insertable'; end if;
  if has_table_privilege('authenticated', 'public.challenge_participants', 'update') then raise exception 'FAIL: participants updatable'; end if;
  if has_table_privilege('anon', 'public.challenge_participants', 'select') then raise exception 'FAIL: anon reads participants'; end if;

  -- 7. RLS as the authenticated role (C): own join ok, join for B rejected, ended challenge rejected, leave ok
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', claims_c, true);
  delete from public.challenge_participants where challenge_id = ch and user_id = c;
  select count(*) into n from public.challenge_participants where challenge_id = ch;
  if n <> 0 then raise exception 'FAIL: C sees rows of others (%)', n; end if;
  insert into public.challenge_participants (challenge_id, user_id) values (ch, c);
  begin
    insert into public.challenge_participants (challenge_id, user_id) values (ch, b);
    raise exception 'FAIL: C could join for B';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.challenge_participants (challenge_id, user_id) values (old_ch, c);
    raise exception 'FAIL: C could join an ended challenge';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.challenge_participants (challenge_id, user_id, joined_at) values (ch, c, now() - interval '1 year');
    raise exception 'FAIL: joined_at accepted from the client';
  exception when insufficient_privilege or unique_violation then null;
  end;
  begin
    insert into public.challenge_progress (challenge_id, user_id, value) values (ch, c, 99999);
    raise exception 'FAIL: challenge_progress accepted a value';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';

  -- 8. grants
  if has_function_privilege('anon', 'public.challenge_board(uuid)', 'execute') then raise exception 'FAIL: anon may execute challenge_board'; end if;
  if not has_function_privilege('authenticated', 'public.challenge_board(uuid)', 'execute') then raise exception 'FAIL: authenticated may not execute challenge_board'; end if;
  if has_function_privilege('anon', 'public.my_challenge_history(int)', 'execute') then raise exception 'FAIL: anon may execute history'; end if;
  if not has_function_privilege('authenticated', 'public.my_challenge_history(int)', 'execute') then raise exception 'FAIL: authenticated may not execute history'; end if;
  if has_function_privilege('authenticated', 'public.ensure_weekly_challenges(date)', 'execute') then raise exception 'FAIL: ensure_weekly_challenges callable by clients'; end if;
  if has_function_privilege('authenticated', 'private.challenge_values(uuid)', 'execute') then raise exception 'FAIL: private.challenge_values callable by clients'; end if;

  raise exception 'CHALLENGE_TEST_OK: 8 checks passed (signed-out 42501, board values/counts, unknown P0002, blocks, history, no writable value, RLS join/leave, grants); all test rows rolled back';
end $t$;
