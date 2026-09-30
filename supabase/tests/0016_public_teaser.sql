-- Smoke test for migration 0016 (public_board_teaser: the signed-out top 10).
-- One transaction, rolled back at the end — safe against the live project
-- (tools/supabase-test.sh, pattern of 0005_rpc_security.sql).
--
-- Seed (resort ids test16-kitz / test16-ischgl, so real riders on the live
-- project never land on the tested boards): 12 opted-in riders in Kitzbühel ('Rider 1' … 'Rider 12', points
-- descending with the index → Rider 1 leads), Chris opted OUT with the
-- biggest day of all, Dora opted in but her only day is suspicious, Erik
-- opted in with a deleted day, Frida opted in with her only day in Ischgl.
-- Anon must get exactly 10 rows, all opted-in riders, without Chris, Dora,
-- Erik; Frida only on the Ischgl board.

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
  ('chris', 'c0000000-0000-4000-8000-000000000016'),
  ('dora',  'd0000000-0000-4000-8000-000000000016'),
  ('erik',  'e0000000-0000-4000-8000-000000000016'),
  ('frida', 'f0000000-0000-4000-8000-000000000016');
insert into t_ids select 'rider' || i, ('a0000000-0000-4000-8000-' || lpad((1600 + i)::text, 12, '0'))::uuid
from generate_series(1, 12) i;

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test16.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code, avatar_url) values
  (pg_temp.id('chris'), 'Chris', false, 'DE', null),
  (pg_temp.id('dora'),  'Dora',  true,  'CH', null),
  (pg_temp.id('erik'),  'Erik',  true,  'AT', null),
  (pg_temp.id('frida'), 'Frida', true,  'AT', 'https://example.invalid/frida.jpg');
insert into public.profiles (id, display_name, share_leaderboards, country_code)
select pg_temp.id('rider' || i), 'Rider ' || i, true, 'AT' from generate_series(1, 12) i;

-- Rider i: drop (13 − i) × 1000 m → points strictly descending with i.
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
select gen_random_uuid(), pg_temp.id('rider' || i), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'test16-kitz', 'Kitzbühel',
       '2025/26', 'AT', 8, (13 - i) * 1000, 15000, 18, 3600000, 21600000, now()
from generate_series(1, 12) i;

insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at,
                         deleted_at)
values
  -- Chris: opted out, biggest plausible day of all → must never show.
  (gen_random_uuid(), pg_temp.id('chris'), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'test16-kitz', 'Kitzbühel',
   '2025/26', 'AT', 30, 14000, 60000, 25, 5000000, 21600000, now(), null),
  -- Dora: opted in, only day suspicious (generated: max_speed_ms > 45) → absent.
  (gen_random_uuid(), pg_temp.id('dora'), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'test16-kitz', 'Kitzbühel',
   '2025/26', 'AT', 30, 13500, 60000, 50, 5000000, 21600000, now(), null),
  -- Erik: opted in, only day deleted → absent.
  (gen_random_uuid(), pg_temp.id('erik'), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'test16-kitz', 'Kitzbühel',
   '2025/26', 'AT', 30, 13000, 60000, 25, 5000000, 21600000, now(), now()),
  -- Frida: opted in, Ischgl only, small day.
  (gen_random_uuid(), pg_temp.id('frida'), '2026-01-16 09:00+01', '2026-01-16 15:00+01', 'test16-ischgl', 'Ischgl',
   '2025/26', 'AT', 3, 500, 4000, 12, 1000000, 21600000, now(), null);

-- ---------------------------------------------------------------------------
-- T1  anon: exactly 10 rows, rank 1…10 in order, only opted-in riders with a
--     plausible day; Chris / Dora / Erik absent; avatar_url passed through.
-- ---------------------------------------------------------------------------
do $$
declare n int; r record; names text;
begin
  perform pg_temp.login(null, 'anon');
  select count(*) into n from public.public_board_teaser('test16-kitz', '2025/26');
  if n <> 10 then raise exception 'T1: anon should get 10 rows, got %', n; end if;
  select string_agg(t.display_name, ',' order by t.rank) into names from public.public_board_teaser('test16-kitz', '2025/26') t;
  if names <> 'Rider 1,Rider 2,Rider 3,Rider 4,Rider 5,Rider 6,Rider 7,Rider 8,Rider 9,Rider 10' then
    raise exception 'T1: unexpected order/names: %', names;
  end if;
  select * into r from public.public_board_teaser('test16-kitz', '2025/26') t where t.rank = 1;
  if r.display_name <> 'Rider 1' or r.value <> round(12000.0 / 10 + 15000.0 / 100 + 8 * 5 + 50) then
    raise exception 'T1: leader row wrong: %', r;
  end if;
  select count(*) into n from public.public_board_teaser('test16-kitz', '2025/26') t
    where t.display_name in ('Chris', 'Dora', 'Erik', 'Frida');
  if n <> 0 then raise exception 'T1: opted-out / suspicious / deleted / other-resort riders must be absent, got %', n; end if;
  -- everybody on the board is opted in (join back via the name — the RPC has no id);
  -- the cross-check reads profiles, which anon may not: verify as postgres.
  reset role;
  select count(*) into n from public.public_board_teaser('test16-kitz', '2025/26') t
    where not exists (select 1 from public.profiles p where p.display_name = t.display_name and p.share_leaderboards);
  if n <> 0 then raise exception 'T1: % rows are not opted-in riders', n; end if;
  perform pg_temp.pass('T1 anon gets the top 10 opted-in riders in rank order; opted-out, suspicious, deleted, other-resort rows absent');
