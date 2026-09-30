-- Smoke test for migration 0015 (track_path writes are free, live_days day
-- window + 20 s throttle, counter cleanup in the cron, join_group expiry in
-- the group's time zone). One transaction, rolled back at the end — safe
-- against the live project (tools/supabase-test.sh, pattern of 0005).
--
-- Seed: Anna, Bernd, Chris (all opted in), Dora (auth user without a profile
-- row); the days are created inside the tests as the riders themselves so
-- days_guard sees client writes.

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
  ('anna',  'a0000000-0000-4000-8000-000000000015'),
  ('bernd', 'b0000000-0000-4000-8000-000000000015'),
  ('chris', 'c0000000-0000-4000-8000-000000000015'),
  ('dora',  'e0000000-0000-4000-8000-000000000015');  -- no profile row (T8)

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

-- Day ids of the 150-day sync, in order (k = 1..150).
create temporary table t_days (k int primary key, id uuid not null default gen_random_uuid(), started_at timestamptz not null) on commit drop;
grant all on table t_days to public;
-- 50 Vienna dates × 3 days (the per-date maximum), December 2025 onwards.
insert into t_days (k, started_at)
select i, (timestamptz '2025-12-01 09:00+01' + ((i - 1) / 3) * interval '1 day' + ((i - 1) % 3) * interval '2 hours')
from generate_series(1, 150) i;

-- The app's upsert (PostgREST `on_conflict=id`), as the calling rider. The
-- insert path back-dates updated_at by an hour (an insert may carry it; every
-- update is server-owned) so the tests can tell "moved to now()" from "left
-- alone" inside one transaction, where now() never advances.
create function pg_temp.upsert_day(p_id uuid, p_uid uuid, p_started timestamptz, p_drop double precision, p_dev timestamptz)
returns void language sql as $$
  insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                           run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at, updated_at)
  values (p_id, p_uid, p_started, p_started + interval '1 hour', 'kitzbuehel', 'Kitzbühel', '2025/26', 'AT',
          5, p_drop, 8000, 15, 2000000, 3600000, p_dev, now() - interval '1 hour')
  on conflict (id) do update set
    started_at = excluded.started_at, ended_at = excluded.ended_at, drop_m = excluded.drop_m,
    device_updated_at = excluded.device_updated_at;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test15.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true, 'DE'),
  (pg_temp.id('bernd'), 'Bernd', true, 'AT'),
  (pg_temp.id('chris'), 'Chris', true, 'CH');

-- ---------------------------------------------------------------------------
-- T1  150 day upserts + 150 track_path updates in one hour: all succeed, the
--     counter shows 150, no track_path update moves updated_at.
-- ---------------------------------------------------------------------------
do $$
declare d record; n int; dev constant timestamptz := now() - interval '5 minutes';
begin
  perform pg_temp.login(pg_temp.id('anna'));
  for d in select * from t_days order by k loop
    perform pg_temp.upsert_day(d.id, pg_temp.id('anna'), d.started_at, 1000, dev);
  end loop;
  for d in select * from t_days order by k loop
    update public.days set track_path = pg_temp.id('anna') || '/' || d.id || '.json.gz' where id = d.id;
  end loop;
  select count(*) into n from public.days where user_id = pg_temp.id('anna') and track_path is not null;
  if n <> 150 then raise exception 'T1: expected 150 days with track_path, got %', n; end if;
  select count(*) into n from public.days where user_id = pg_temp.id('anna') and updated_at = now() - interval '1 hour';
  if n <> 150 then raise exception 'T1: track_path updates moved updated_at on % of 150 days', 150 - n; end if;
  reset role;
  select writes into n from public.day_write_counters where user_id = pg_temp.id('anna');
  if n <> 150 then raise exception 'T1: expected 150 counted writes, got %', n; end if;
  perform pg_temp.pass('T1 150 upserts + 150 track_path updates → 150 counted, updated_at untouched');
end $$;

-- T2  updated_at and the counter move with every real write and only then;
--     too_many_days is still enforced without a new device clock.
do $$
declare d1 uuid; d4 uuid; ts timestamptz; n int; ok boolean := false;
  old_ts constant timestamptz := now() - interval '1 hour';
