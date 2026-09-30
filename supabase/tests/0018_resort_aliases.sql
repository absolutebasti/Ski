-- Smoke test for migration 0018 (resort_aliases, canonicalising triggers,
-- backfill, private.board resolving alias ids). One transaction, rolled back
-- at the end (tools/supabase-test.sh; pattern of 0013_rangliste.sql).
--
-- Seed: Anna skis in Lech (old id 'lech-zuers', alias of 'st-anton'), Bernd in
-- St. Anton ('st-anton'), both opted in. A third day is planted with an alias
-- id behind the trigger's back (trigger disabled) to exercise the backfill.

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
  ('anna',  'a0000000-0000-4000-8000-000000000018'),
  ('bernd', 'b0000000-0000-4000-8000-000000000018'),
  ('chris', 'c0000000-0000-4000-8000-000000000018');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test18.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true, 'DE'),
  (pg_temp.id('bernd'), 'Bernd', true, 'AT'),
  (pg_temp.id('chris'), 'Chris', true, 'CH');

-- ---------------------------------------------------------------------------
-- T1  The importer's pairs are in: Arlberg and Damüls variants resolve, chains
--     are flat, the table and helper carry no client grant.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  if private.canonical_resort('lech-zuers') <> 'st-anton' then raise exception 'T1: lech-zuers → %', private.canonical_resort('lech-zuers'); end if;
  if private.canonical_resort('warth-schrocken-at-29248a') <> 'st-anton' then raise exception 'T1: warth-schrocken'; end if;
  if private.canonical_resort('damuls-at-4f8cc7') <> 'skigebiet-damuls-mellau-faschina-at-da710e'
     or private.canonical_resort('skigebiet-damuls-mellau-at-f83cb9') <> 'skigebiet-damuls-mellau-faschina-at-da710e' then
    raise exception 'T1: Damüls variants do not resolve';
  end if;
  if private.canonical_resort('kitzbuehel') <> 'kitzbuehel' then raise exception 'T1: canonical id must pass through'; end if;
  if private.canonical_resort(null) is not null then raise exception 'T1: null must stay null'; end if;
  select count(*) into n from public.resort_aliases a join public.resort_aliases b on b.alias_id = a.canonical_id;
  if n <> 0 then raise exception 'T1: % alias chains', n; end if;
  if has_table_privilege('authenticated', 'public.resort_aliases', 'select')
     or has_table_privilege('anon', 'public.resort_aliases', 'select') then
    raise exception 'T1: resort_aliases must not be readable by clients';
  end if;
  if has_function_privilege('authenticated', 'private.canonical_resort(text)', 'execute') then
    raise exception 'T1: canonical_resort must not be a client RPC';
  end if;
  perform pg_temp.pass('T1 alias pairs (Arlberg, Damüls) resolve, no chains, no client grants');
end $$;

-- ---------------------------------------------------------------------------
-- T2  A client write with an alias id is stored under the canonical id
--     (days and profiles.home_resort_id).
-- ---------------------------------------------------------------------------
do $$
declare v text;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                           run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
  values ('a1000000-0000-4000-8000-000000000018', pg_temp.id('anna'), '2026-01-15 09:00+01', '2026-01-15 15:00+01',
          'lech-zuers', 'Lech Zürs', '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now());
  update public.profiles set home_resort_id = 'lech-zuers' where id = pg_temp.id('anna');
  reset role;
  select resort_id into v from public.days where id = 'a1000000-0000-4000-8000-000000000018';
  if v <> 'st-anton' then raise exception 'T2: day stored as %', v; end if;
  select home_resort_id into v from public.profiles where id = pg_temp.id('anna');
  if v <> 'st-anton' then raise exception 'T2: home resort stored as %', v; end if;
  perform pg_temp.pass('T2 alias ids are canonicalised on write (days, home resort)');
end $$;

-- ---------------------------------------------------------------------------
-- T3  Backfill: a day that still carries an alias (written before 0018) counts
--     on the canonical board after the migration's UPDATE.
-- ---------------------------------------------------------------------------
alter table public.days disable trigger days_canonical_resort;
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values ('b1000000-0000-4000-8000-000000000018', pg_temp.id('bernd'), '2026-01-16 09:00+01', '2026-01-16 15:00+01',
        'warth-schrocken-at-29248a', 'Warth-Schröcken', '2025/26', 'AT', 8, 2000, 15000, 20, 3000000, 21600000, now()),
       ('c1000000-0000-4000-8000-000000000018', pg_temp.id('chris'), '2026-01-16 09:00+01', '2026-01-16 15:00+01',
        'damuls-at-4f8cc7', 'Damüls', '2025/26', 'AT', 5, 1000, 8000, 15, 2000000, 21600000, now());
alter table public.days enable trigger days_canonical_resort;

do $$
declare v text; n int;
begin
  select resort_id into v from public.days where id = 'b1000000-0000-4000-8000-000000000018';
  if v <> 'warth-schrocken-at-29248a' then raise exception 'T3: seed must keep the alias, got %', v; end if;
  -- the migration's backfill statement
  update public.days d set resort_id = a.canonical_id from public.resort_aliases a where d.resort_id = a.alias_id;
  select count(*) into n from public.days d join public.resort_aliases a on a.alias_id = d.resort_id
   where d.user_id in (select id from t_ids);
  if n <> 0 then raise exception 'T3: % seeded days still carry an alias', n; end if;
  select resort_id into v from public.days where id = 'c1000000-0000-4000-8000-000000000018';
  if v <> 'skigebiet-damuls-mellau-faschina-at-da710e' then raise exception 'T3: Damüls day backfilled to %', v; end if;

  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.leaderboard('st-anton', '2025/26', 'drop_m')
   where user_id in (pg_temp.id('anna'), pg_temp.id('bernd'));
  if n <> 2 then raise exception 'T3: st-anton board should hold Anna and Bernd, got %', n; end if;
  select count(*) into n from public.leaderboard('st-anton', '2025/26', 'drop_m') where user_id = pg_temp.id('chris');
  if n <> 0 then raise exception 'T3: Damüls day must not count on st-anton'; end if;
  reset role;
  perform pg_temp.pass('T3 backfilled alias day counts on the canonical board');
end $$;

-- ---------------------------------------------------------------------------
-- T4  An old client asking for an alias board gets the canonical board;
--     re-running the backfill is a no-op.
-- ---------------------------------------------------------------------------
do $$
declare n int; a int; b int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into a from public.leaderboard('lech-zuers', '2025/26', 'drop_m') where user_id in (select id from t_ids);
  select count(*) into b from public.leaderboard('st-anton', '2025/26', 'drop_m') where user_id in (select id from t_ids);
  if a <> 2 or a <> b then raise exception 'T4: alias board % rows, canonical %', a, b; end if;
  select count(*) into n from public.leaderboard('skigebiet-damuls-mellau-at-f83cb9', '2025/26', 'drop_m') where user_id = pg_temp.id('chris');
  if n <> 1 then raise exception 'T4: Damüls alias board must show Chris'; end if;
  reset role;
  update public.days d set resort_id = a2.canonical_id from public.resort_aliases a2 where d.resort_id = a2.alias_id;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T4: second backfill touched % rows', n; end if;
  perform pg_temp.pass('T4 alias board = canonical board, backfill re-run is a no-op');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