end $$;

-- ---------------------------------------------------------------------------
-- T2  Row shape: no user_id (or any id) column; the four columns only.
-- ---------------------------------------------------------------------------
do $$
declare cols text;
begin
  reset role;
  select pg_get_function_result(p.oid) into cols
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'public_board_teaser';
  if cols is distinct from 'TABLE(rank bigint, display_name text, avatar_url text, value double precision)' then
    raise exception 'T2: teaser columns must be rank, display_name, avatar_url, value — got %', cols;
  end if;
  if cols like '%user_id%' or cols like '%country%' then
    raise exception 'T2: teaser must not expose an id or the country: %', cols;
  end if;
  perform pg_temp.pass('T2 row shape is rank, display_name, avatar_url, value — no user_id');
end $$;

-- ---------------------------------------------------------------------------
-- T3  Resort scope: Ischgl lists Frida with her avatar; null / '' resort =
--     every resort (Frida last at rank 13 → not in the top 10); unknown
--     resort → 0 rows; blank season key → 22023.
-- ---------------------------------------------------------------------------
do $$
declare n int; r record; ok boolean := false;
begin
  perform pg_temp.login(null, 'anon');
  select count(*) into n from public.public_board_teaser('test16-ischgl', '2025/26');
  if n <> 1 then raise exception 'T3: ischgl should list one rider, got %', n; end if;
  select * into r from public.public_board_teaser('test16-ischgl', '2025/26');
  if r.display_name <> 'Frida' or r.rank <> 1 or r.avatar_url <> 'https://example.invalid/frida.jpg' then
    raise exception 'T3: ischgl row wrong: %', r;
  end if;
  select count(*) into n from public.public_board_teaser(null, '2025/26');
  if n <> 10 then raise exception 'T3: null resort should still cap at 10, got %', n; end if;
  -- blank resort = every resort (compared with the null board, so real
  -- riders on the live project cannot make this flaky)
  select count(*) into n from (
    (select * from public.public_board_teaser('', '2025/26') except all select * from public.public_board_teaser(null, '2025/26'))
    union all
    (select * from public.public_board_teaser(null, '2025/26') except all select * from public.public_board_teaser('', '2025/26'))
  ) x;
  if n <> 0 then raise exception 'T3: blank resort must mean every resort'; end if;
  select count(*) into n from public.public_board_teaser('nirgendwo', '2025/26');
  if n <> 0 then raise exception 'T3: unknown resort must be empty, got %', n; end if;
  select count(*) into n from public.public_board_teaser('test16-kitz', '2026-01');
  if n <> 10 then raise exception 'T3: month key should rank the January days, got %', n; end if;
  select count(*) into n from public.public_board_teaser('test16-kitz', '2024/25');
  if n <> 0 then raise exception 'T3: another season must be empty, got %', n; end if;
  begin perform public.public_board_teaser('test16-kitz', null);
  exception when sqlstate '22023' then ok := true;
  end;
  if not ok then raise exception 'T3: null season key must raise 22023'; end if;
  ok := false;
  begin perform public.public_board_teaser('test16-kitz', '  ');
  exception when sqlstate '22023' then ok := true;
  end;
  if not ok then raise exception 'T3: blank season key must raise 22023'; end if;
  perform pg_temp.pass('T3 resort scope (ischgl / null / blank / unknown), month key, bad season key');
end $$;

-- ---------------------------------------------------------------------------
-- T4  Grants: anon and authenticated may execute, security definer; the
--     signed-in call sees the same rows (no block in play); the other board
--     RPCs stay closed to anon.
-- ---------------------------------------------------------------------------
do $$
declare n int; denied int := 0;
begin
  reset role;
  if not has_function_privilege('anon', 'public.public_board_teaser(text, text)', 'execute') then
    raise exception 'T4: anon must be able to execute public_board_teaser';
  end if;
  if not has_function_privilege('authenticated', 'public.public_board_teaser(text, text)', 'execute') then
    raise exception 'T4: authenticated must be able to execute public_board_teaser';
  end if;
  if not (select p.prosecdef from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
          where ns.nspname = 'public' and p.proname = 'public_board_teaser') then
    raise exception 'T4: public_board_teaser must be security definer';
  end if;
  perform pg_temp.login(pg_temp.id('rider5'));
  select count(*) into n from public.public_board_teaser('test16-kitz', '2025/26');
  if n <> 10 then raise exception 'T4: authenticated should get 10 rows, got %', n; end if;
  perform pg_temp.login(null, 'anon');
  begin perform public.leaderboard('test16-kitz', '2025/26', 'points', 10, null, 0); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.my_rank('test16-kitz', '2025/26', 'points', null); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.rider_profile(pg_temp.id('rider1')); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T4: anon should still be denied on leaderboard/my_rank/rider_profile, got %', denied; end if;
  perform pg_temp.pass('T4 grants: anon + authenticated execute the teaser, definer; other board RPCs stay closed to anon');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