begin
  select id into d1 from t_days where k = 1;
  select id into d4 from t_days where k = 4;

  -- a client cannot move updated_at along with a track_path update, and a
  -- no-op re-upsert (same device clock, same numbers) is free as well
  perform pg_temp.login(pg_temp.id('anna'));
  update public.days set track_path = 'x/' || d1 || '.json.gz', updated_at = now() + interval '1 day' where id = d1;
  perform pg_temp.upsert_day(d1, pg_temp.id('anna'), (select started_at from t_days where k = 1), 1000, now() - interval '5 minutes');
  select updated_at into ts from public.days where id = d1;
  if ts <> old_ts then raise exception 'T2: track_path update / no-op upsert moved updated_at (%)', ts; end if;
  reset role;
  select writes into n from public.day_write_counters where user_id = pg_temp.id('anna');
  if n <> 150 then raise exception 'T2: track_path update / no-op upsert was counted (%)', n; end if;

  -- a real re-upsert: new device_updated_at → counted, updated_at = now()
  perform pg_temp.login(pg_temp.id('anna'));
  perform pg_temp.upsert_day(d1, pg_temp.id('anna'), (select started_at from t_days where k = 1), 1500, now());
  select updated_at into ts from public.days where id = d1;
  if ts <> now() then raise exception 'T2: device write must move updated_at (%)', ts; end if;
  reset role;
  select writes into n from public.day_write_counters where user_id = pg_temp.id('anna');
  if n <> 151 then raise exception 'T2: device write not counted (%)', n; end if;

  -- a metric change without a new device_updated_at is still a client write
  perform pg_temp.login(pg_temp.id('anna'));
  update public.days set drop_m = 1600 where id = d4;
  select updated_at into ts from public.days where id = d4;
  if ts <> now() then raise exception 'T2: metric change with a stale device clock must move updated_at (%)', ts; end if;
  reset role;
  select writes into n from public.day_write_counters where user_id = pg_temp.id('anna');
  if n <> 152 then raise exception 'T2: metric change with a stale device clock must count (%)', n; end if;

  -- moving day 4 onto the (full) date of day 1 with a stale device clock → P0004
  perform pg_temp.login(pg_temp.id('anna'));
  begin
    update public.days set started_at = (select started_at from t_days where k = 1) + interval '30 minutes' where id = d4;
  exception when sqlstate 'P0004' then ok := true;
  end;
  if not ok then raise exception 'T2: too_many_days must still be enforced'; end if;
  perform pg_temp.pass('T2 updated_at + counter only for real writes; too_many_days kept');
end $$;

-- T3  the hour window: a counter at the limit whose window is over resets to 1.
do $$
declare n int; ok boolean := false;
begin
  reset role;
  insert into public.day_write_counters (user_id, window_start, writes)
  values (pg_temp.id('bernd'), now() - interval '3 hours', 200);
  perform pg_temp.login(pg_temp.id('bernd'));
  perform pg_temp.upsert_day(gen_random_uuid(), pg_temp.id('bernd'), timestamptz '2026-01-15 09:00+01', 900, now());
  reset role;
  select writes into n from public.day_write_counters where user_id = pg_temp.id('bernd');
  if n <> 1 then raise exception 'T3: expired window must reset to 1, got %', n; end if;
  update public.day_write_counters set writes = 200 where user_id = pg_temp.id('bernd');
  perform pg_temp.login(pg_temp.id('bernd'));
  begin
    perform pg_temp.upsert_day(gen_random_uuid(), pg_temp.id('bernd'), timestamptz '2026-01-16 09:00+01', 900, now());
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T3: 201st write must be rate_limited'; end if;
  perform pg_temp.pass('T3 counter window expiry + 201st write rate_limited');
end $$;

