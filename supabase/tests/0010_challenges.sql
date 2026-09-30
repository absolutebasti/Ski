-- Smoke test for migration 0010 as it stands after 0014 (weekly challenge:
-- participants, server-side progress, board, history, bilingual titles). One
-- transaction, rolled back at the end — safe against the live project
-- (tools/supabase-test.sh, pattern of 0005_rpc_security.sql).
--
-- Seed: Anna, Bernd (opted in), Chris (opted OUT — joining a challenge is the
-- consent, he is on its board anyway), Dora (joins nothing).
--   old   drop_m ≥ 2.000, 12.–18.01.2026 (ended): Anna 2.600 (done), Bernd
--         1.800 (+ a suspicious and a deleted day that must not count), Chris 0
--   days  day_count ≥ 2, same week (ended): Anna 3, Bernd 1
--   yday  ended yesterday, today ends today, open runs until today + 5
--         (Europe/Vienna calendar) — nobody is in at the start.

begin;

create temporary table t_results (n serial, test text) on commit drop;
grant all on table t_results to public;
grant all on sequence t_results_n_seq to public;

create function pg_temp.login(p_uid uuid, p_role text default 'authenticated') returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('sub', p_uid, 'role', p_role)::text end, true);
  perform set_config('role', p_role, true);
end;
$$;

create function pg_temp.pass(p_test text) returns void language sql as $$
  insert into t_results (test) values (p_test);
$$;

create temporary table t_ids (k text primary key, id uuid not null) on commit drop;
grant select on table t_ids to public;
insert into t_ids values
  ('anna',  'a0000000-0000-4000-8000-000000000010'),
  ('bernd', 'b0000000-0000-4000-8000-000000000010'),
  ('chris', 'c0000000-0000-4000-8000-000000000010'),
  ('dora',  'e0000000-0000-4000-8000-000000000010'),
  ('old',   '90000000-0000-4000-8000-000000000010'),
  ('days',  '90000000-0000-4000-8000-000000000110'),
  ('yday',  '90000000-0000-4000-8000-000000000210'),
  ('today', '90000000-0000-4000-8000-000000000310'),
  ('open',  '90000000-0000-4000-8000-000000000410');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

create function pg_temp.vienna_today() returns date language sql stable as $$
  select (now() at time zone 'Europe/Vienna')::date;
$$;

-- One plausible day (distance = 5 × vertical keeps it inside the
-- plausibility rules of 0006); the tests override what they are about.
create function pg_temp.ins_day(
  p_uid uuid, p_started timestamptz,
  p_drop double precision default 1000,
  p_run_count int default 5,
  p_speed double precision default 15,
  p_deleted boolean default false
) returns void language sql as $$
  insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                           run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at, deleted_at)
  values (gen_random_uuid(), p_uid, p_started, p_started + interval '1 hour', 'kitzbuehel', 'Kitzbühel', '2025/26', 'AT',
          p_run_count, p_drop, p_drop * 5, p_speed, 2000000, 3600000, now(), case when p_deleted then now() end);
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test10.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u where u.k in ('anna', 'bernd', 'chris', 'dora');

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true,  'DE'),
  (pg_temp.id('bernd'), 'Bernd', true,  'AT'),
  (pg_temp.id('chris'), 'Chris', false, 'CH'),
  (pg_temp.id('dora'),  'Dora',  true,  'CH');

insert into public.challenges (id, title, title_de, title_en, metric, target, starts_on, ends_on) values
  (pg_temp.id('old'),   'Alt',     'Alt',     'Old',       'drop_m',         2000, '2026-01-12', '2026-01-18'),
  (pg_temp.id('days'),  'Tage',    'Tage',    'Days',      'day_count',      2,    '2026-01-12', '2026-01-18'),
  (pg_temp.id('yday'),  'Gestern', 'Gestern', 'Yesterday', 'ski_distance_m', 1000, pg_temp.vienna_today() - 7, pg_temp.vienna_today() - 1),
  (pg_temp.id('today'), 'Heute',   'Heute',   'Today',     'ski_distance_m', 1000, pg_temp.vienna_today() - 6, pg_temp.vienna_today()),
  (pg_temp.id('open'),  'Offen',   'Offen',   'Open',      'run_count',      20,   pg_temp.vienna_today() - 1, pg_temp.vienna_today() + 5);

