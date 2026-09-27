-- Smoke test for migration 0005 (RPC security). Runs as postgres inside ONE
-- transaction that is rolled back at the end — nothing is left behind, so it
-- is safe against the live project too (tools/supabase-test.sh runs it locally
-- against `supabase start`; the same file was posted to the Management API).
--
-- Every test switches role with pg_temp.login(<uid>) (= `set role
-- authenticated` + `request.jwt.claims`) and raises on the first failed
-- assertion. On success the last statement lists the passed tests.
--
-- Seed: Anna (DE, opted in, skis in AT), Bernd (AT, opted in), Chris (not
-- opted in), 250 opted-in fillers (CH) with higher totals, one duel Anna+Bernd.

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

-- ---------------------------------------------------------------------------
-- Seed
-- ---------------------------------------------------------------------------
create temporary table t_ids (k text primary key, id uuid not null) on commit drop;
grant select on table t_ids to public;
insert into t_ids values
  ('anna',  'a0000000-0000-4000-8000-000000000001'),
  ('bernd', 'b0000000-0000-4000-8000-000000000002'),
  ('chris', 'c0000000-0000-4000-8000-000000000003'),
  ('duel',  'd0000000-0000-4000-8000-000000000004');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u where u.k <> 'duel';

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select ('f0000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', 'filler' || i || '@test.slopetrack.invalid', '', now(),
       '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
from generate_series(1, 250) i;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true,  'DE'),
  (pg_temp.id('bernd'), 'Bernd', true,  'AT'),
  (pg_temp.id('chris'), 'Chris', false, 'DE');
insert into public.profiles (id, display_name, share_leaderboards, country_code)
select ('f0000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid, 'Filler ' || i, true, 'CH'
from generate_series(1, 250) i;

-- days: season 2025/26, resort kitzbuehel for the three named riders.
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values
  (gen_random_uuid(), pg_temp.id('anna'), '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('anna'), '2026-01-17 09:00+01', '2026-01-17 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 8, 2500, 15000, 17, 3000000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('bernd'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 12, 4000, 30000, 20, 4000000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('chris'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 15, 9000, 50000, 22, 5000000, 21600000, now());
-- fillers: all above Anna and Bernd, other resort
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
select gen_random_uuid(), ('f0000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
       '2026-01-20 09:00+01', '2026-01-20 15:00+01', 'filler-resort', 'Filler', '2025/26', 'CH',
       20, 6000 + i * 10, 40000, 20, 5000000, 21600000, now()
from generate_series(1, 250) i;

insert into public.groups (id, code, name, day, resort_id, created_by, max_members)
values (pg_temp.id('duel'), 'TEST01', 'Testduell', '2026-01-15', null, pg_temp.id('anna'), 3);
insert into public.group_members (group_id, user_id) values
  (pg_temp.id('duel'), pg_temp.id('anna')),
  (pg_temp.id('duel'), pg_temp.id('bernd'));

-- ---------------------------------------------------------------------------
-- T1  Anna sees herself AND Bernd, not Chris; new columns filled.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null);
  if n <> 2 then raise exception 'T1: expected 2 rows in kitzbuehel, got %', n; end if;

  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null) where user_id = pg_temp.id('anna');
  if r.rank <> 1 or r.value <> 5500 or r.total <> 2 then raise exception 'T1: anna row wrong: %', r; end if;
  if r.country_code <> 'DE' then raise exception 'T1: country_code should be DE (team), got %', r.country_code; end if;
  if r.day_count <> 2 then raise exception 'T1: day_count should be 2, got %', r.day_count; end if;
  if r.last_day <> '2026-01-17 09:00+01'::timestamptz then raise exception 'T1: last_day wrong: %', r.last_day; end if;

  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null) where user_id = pg_temp.id('bernd');
  if r.rank <> 2 or r.value <> 4000 then raise exception 'T1: bernd row wrong: %', r; end if;

  if exists (select 1 from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null) where user_id = pg_temp.id('chris')) then
    raise exception 'T1: chris (not opted in) must be absent';
  end if;
  perform pg_temp.pass('T1 leaderboard sees other opted-in riders, hides opted-out');
end $$;

-- ---------------------------------------------------------------------------
-- T2  anon: every board RPC is permission denied.
-- ---------------------------------------------------------------------------
do $$
declare denied int := 0;
begin
  perform pg_temp.login(null, 'anon');
  begin perform public.leaderboard(null, '2025/26', 'drop_m', 10, null);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.my_rank(null, '2025/26', 'drop_m', null);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.country_board('2025/26');
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.group_board(pg_temp.id('duel'));
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.join_group('TEST01');
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 5 then raise exception 'T2: anon should be denied 5 times, got %', denied; end if;
  perform pg_temp.pass('T2 anon is denied on every RPC');