-- ---------------------------------------------------------------------------
-- T4  live_days: day within current_date ± 1; second update within 20 s →
--     rate_limited; after 20 s it goes through.
-- ---------------------------------------------------------------------------
do $$
declare bad int := 0; ok boolean := false; r record;
begin
  perform pg_temp.login(pg_temp.id('chris'));
  begin
    insert into public.live_days (user_id, day, drop_m) values (pg_temp.id('chris'), current_date - 5, 10);
  exception when check_violation then bad := bad + 1;
  end;
  begin
    insert into public.live_days (user_id, day, drop_m) values (pg_temp.id('chris'), current_date + 2, 10);
  exception when check_violation then bad := bad + 1;
  end;
  if bad <> 2 then raise exception 'T4: day outside current_date ± 1 must fail (% of 2)', bad; end if;

  insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('chris'), current_date - 1, 100, 1)
    on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  begin
    insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('chris'), current_date - 1, 200, 2)
      on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T4: second update within 20 s must be rate_limited'; end if;
  select * into r from public.live_days where user_id = pg_temp.id('chris');
  if r.drop_m <> 100 then raise exception 'T4: rejected update must not land (%)', r.drop_m; end if;

  -- let 30 s pass (the touch trigger would re-stamp now(), so it is paused)
  reset role;
  alter table public.live_days disable trigger live_days_touch;
  update public.live_days set updated_at = now() - interval '30 seconds' where user_id = pg_temp.id('chris');
  alter table public.live_days enable trigger live_days_touch;
  perform pg_temp.login(pg_temp.id('chris'));
  insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('chris'), current_date + 1, 300, 3)
    on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  select * into r from public.live_days where user_id = pg_temp.id('chris');
  if r.drop_m <> 300 or r.day <> current_date + 1 or r.updated_at <> now() then
    raise exception 'T4: update after 20 s must land with server updated_at (%)', r;
  end if;
  -- a fresh insert of another rider is unaffected by chris's throttle
  perform pg_temp.login(pg_temp.id('bernd'));
  insert into public.live_days (user_id, day, drop_m) values (pg_temp.id('bernd'), current_date, 50);
  perform pg_temp.pass('T4 live_days day window + 20 s throttle');
end $$;

-- ---------------------------------------------------------------------------
-- T5  cron live-days-cleanup: live rows older than two days and counters with
--     a window older than two hours go; fresh rows stay.
-- ---------------------------------------------------------------------------
do $$
declare cmd text; sched text; n int;
begin
  reset role;
  select command, schedule into cmd, sched from cron.job where jobname = 'live-days-cleanup';
  if cmd is null or sched <> '0 5 * * *' then raise exception 'T5: cron job missing or wrong schedule (%)', sched; end if;
  if cmd not like '%day_write_counters%' then raise exception 'T5: cron must clean day_write_counters: %', cmd; end if;
  -- chris: stale window; anna: fresh (T1)
  insert into public.day_write_counters (user_id, window_start, writes) values (pg_temp.id('chris'), now() - interval '3 hours', 7);
  execute cmd;
  select count(*) into n from public.day_write_counters where user_id = pg_temp.id('chris');
  if n <> 0 then raise exception 'T5: stale counter must be deleted'; end if;
  select count(*) into n from public.day_write_counters where user_id = pg_temp.id('anna');
  if n <> 1 then raise exception 'T5: fresh counter must stay'; end if;
  select count(*) into n from public.live_days where user_id in (pg_temp.id('chris'), pg_temp.id('bernd'));
  if n <> 2 then raise exception 'T5: live rows within two days must stay (%)', n; end if;
  perform pg_temp.pass('T5 cron cleans stale counters, keeps fresh rows');
end $$;