-- The ended challenges were joined while they ran (a client cannot do that any more).
insert into public.challenge_participants (challenge_id, user_id, joined_at) values
  (pg_temp.id('old'),  pg_temp.id('anna'),  '2026-01-12 08:00+01'),
  (pg_temp.id('old'),  pg_temp.id('bernd'), '2026-01-12 08:00+01'),
  (pg_temp.id('old'),  pg_temp.id('chris'), '2026-01-12 08:00+01'),
  (pg_temp.id('days'), pg_temp.id('anna'),  '2026-01-12 08:00+01'),
  (pg_temp.id('days'), pg_temp.id('bernd'), '2026-01-12 08:00+01');

-- Anna: 1.500 + 1.000 + 100 inside the week (the last one at 23:00 on the
-- closing Sunday), 5.000 each just before and just after it.
select pg_temp.ins_day(pg_temp.id('anna'), '2026-01-11 22:30+01', 5000);
select pg_temp.ins_day(pg_temp.id('anna'), '2026-01-13 09:00+01', 1500);
select pg_temp.ins_day(pg_temp.id('anna'), '2026-01-15 09:00+01', 1000);
select pg_temp.ins_day(pg_temp.id('anna'), '2026-01-18 23:00+01', 100);
select pg_temp.ins_day(pg_temp.id('anna'), '2026-01-19 00:30+01', 5000);
-- Bernd: 1.800 plausible, 9.000 suspicious (46 m/s), 3.000 deleted.
select pg_temp.ins_day(pg_temp.id('bernd'), '2026-01-14 09:00+01', 1800);
select pg_temp.ins_day(pg_temp.id('bernd'), '2026-01-15 09:00+01', 9000, p_run_count => 10, p_speed => 46);
select pg_temp.ins_day(pg_temp.id('bernd'), '2026-01-16 09:00+01', 3000, p_deleted => true);

-- ---------------------------------------------------------------------------
-- T1  Joining: only yourself, only while the challenge is open (ends_on today
--     still counts), nothing but (challenge_id, user_id) is writable.
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); d constant uuid := pg_temp.id('dora');
  denied int := 0; ok boolean := false; n int;
begin
  perform pg_temp.login(a);
  insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('open'), a);
  insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('today'), a);
  begin
    insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('open'), a);
  exception when unique_violation then ok := true;
  end;
  if not ok then raise exception 'T1: joining twice must be a unique_violation'; end if;

  -- after ends_on: last week's fixed one and the one that ended yesterday
  perform pg_temp.login(d);
  begin insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('old'), d);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('yday'), d);
  exception when insufficient_privilege then denied := denied + 1; end;
  -- somebody else, a chosen joined_at, a later edit
  begin insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('open'), pg_temp.id('chris'));
  exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into public.challenge_participants (challenge_id, user_id, joined_at) values (pg_temp.id('open'), d, '2000-01-01');
  exception when insufficient_privilege then denied := denied + 1; end;
  perform pg_temp.login(a);
  begin update public.challenge_participants set joined_at = '2000-01-01' where user_id = a;
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 5 then raise exception 'T1: join after ends_on / for others / with joined_at / update denied % of 5', denied; end if;

  -- own rows only
  select count(*) into n from public.challenge_participants where challenge_id = pg_temp.id('old');
  if n <> 1 then raise exception 'T1: a rider reads only the own participant rows, got %', n; end if;
  reset role;
  if (select joined_at from public.challenge_participants where challenge_id = pg_temp.id('open') and user_id = a) <> now() then
    raise exception 'T1: joined_at must come from the server';
  end if;
  if exists (select 1 from public.challenge_participants where user_id = d) then raise exception 'T1: dora must not be in anywhere'; end if;
  perform pg_temp.pass('T1 join: self only, not after ends_on, joined_at server-side');
end $$;