end $$;

-- ---------------------------------------------------------------------------
-- T3  group_board: non-member → 42501; member sees partner totals (not 0).
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('chris'));
  begin
    perform public.group_board(pg_temp.id('duel'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T3: non-member must get 42501'; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 2 then raise exception 'T3: expected 2 members, got %', n; end if;
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('bernd');
  if r.drop_m <> 4000 or r.run_count <> 12 then raise exception 'T3: bernd totals wrong: %', r; end if;
  -- Anna: only the 15.1. counts for the duel day
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('anna');
  if r.drop_m <> 3000 then raise exception 'T3: anna duel-day total wrong: %', r; end if;
  perform pg_temp.pass('T3 group_board: 42501 for non-members, real totals for members');
end $$;

-- ---------------------------------------------------------------------------
-- T4  helpers are not callable as authenticated; policies still work.
-- ---------------------------------------------------------------------------
do $$
declare denied int := 0; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin perform public.is_group_member(pg_temp.id('duel'));
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.shares_group_with(pg_temp.id('bernd'));
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.ensure_weekly_challenges(current_date);
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T4: helpers should be denied 3 times, got %', denied; end if;

  -- RLS still evaluates the (private) helpers without permission errors
  select count(*) into n from public.groups;
  if n <> 1 then raise exception 'T4: anna should read her duel group, got %', n; end if;
  select count(*) into n from public.group_members;
  if n <> 2 then raise exception 'T4: anna should read both members, got %', n; end if;
  select count(*) into n from public.profiles where id = pg_temp.id('anna');
  if n <> 1 then raise exception 'T4: anna should read her own profile'; end if;
  -- (0006 narrows profile reads to the own row; other riders come via RPCs.)
  select count(*) into n from public.days where user_id <> pg_temp.id('anna');
  if n <> 0 then raise exception 'T4: days must stay owner-only via RLS, got %', n; end if;
  if not private.shares_group_with(pg_temp.id('bernd')) then raise exception 'T4: anna shares a duel with bernd'; end if;
  if private.shares_group_with(pg_temp.id('chris')) then raise exception 'T4: anna shares no duel with chris'; end if;

  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.groups;
  if n <> 0 then raise exception 'T4: chris must not read the duel group, got %', n; end if;
  if private.is_group_member(pg_temp.id('duel')) then raise exception 'T4: chris is not a member'; end if;
  perform pg_temp.pass('T4 helpers hidden from clients, RLS policies still work');
end $$;

-- ---------------------------------------------------------------------------
-- T5  Team country: Anna (DE, skied in AT) is under DE, not AT; country_board.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', 200, 'DE') where user_id = pg_temp.id('anna');
  if n <> 1 then raise exception 'T5: anna must appear under p_country=DE'; end if;
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', 200, 'AT') where user_id = pg_temp.id('anna');
  if n <> 0 then raise exception 'T5: anna must not appear under p_country=AT'; end if;
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', 200, 'AT');
  if n <> 1 then raise exception 'T5: AT board should have only bernd, got %', n; end if;

  select * into r from public.country_board('2025/26') where country_code = 'DE';
  if r.riders <> 1 or r.points <> 1090 or r.drop_m <> 5500 then raise exception 'T5: DE row wrong: %', r; end if;
  select * into r from public.country_board('2025/26') where country_code = 'AT';
  if r.riders <> 1 or r.points <> 810 then raise exception 'T5: AT row wrong: %', r; end if;
  select * into r from public.country_board('2025/26') where country_code = 'CH';
  if r.riders <> 250 then raise exception 'T5: CH row wrong: %', r; end if;
  select count(*) into n from public.country_board('2025/26');
  if n <> 3 then raise exception 'T5: expected 3 countries, got %', n; end if;
  perform pg_temp.pass('T5 team country = onboarding country; country_board sums per team');
end $$;

-- ---------------------------------------------------------------------------
-- T6  my_rank outside the top 100; clamp; bad metric; month/week keys.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', 100, null) where user_id = pg_temp.id('anna');
  if n <> 0 then raise exception 'T6: anna should be outside the top 100'; end if;

  select * into r from public.my_rank(null, '2025/26', 'drop_m', null);
  if r is null then raise exception 'T6: my_rank returned nothing'; end if;
  if r.rank <> 251 or r.total <> 252 or r.value <> 5500 then raise exception 'T6: my_rank wrong: %', r; end if;

  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', 1000000000, null);
  if n <> 200 then raise exception 'T6: p_limit 1e9 should clamp to 200, got %', n; end if;
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', -5, null);
  if n <> 1 then raise exception 'T6: p_limit -5 should clamp to 1, got %', n; end if;
  select count(*) into n from public.leaderboard(null, '2025/26', 'drop_m', null, null);
  if n <> 100 then raise exception 'T6: p_limit null should default to 100, got %', n; end if;

  begin
    perform public.leaderboard(null, '2025/26', 'nope', 10, null);
  exception when sqlstate '22023' then
    if sqlerrm <> 'bad_metric' then raise exception 'T6: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T6: bad metric must raise'; end if;
  ok := false;
  begin
    perform public.my_rank(null, '2025/26', 'nope', null);
  exception when sqlstate '22023' then ok := true;
  end;
  if not ok then raise exception 'T6: my_rank bad metric must raise'; end if;

  -- month and ISO-week keys still work (0002)
  select * into r from public.my_rank('kitzbuehel', '2026-01', 'drop_m', null);
  if r.rank <> 1 then raise exception 'T6: month key failed: %', r; end if;
  select * into r from public.my_rank('kitzbuehel', '2026-W03', 'drop_m', null);
  if r.rank <> 1 or r.value <> 5500 then raise exception 'T6: week key failed: %', r; end if;

  -- not ranked: chris is opted out
  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.my_rank(null, '2025/26', 'drop_m', null);
  if n <> 0 then raise exception 'T6: opted-out rider must get zero rows from my_rank'; end if;
  perform pg_temp.pass('T6 my_rank outside top 100, clamp 1..200, bad_metric raises');
end $$;

-- ---------------------------------------------------------------------------
-- T7  Blocks: Anna blocks Bernd → gone for Anna only; RLS on blocks.
-- ---------------------------------------------------------------------------
do $$
declare n int; ok boolean := false; r record;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('anna'), pg_temp.id('bernd'));

  begin
    insert into public.blocks (user_id, blocked_id) values (pg_temp.id('bernd'), pg_temp.id('anna'));
  exception when insufficient_privilege or check_violation then ok := true;
  end;
  if not ok then raise exception 'T7: inserting a block for someone else must fail'; end if;

  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null);
  if n <> 1 then raise exception 'T7: anna should see 1 row after blocking, got %', n; end if;
  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null);
  if r.user_id <> pg_temp.id('anna') or r.total <> 1 then raise exception 'T7: wrong remaining row %', r; end if;
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 1 then raise exception 'T7: anna duel board should hide bernd, got %', n; end if;
  select * into r from public.my_rank(null, '2025/26', 'drop_m', null);
  if r.total <> 251 then raise exception 'T7: total for anna should drop to 251, got %', r.total; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null);
  if n <> 2 then raise exception 'T7: bernd must still see both rows, got %', n; end if;
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 2 then raise exception 'T7: bernd duel board must still show both, got %', n; end if;
  select count(*) into n from public.blocks;
  if n <> 0 then raise exception 'T7: bernd must not read anna''s block row'; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  delete from public.blocks where blocked_id = pg_temp.id('bernd');
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null);
  if n <> 2 then raise exception 'T7: unblock should restore 2 rows, got %', n; end if;
  perform pg_temp.pass('T7 blocks hide the blocked rider for the blocker only');