-- ---------------------------------------------------------------------------
-- T6  join_group judges duel_expired in the group's own time zone.
--     a) fixed instants through private.duel_expired (the clock of a
--        transaction cannot be moved): a Denver duel on the 15th is joinable
--        at 23:30 Vienna time on the 16th and still at 00:30 on the 17th
--        (16:30 on the 16th in Denver — 0006 called that expired), until
--        Denver's 16th is over.
--     b) the real RPC at the real clock: Pago Pago (UTC-11) is the last zone
--        to reach a date, Kiritimati (UTC+14) the first; "yesterday" in the
--        group's zone is always joinable, "the day before yesterday" never —
--        whatever Vienna's clock says.
-- ---------------------------------------------------------------------------
do $$
declare d constant date := date '2026-01-15';
begin
  reset role;
  if private.duel_expired(d, 'America/Denver', timestamptz '2026-01-16 23:30 Europe/Vienna') then
    raise exception 'T6: denver duel must be joinable at 23:30 Vienna on day+1';
  end if;
  if private.duel_expired(d, 'America/Denver', timestamptz '2026-01-17 00:30 Europe/Vienna') then
    raise exception 'T6: denver duel must be joinable at 00:30 Vienna on day+2 (16:30 day+1 in Denver)';
  end if;
  if private.duel_expired(d, 'America/Denver', timestamptz '2026-01-16 23:59:59 America/Denver') then
    raise exception 'T6: denver duel must be joinable until the end of day+1 in Denver';
  end if;
  if not private.duel_expired(d, 'America/Denver', timestamptz '2026-01-17 00:00 America/Denver') then
    raise exception 'T6: denver duel must be expired on day+2 in Denver';
  end if;
  if private.duel_expired(d, 'Europe/Vienna', timestamptz '2026-01-16 23:59:59 Europe/Vienna')
     or not private.duel_expired(d, 'Europe/Vienna', timestamptz '2026-01-17 00:00 Europe/Vienna') then
    raise exception 'T6: vienna duel must expire at midnight Vienna after day+1';
  end if;
  if private.duel_expired(d, null, timestamptz '2026-01-16 23:59:59 Europe/Vienna')
     or not private.duel_expired(d, '', timestamptz '2026-01-17 00:00 Europe/Vienna') then
    raise exception 'T6: missing tz must fall back to Europe/Vienna';
  end if;
end $$;

do $$
declare r record; ok boolean := false; n int;
  d_pago date := (now() at time zone 'Pacific/Pago_Pago')::date;
  d_kiri date := (now() at time zone 'Pacific/Kiritimati')::date;
  d_den  date := (now() at time zone 'America/Denver')::date;
begin
  reset role;
  insert into public.groups (id, code, name, day, created_by, max_members, tz) values
    ('d0000000-0000-4000-8000-000000000015', 'TST015', 'Pago gestern',  d_pago - 1, pg_temp.id('anna'), 3, 'Pacific/Pago_Pago'),
    ('d0000000-0000-4000-8000-000000000115', 'TST115', 'Denver gestern', d_den - 1,  pg_temp.id('anna'), 3, 'America/Denver'),
    ('d0000000-0000-4000-8000-000000000215', 'TST215', 'Kiri gestern',  d_kiri - 1, pg_temp.id('anna'), 3, 'Pacific/Kiritimati'),
    ('d0000000-0000-4000-8000-000000000315', 'TST315', 'Kiri vorgestern', d_kiri - 2, pg_temp.id('anna'), 3, 'Pacific/Kiritimati'),
    ('d0000000-0000-4000-8000-000000000415', 'TST415', 'Voll', current_date, pg_temp.id('anna'), 2, 'Europe/Vienna');
  insert into public.group_members (group_id, user_id)
  select g.id, pg_temp.id('anna') from public.groups g where g.code like 'TST_15';
  insert into public.group_members (group_id, user_id) values ('d0000000-0000-4000-8000-000000000415', pg_temp.id('chris'));

  perform pg_temp.login(pg_temp.id('bernd'));
  select * into r from public.join_group('TST015');
  if r.id <> 'd0000000-0000-4000-8000-000000000015'::uuid or r.max_members <> 3 or r.code <> 'TST015' then
    raise exception 'T6: pago yesterday must be joinable (%)', r;
  end if;
  select * into r from public.join_group('tst115');
  if r.day <> d_den - 1 then raise exception 'T6: denver yesterday must be joinable (%)', r; end if;
  select * into r from public.join_group('TST215');
  if r.day <> d_kiri - 1 then raise exception 'T6: kiritimati yesterday must be joinable (%)', r; end if;
  begin
    perform public.join_group('TST315');
  exception when sqlstate 'P0006' then ok := true;
  end;
  if not ok then raise exception 'T6: the day before yesterday (group tz) must be duel_expired'; end if;
  ok := false;
  begin
    perform public.join_group('TST415');
  exception when sqlstate 'P0003' then ok := true;
  end;
  if not ok then raise exception 'T6: full duel must be duel_full'; end if;
  ok := false;
  begin
    perform public.join_group('NOPE15');
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T6: unknown code must be code_not_found'; end if;
  -- joining twice is idempotent
  perform public.join_group('TST015');
  reset role;
  select count(*) into n from public.group_members where group_id = 'd0000000-0000-4000-8000-000000000015';
  if n <> 2 then raise exception 'T6: repeated join must not add a row (%)', n; end if;
  perform pg_temp.pass('T6 join_group expiry in the group tz');