-- ---------------------------------------------------------------------------
-- T2  challenge_board of the ended week: days inside starts_on…ends_on
--     (Vienna), suspicious and deleted days ignored, opted-out participant
--     listed, rank/done/participants/done_count.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.challenge_board(pg_temp.id('old'));
  if n <> 3 then raise exception 'T2: expected 3 participants on the board, got %', n; end if;
  select * into r from public.challenge_board(pg_temp.id('old')) where user_id = pg_temp.id('anna');
  if r.rank <> 1 or r.value <> 2600 or not r.done or r.participants <> 3 or r.done_count <> 1
     or r.display_name <> 'Anna' or r.country_code <> 'DE' then
    raise exception 'T2: anna row wrong: %', r;
  end if;
  select * into r from public.challenge_board(pg_temp.id('old')) where user_id = pg_temp.id('bernd');
  if r.rank <> 2 or r.value <> 1800 or r.done then raise exception 'T2: bernd row wrong (suspicious/deleted day counted?): %', r; end if;
  select * into r from public.challenge_board(pg_temp.id('old')) where user_id = pg_temp.id('chris');
  if r.rank <> 3 or r.value <> 0 or r.done then raise exception 'T2: chris (opted out, no day) row wrong: %', r; end if;
  if (select array_agg(b.user_id) from public.challenge_board(pg_temp.id('old')) b)
     <> array[pg_temp.id('anna'), pg_temp.id('bernd'), pg_temp.id('chris')] then
    raise exception 'T2: board must be ordered by value desc';
  end if;

  -- day_count counts plausible days
  select * into r from public.challenge_board(pg_temp.id('days')) where user_id = pg_temp.id('anna');
  if r.value <> 3 or not r.done or r.rank <> 1 or r.participants <> 2 then raise exception 'T2: anna day_count wrong: %', r; end if;
  select * into r from public.challenge_board(pg_temp.id('days')) where user_id = pg_temp.id('bernd');
  if r.value <> 1 or r.done or r.rank <> 2 then raise exception 'T2: bernd day_count wrong: %', r; end if;

  -- any signed-in rider may look at a board; an unknown id is challenge_not_found
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.challenge_board(pg_temp.id('old'));
  if n <> 3 then raise exception 'T2: a non-participant sees the board too, got %', n; end if;
  begin
    perform public.challenge_board('90000000-0000-4000-8000-00000000ffff');
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: unknown challenge must be challenge_not_found'; end if;
  perform pg_temp.pass('T2 challenge_board: window, plausibility, rank, done, counts');
end $$;

-- ---------------------------------------------------------------------------
-- T3  A running challenge moves with the days; leaving removes the rider.
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); b constant uuid := pg_temp.id('bernd'); r record; n int;
begin
  perform pg_temp.login(a);
  select * into r from public.challenge_board(pg_temp.id('open')) where user_id = a;
  if r.value <> 0 or r.done or r.participants <> 1 or r.done_count <> 0 then raise exception 'T3: fresh participant wrong: %', r; end if;
  perform pg_temp.ins_day(a, now() - interval '2 hours', 2000, p_run_count => 12);

  perform pg_temp.login(b);
  insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('open'), b);
  perform pg_temp.ins_day(b, now() - interval '2 hours', 3000, p_run_count => 25);
  select * into r from public.challenge_board(pg_temp.id('open')) where user_id = b;
  if r.rank <> 1 or r.value <> 25 or not r.done or r.participants <> 2 or r.done_count <> 1 then
    raise exception 'T3: bernd (25 of 20 runs) wrong: %', r;
  end if;
  select * into r from public.challenge_board(pg_temp.id('open')) where user_id = a;
  if r.rank <> 2 or r.value <> 12 or r.done then raise exception 'T3: anna (12 of 20 runs) wrong: %', r; end if;

  -- leaving: own row only
  delete from public.challenge_participants where challenge_id = pg_temp.id('open');
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'T3: leaving must remove exactly the own row, removed %', n; end if;
  perform pg_temp.login(a);
  select * into r from public.challenge_board(pg_temp.id('open')) where user_id = a;
  if r.rank <> 1 or r.participants <> 1 then raise exception 'T3: board after bernd left wrong: %', r; end if;
  perform pg_temp.pass('T3 running challenge follows the days; leave');
end $$;

