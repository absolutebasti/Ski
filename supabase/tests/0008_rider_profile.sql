-- Smoke test for migration 0008 (rider_profile) with the block rules of
-- 0014. One transaction, rolled back at the end (tools/supabase-test.sh;
-- pattern of 0005_rpc_security.sql).
--
-- Seed: Anna (opted in; two days last season in Kitzbühel/AT, one day this
-- season yesterday in Zermatt/CH, one suspicious day), Bernd (opted out, duel
-- partner of Anna), Chris (opted out), Dora (opted in, the viewer; friend of
-- Chris).

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
  ('anna',  'a0000000-0000-4000-8000-000000000008'),
  ('bernd', 'b0000000-0000-4000-8000-000000000008'),
  ('chris', 'c0000000-0000-4000-8000-000000000008'),
  ('dora',  'e0000000-0000-4000-8000-000000000008'),
  ('duel',  'd0000000-0000-4000-8000-000000000008');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

-- current season key the way rider_profile computes it ('2026/27' from July).
create function pg_temp.season_now() returns text language sql stable as $$
  select y::text || '/' || lpad(((y + 1) % 100)::text, 2, '0') from (
    select case when extract(month from (now() at time zone 'Europe/Vienna')) < 7
                then extract(year from (now() at time zone 'Europe/Vienna'))::int - 1
                else extract(year from (now() at time zone 'Europe/Vienna'))::int end as y
  ) s;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test8.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u where u.k <> 'duel';

insert into public.profiles (id, display_name, share_leaderboards, country_code, home_resort_id) values
  (pg_temp.id('anna'),  'Anna',  true,  'DE', 'kitzbuehel'),
  (pg_temp.id('bernd'), 'Bernd', false, 'AT', null),
  (pg_temp.id('chris'), 'Chris', false, 'DE', null),
  (pg_temp.id('dora'),  'Dora',  true,  'CH', null);

insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values
  -- last season, two consecutive days
  (gen_random_uuid(), pg_temp.id('anna'), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('anna'), '2026-01-16 09:00+01', '2026-01-16 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 8, 2500, 15000, 22, 3000000, 21600000, now()),
  -- suspicious (max speed 50 m/s): counts as a day, not in the sums
  (gen_random_uuid(), pg_temp.id('anna'), '2026-02-01 09:00+01', '2026-02-01 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 5, 1000, 9000, 50, 1000000, 21600000, now()),
  -- this season, yesterday, Zermatt
  (gen_random_uuid(), pg_temp.id('anna'), now() - interval '1 day', now() - interval '18 hours', 'zermatt', 'Zermatt',
   pg_temp.season_now(), 'CH', 6, 1500, 12000, 16, 2000000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('bernd'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 12, 4000, 30000, 20, 4000000, 21600000, now());

insert into public.groups (id, code, name, day, resort_id, created_by, max_members)
values (pg_temp.id('duel'), 'TST008', 'Testduell', '2026-01-15', null, pg_temp.id('anna'), 3);
insert into public.group_members (group_id, user_id) values
  (pg_temp.id('duel'), pg_temp.id('anna')),
  (pg_temp.id('duel'), pg_temp.id('bernd'));

insert into public.friendships (user_id, friend_id, status) values (pg_temp.id('chris'), pg_temp.id('dora'), 'accepted');

-- ---------------------------------------------------------------------------
-- T1  Opted-in stranger: full row with season + lifetime numbers.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('anna'));
  if n <> 1 then raise exception 'T1: expected one row, got %', n; end if;
  select * into r from public.rider_profile(pg_temp.id('anna'));
  if r.display_name <> 'Anna' or r.country_code <> 'DE' or r.home_resort_id <> 'kitzbuehel' then raise exception 'T1: head wrong: %', r; end if;
  if r.season_key <> pg_temp.season_now() then raise exception 'T1: season_key % <> %', r.season_key, pg_temp.season_now(); end if;
  if r.season_drop_m <> 1500 or r.season_ski_distance_m <> 12000 or r.season_run_count <> 6 or r.season_day_count <> 1 then
    raise exception 'T1: season numbers wrong: %', r;
  end if;
  -- lifetime: sums skip the suspicious day, day_count counts it
  if r.lifetime_drop_m <> 7000 or r.lifetime_ski_distance_m <> 47000 or r.lifetime_run_count <> 24 or r.lifetime_day_count <> 4 then
    raise exception 'T1: lifetime numbers wrong: %', r;
  end if;
  if r.lifetime_max_speed_ms <> 22 then raise exception 'T1: max speed must ignore the suspicious day, got %', r.lifetime_max_speed_ms; end if;
  if r.best_day_drop_m <> 3000 or r.best_day_run_count <> 10 then raise exception 'T1: best day wrong: %', r; end if;
  if r.longest_streak <> 2 then raise exception 'T1: longest streak should be 2, got %', r.longest_streak; end if;
  if r.resort_count <> 2 or r.country_count <> 2 then raise exception 'T1: resort/country counts wrong: %', r; end if;
  if r.last_day < now() - interval '2 days' then raise exception 'T1: last_day wrong: %', r.last_day; end if;
  if r.lifetime_points <= 0 or r.season_points <= 0 then raise exception 'T1: points must be positive: %', r; end if;
  perform pg_temp.pass('T1 opted-in stranger: season + lifetime numbers, streak, resorts, countries');
end $$;

-- ---------------------------------------------------------------------------
-- T2  Opted-out rider: hidden from strangers, visible to a duel partner and
--     to himself.
-- ---------------------------------------------------------------------------
do $$
declare n int; r record;
begin
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('bernd'));
  if n <> 0 then raise exception 'T2: opted-out stranger must be hidden, got % rows', n; end if;
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.rider_profile(pg_temp.id('bernd'));
  if r.display_name is distinct from 'Bernd' or r.lifetime_drop_m <> 4000 then raise exception 'T2: duel partner must see bernd: %', r; end if;
  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.rider_profile(pg_temp.id('bernd'));
  if n <> 1 then raise exception 'T2: own profile must always be visible'; end if;
  perform pg_temp.pass('T2 opted-out rider hidden from strangers, visible to duel partner and self');
end $$;

-- ---------------------------------------------------------------------------
-- T3  Accepted friendship makes an opted-out rider visible; pending does not.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('chris'));
  if n <> 1 then raise exception 'T3: friend must see chris'; end if;
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.rider_profile(pg_temp.id('chris'));
  if n <> 0 then raise exception 'T3: anna is no friend of chris'; end if;
  reset role;
  update public.friendships set status = 'pending' where user_id = pg_temp.id('chris') and friend_id = pg_temp.id('dora');
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('chris'));
  if n <> 0 then raise exception 'T3: a pending request must not open the profile'; end if;
  perform pg_temp.pass('T3 accepted friendship opens an opted-out profile, pending does not');
end $$;

-- ---------------------------------------------------------------------------
-- T4  Blocks hide the profile in both directions; unblock restores.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('anna'), pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('dora'));
  if n <> 0 then raise exception 'T4: blocker must not see the blocked profile'; end if;
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('anna'));
  if n <> 0 then raise exception 'T4: blocked rider must not see the blocker'; end if;
  perform pg_temp.login(pg_temp.id('anna'));
  delete from public.blocks where blocked_id = pg_temp.id('dora');
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile(pg_temp.id('anna'));
  if n <> 1 then raise exception 'T4: unblock must restore visibility'; end if;
  perform pg_temp.pass('T4 block hides the profile both ways, unblock restores');
end $$;

-- ---------------------------------------------------------------------------
-- T5  Edge cases: unknown id / null → no row; anon denied; signed-out 42501.
-- ---------------------------------------------------------------------------
do $$
declare n int; ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.rider_profile('00000000-0000-4000-8000-0000000000ff');
  if n <> 0 then raise exception 'T5: unknown id must return nothing'; end if;
  select count(*) into n from public.rider_profile(null);
  if n <> 0 then raise exception 'T5: null id must return nothing'; end if;
  perform pg_temp.login(null, 'anon');
  begin perform public.rider_profile(pg_temp.id('anna'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: anon must be denied'; end if;
  reset role;
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  perform set_config('role', 'authenticated', true);
  ok := false;
  begin perform public.rider_profile(pg_temp.id('anna'));
  exception when insufficient_privilege then
    if sqlerrm <> 'not_signed_in' then raise exception 'T5: wrong message %', sqlerrm; end if; ok := true;
  end;
  if not ok then raise exception 'T5: signed-out authenticated must raise not_signed_in'; end if;
  perform pg_temp.pass('T5 unknown/null id empty, anon denied, not_signed_in without sub');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