end $$;

-- T7  anon gets nothing; helpers and trigger functions have no client grant.
do $$
declare denied int := 0;
begin
  perform pg_temp.login(null, 'anon');
  begin perform public.join_group('TST015'); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.live_days; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.day_write_counters; exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T7: anon denied % of 3', denied; end if;
  reset role;
  if has_function_privilege('authenticated', 'private.duel_expired(date, text, timestamptz)', 'execute')
     or has_function_privilege('authenticated', 'private.live_days_touch()', 'execute')
     or has_function_privilege('authenticated', 'public.days_guard()', 'execute')
     or has_function_privilege('anon', 'public.join_group(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.join_group(text)', 'execute') then
    raise exception 'T7: grants wrong (helpers/trigger functions must have none, join_group authenticated only)';
  end if;
  perform pg_temp.pass('T7 anon denied, helpers without client grant');
end $$;

-- ---------------------------------------------------------------------------
-- T8  blocked_riders: the caller's own blocks, newest first, with name and
--     avatar although rider_profile hides the pair; a rider without a profile
--     row still appears (null name); signed out → 42501; anon has no grant.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ids uuid[]; ok boolean := false; denied boolean := false;
begin
  reset role;
  update public.profiles set avatar_url = 'https://example.invalid/bernd.png' where id = pg_temp.id('bernd');
  insert into public.blocks (user_id, blocked_id, created_at) values
    (pg_temp.id('anna'),  pg_temp.id('bernd'), now() - interval '2 days'),
    (pg_temp.id('anna'),  pg_temp.id('dora'),  now() - interval '1 day'),
    (pg_temp.id('chris'), pg_temp.id('anna'),  now());

  perform pg_temp.login(pg_temp.id('anna'));
  select array_agg(b.user_id order by ord) into ids
    from public.blocked_riders() with ordinality as b(user_id, display_name, avatar_url, created_at, ord);
  if ids is distinct from array[pg_temp.id('dora'), pg_temp.id('bernd')] then
    raise exception 'T8: expected dora, bernd (newest first), got %', ids;
  end if;
  select * into r from public.blocked_riders() b where b.user_id = pg_temp.id('bernd');
  if r.display_name <> 'Bernd' or r.avatar_url <> 'https://example.invalid/bernd.png' or r.created_at <> now() - interval '2 days' then
    raise exception 'T8: bernd row wrong (%)', r;
  end if;
  select * into r from public.blocked_riders() b where b.user_id = pg_temp.id('dora');
  if r.display_name is not null or r.avatar_url is not null then raise exception 'T8: dora has no profile (%)', r; end if;
  -- the profile itself stays hidden from Anna (rider_profile + own-row RLS)
  select count(*) into n from public.profiles where id = pg_temp.id('bernd');
  if n <> 0 then raise exception 'T8: profiles must stay own-row'; end if;

  -- Bernd blocked nobody; Chris sees only his own block, not who blocked him
  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.blocked_riders();
  if n <> 0 then raise exception 'T8: bernd must see no rows (%)', n; end if;
  perform pg_temp.login(pg_temp.id('chris'));
  select array_agg(b.user_id) into ids from public.blocked_riders() b;
  if ids is distinct from array[pg_temp.id('anna')] then raise exception 'T8: chris must see only anna (%)', ids; end if;

  perform pg_temp.login(null, 'authenticated');
  begin perform count(*) from public.blocked_riders(); exception when sqlstate '42501' then ok := true; end;
  if not ok then raise exception 'T8: without a user id → not_signed_in'; end if;
  perform pg_temp.login(null, 'anon');
  begin perform count(*) from public.blocked_riders(); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'T8: anon must not execute blocked_riders'; end if;
  reset role;
  if has_function_privilege('anon', 'public.blocked_riders()', 'execute')
     or not has_function_privilege('authenticated', 'public.blocked_riders()', 'execute') then
    raise exception 'T8: blocked_riders grants wrong';
  end if;
  perform pg_temp.pass('T8 blocked_riders: own blocks, newest first, names despite hiding');
end $$;

reset role;
select n, test from t_results order by n;
rollback;