-- ---------------------------------------------------------------------------
-- T4  my_challenge_history: ended challenges the caller joined, with the
--     final value, done, rank and counts; running ones are not history.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ids uuid[];
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select array_agg(h.challenge_id) into ids from public.my_challenge_history(100) h;
  if not (ids @> array[pg_temp.id('old'), pg_temp.id('days')]) then raise exception 'T4: ended challenges missing: %', ids; end if;
  if ids && array[pg_temp.id('open'), pg_temp.id('today')] then raise exception 'T4: a running challenge is not history: %', ids; end if;
  select * into r from public.my_challenge_history(100) where challenge_id = pg_temp.id('old');
  if r.value <> 2600 or not r.done or r.rank <> 1 or r.participants <> 3 or r.done_count <> 1
     or r.metric <> 'drop_m' or r.target <> 2000 or r.title_de <> 'Alt' or r.title_en <> 'Old'
     or r.starts_on <> '2026-01-12' or r.ends_on <> '2026-01-18' then
    raise exception 'T4: anna history row wrong: %', r;
  end if;
  select * into r from public.my_challenge_history(100) where challenge_id = pg_temp.id('days');
  if r.value <> 3 or not r.done or r.rank <> 1 or r.participants <> 2 then raise exception 'T4: anna day_count history wrong: %', r; end if;
  -- newest first, then by metric; the limit is clamped to 1…100
  select array_agg(h.challenge_id) into ids from public.my_challenge_history(2) h;
  if ids <> array[pg_temp.id('days'), pg_temp.id('old')] then raise exception 'T4: order must be ends_on desc, metric: %', ids; end if;
  select count(*) into n from public.my_challenge_history(1);
  if n <> 1 then raise exception 'T4: p_limit not honoured'; end if;
  select count(*) into n from public.my_challenge_history(0);
  if n <> 1 then raise exception 'T4: p_limit 0 must clamp to 1, got %', n; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  select * into r from public.my_challenge_history(100) where challenge_id = pg_temp.id('old');
  if r.value <> 1800 or r.done or r.rank <> 2 or r.participants <> 3 then raise exception 'T4: bernd history row wrong: %', r; end if;
  perform pg_temp.login(pg_temp.id('chris'));
  select * into r from public.my_challenge_history(100) where challenge_id = pg_temp.id('old');
  if r.value <> 0 or r.done or r.rank <> 3 then raise exception 'T4: chris history row wrong: %', r; end if;
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.my_challenge_history(100);
  if n <> 0 then raise exception 'T4: dora joined nothing, got % rows', n; end if;
  perform pg_temp.pass('T4 my_challenge_history: final value, rank, counts, order, limit');
end $$;

-- ---------------------------------------------------------------------------
-- T5  Titles in both languages; the weekly job is idempotent and cron-only;
--     the old challenge_progress snapshot is read-only.
-- ---------------------------------------------------------------------------
do $$
declare n int; denied int := 0; w constant date := date '2099-01-05';
begin
  reset role;
  if private.challenge_title('drop_m', 5000, 'de') <> 'Wochen-Challenge: 5.000 Höhenmeter'
     or private.challenge_title('drop_m', 5000, 'en') <> 'Weekly challenge: 5,000 m vertical'
     or private.challenge_title('run_count', 20, 'de') <> 'Wochen-Challenge: 20 Abfahrten'
     or private.challenge_title('day_count', 1, 'en') <> 'Weekly challenge: 1 ski day'
     or private.challenge_title('day_count', 3, 'de') <> 'Wochen-Challenge: 3 Skitage' then
    raise exception 'T5: challenge_title wrong: % / %', private.challenge_title('drop_m', 5000, 'de'), private.challenge_title('drop_m', 5000, 'en');
  end if;
  if public.ensure_weekly_challenges(w) <> 3 then raise exception 'T5: a new week must get three challenges'; end if;
  if public.ensure_weekly_challenges(w) <> 0 then raise exception 'T5: ensure_weekly_challenges must be idempotent'; end if;
  select count(*) into n from public.challenges c
   where c.starts_on = w and c.ends_on = w + 6 and c.title = c.title_de and c.title_en like 'Weekly challenge: %'
     and char_length(c.title_de) <= 60 and c.metric in ('drop_m', 'run_count', 'day_count');
  if n <> 3 then raise exception 'T5: weekly challenges wrong (% of 3 well-formed)', n; end if;
  if has_function_privilege('authenticated', 'public.ensure_weekly_challenges(date)', 'execute')
     or has_function_privilege('authenticated', 'private.challenge_values(uuid)', 'execute')
     or has_function_privilege('anon', 'public.challenge_board(uuid)', 'execute')
     or has_function_privilege('anon', 'public.my_challenge_history(int)', 'execute') then
    raise exception 'T5: grants wrong (cron-only job, private helper, anon)';
  end if;

  perform pg_temp.login(pg_temp.id('anna'));
  begin insert into public.challenge_progress (challenge_id, user_id, value) values (pg_temp.id('open'), pg_temp.id('anna'), 99999);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin update public.challenge_progress set value = 99999;
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 2 then raise exception 'T5: challenge_progress must be read-only for clients (% of 2)', denied; end if;
  perform pg_temp.pass('T5 titles de/en, weekly job idempotent + cron-only, progress read-only');
end $$;

-- T6  anon gets nothing.
do $$
declare denied int := 0;
begin
  perform pg_temp.login(null, 'anon');
  begin perform public.challenge_board(pg_temp.id('old')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.my_challenge_history(5); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.challenge_participants; exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into public.challenge_participants (challenge_id, user_id) values (pg_temp.id('open'), pg_temp.id('dora'));
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 4 then raise exception 'T6: anon denied % of 4', denied; end if;
  perform pg_temp.pass('T6 anon denied');
end $$;

reset role;
select n, test from t_results order by n;
rollback;
