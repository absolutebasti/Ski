-- Smoke test for migration 0013 (add_friend_by_id, friends_* without blocked
-- riders, team country on friends_board, leaderboard p_offset, trigger helpers
-- without client grant) with the 0014 block rules. One transaction, rolled
-- back at the end (tools/supabase-test.sh; pattern of 0005_rpc_security.sql).
--
-- Seed: Anna (DE), Bernd (no team country, skis in AT), Chris (CH), all opted
-- in with one day each in Kitzbühel, values 3000 > 2000 > 1000.

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
  ('anna',  'a0000000-0000-4000-8000-000000000013'),
  ('bernd', 'b0000000-0000-4000-8000-000000000013'),
  ('chris', 'c0000000-0000-4000-8000-000000000013');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test13.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true, 'DE'),
  (pg_temp.id('bernd'), 'Bernd', true, null),
  (pg_temp.id('chris'), 'Chris', true, 'CH');

insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values
  (gen_random_uuid(), pg_temp.id('anna'),  '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('bernd'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 8, 2000, 15000, 20, 3000000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('chris'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'CH', 5, 1000, 8000, 15, 2000000, 21600000, now());

-- ---------------------------------------------------------------------------
-- T1  add_friend_by_id: self, unknown, pending, duplicate, reverse accepts.
-- ---------------------------------------------------------------------------
do $$
declare r record; ok boolean := false; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin perform public.add_friend_by_id(pg_temp.id('anna'));
  exception when sqlstate 'P0004' then ok := true;
  end;
  if not ok then raise exception 'T1: self must raise'; end if;
  ok := false;
  begin perform public.add_friend_by_id('00000000-0000-4000-8000-0000000000ff');
  exception when sqlstate 'P0002' then
    if sqlerrm <> 'rider_not_found' then raise exception 'T1: wrong message %', sqlerrm; end if; ok := true;
  end;
  if not ok then raise exception 'T1: unknown id must raise rider_not_found'; end if;
  ok := false;
  begin perform public.add_friend_by_id(null);
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T1: null id must raise rider_not_found'; end if;

  select * into r from public.add_friend_by_id(pg_temp.id('bernd'));
  if r.status <> 'pending' or r.incoming or r.display_name <> 'Bernd' then raise exception 'T1: pending row wrong: %', r; end if;
  ok := false;
  begin perform public.add_friend_by_id(pg_temp.id('bernd'));
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T1: duplicate must raise already_friends'; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  select * into r from public.add_friend_by_id(pg_temp.id('anna'));
  if r.status <> 'accepted' or not r.incoming then raise exception 'T1: reverse add must accept: %', r; end if;
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('anna') and status = 'accepted';
  if n <> 1 then raise exception 'T1: friendship must be accepted now'; end if;
  perform pg_temp.pass('T1 add_friend_by_id: self / unknown / pending / duplicate / reverse accepts');
end $$;

-- ---------------------------------------------------------------------------
-- T2  Blocked riders vanish from friends_list and friends_board both ways;
--     add_friend_by_id across a block → rider_not_found.
-- ---------------------------------------------------------------------------
do $$
declare n int; ok boolean := false;
begin
  -- Anna ↔ Chris become friends too
  perform pg_temp.login(pg_temp.id('chris'));
  perform public.add_friend_by_id(pg_temp.id('anna'));
  perform pg_temp.login(pg_temp.id('anna'));
  perform public.accept_friend(pg_temp.id('chris'));
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 3 then raise exception 'T2: anna should see 3 on friends_board, got %', n; end if;

  -- Chris blocks Anna
  perform pg_temp.login(pg_temp.id('chris'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('chris'), pg_temp.id('anna'));
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('anna');
  if n <> 0 then raise exception 'T2: chris must not list anna'; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'T2: chris friends_board should be self only, got %', n; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('chris');
  if n <> 0 then raise exception 'T2: anna must not list chris'; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 2 then raise exception 'T2: anna friends_board should be anna + bernd, got %', n; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m') where user_id = pg_temp.id('bernd');
  if n <> 1 then raise exception 'T2: bernd must stay on anna''s friends_board'; end if;
  begin perform public.add_friend_by_id(pg_temp.id('chris'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: adding a rider across a block must raise rider_not_found'; end if;
  -- blocker side too
  perform pg_temp.login(pg_temp.id('chris'));
  ok := false;
  begin perform public.add_friend_by_id(pg_temp.id('anna'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: the blocker cannot add the blocked rider either'; end if;
  delete from public.blocks where blocked_id = pg_temp.id('anna');
  perform pg_temp.pass('T2 friends_list/friends_board hide blocked pairs both ways; add across block → rider_not_found');
end $$;

-- ---------------------------------------------------------------------------
-- T3  friends_board ranks with the team country: Bernd has no profile
--     country → skied-in AT; Anna's DE from the profile.
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = pg_temp.id('bernd');
  if r.country_code is distinct from 'AT' then raise exception 'T3: bernd team country should fall back to AT, got %', r.country_code; end if;
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = pg_temp.id('anna');
  if r.country_code is distinct from 'DE' or r.rank <> 1 then raise exception 'T3: anna row wrong: %', r; end if;
  select * into r from public.friends_board('2026-01', 'run_count') where user_id = pg_temp.id('bernd');
  if r.value <> 8 then raise exception 'T3: month key / run_count wrong: %', r; end if;
  select * into r from public.friends_board('2024/25', 'drop_m') where user_id = pg_temp.id('bernd');
  if r.value <> 0 or r.day_count <> 0 then raise exception 'T3: friend without days must be listed with 0: %', r; end if;
  perform pg_temp.pass('T3 friends_board team country fallback, month key, zero rows for friends without days');
end $$;

-- ---------------------------------------------------------------------------
-- T4  leaderboard p_offset: window around the own rank; clamps.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('chris'));
  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 1, null, 1);
  if r.rank <> 2 or r.user_id <> pg_temp.id('bernd') or r.total <> 3 then raise exception 'T4: offset 1 limit 1 wrong: %', r; end if;
  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 1, null, -5);
  if r.rank <> 1 then raise exception 'T4: negative offset must clamp to 0: %', r; end if;
  select * into r from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 1, null, null);
  if r.rank <> 1 then raise exception 'T4: null offset must be 0: %', r; end if;
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 3);
  if n <> 0 then raise exception 'T4: offset past the end must be empty, got %', n; end if;
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 0, null, 0);
  if n <> 1 then raise exception 'T4: p_limit 0 clamps to 1, got %', n; end if;
  select * into r from public.my_rank('kitzbuehel', '2025/26', 'drop_m', null);
  if r.rank <> 3 or r.total <> 3 then raise exception 'T4: my_rank for chris wrong: %', r; end if;
  perform pg_temp.pass('T4 leaderboard p_offset window and clamps');
end $$;

-- ---------------------------------------------------------------------------
-- T5  Grants: new_friend_code / profiles_set_friend_code not callable;
--     add_friend_by_id granted; anon denied.
-- ---------------------------------------------------------------------------
do $$
declare bad text; denied int := 0;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin perform public.new_friend_code(); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 1 then raise exception 'T5: new_friend_code must be denied for authenticated'; end if;
  perform pg_temp.login(null, 'anon');
  begin perform public.add_friend_by_id(pg_temp.id('anna')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 10, null, 0); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T5: anon should be denied twice, got %', denied - 1; end if;
  reset role;
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.new_friend_code()', 'public.profiles_set_friend_code()']) sig
  where has_function_privilege('authenticated', to_regprocedure(sig), 'execute')
     or has_function_privilege('anon', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T5: must not be client-callable: %', bad; end if;
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.add_friend_by_id(uuid)', 'public.friends_list()', 'public.friends_board(text, text)',
      'public.leaderboard(text, text, text, int, text, int)']) sig
  where not has_function_privilege('authenticated', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T5: missing client grants: %', bad; end if;
  perform pg_temp.pass('T5 trigger helpers hidden, client RPCs granted, anon denied');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