end $$;

-- ---------------------------------------------------------------------------
-- T8  Grants snapshot: exactly the five client RPCs are executable.
-- ---------------------------------------------------------------------------
do $$
declare bad text;
begin
  reset role;
  -- 0005's own functions: the five client RPCs yes, the helpers no.
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.leaderboard(text, text, text, int, text)', 'public.my_rank(text, text, text, text)',
      'public.country_board(text)', 'public.group_board(uuid)', 'public.join_group(text)']) sig
  where not has_function_privilege('authenticated', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T8: missing client grants: %', bad; end if;
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.is_group_member(uuid, uuid)', 'public.shares_group_with(uuid, uuid)',
      'public.ensure_weekly_challenges(date)', 'private.board(text, text, text, text)']) sig
  where has_function_privilege('authenticated', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T8: helpers must not be client-callable: %', bad; end if;
  -- Later migrations own their grants (0006+), but nobody may grant anon.

  select string_agg(p.proname, ', ' order by p.proname) into bad
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute')
    and p.prorettype <> 'trigger'::regtype;
  if bad is not null then raise exception 'T8: anon must have no grants, has: %', bad; end if;

  select string_agg(p.proname, ', ' order by p.proname) into bad
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in ('leaderboard', 'country_board', 'group_board', 'my_rank', 'join_group')
    and not p.prosecdef;
  if bad is not null then raise exception 'T8: not security definer: %', bad; end if;
  perform pg_temp.pass('T8 grants: only join_group/leaderboard/country_board/group_board/my_rank for authenticated');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
