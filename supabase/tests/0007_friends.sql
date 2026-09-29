-- Smoke test for migration 0007 (friends) as amended by 0013/0014. One
-- transaction, rolled back at the end (tools/supabase-test.sh; pattern of
-- 0005_rpc_security.sql).
--
-- Seed: Anna (opted in, one day), Bernd (NOT opted in, one day), Chris (opted
-- in, no friends). Friend codes come from the 0007 trigger.

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
  ('anna',  'a0000000-0000-4000-8000-000000000007'),
  ('bernd', 'b0000000-0000-4000-8000-000000000007'),
  ('chris', 'c0000000-0000-4000-8000-000000000007');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

create function pg_temp.code(p_k text) returns text language sql stable security definer as $$
  select p.friend_code::text from public.profiles p where p.id = (select id from t_ids where k = p_k);
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test7.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true,  'DE'),
  (pg_temp.id('bernd'), 'Bernd', false, 'AT'),
  (pg_temp.id('chris'), 'Chris', true,  'DE');

insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values
  (gen_random_uuid(), pg_temp.id('anna'),  '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('bernd'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 12, 4000, 30000, 20, 4000000, 21600000, now());

-- ---------------------------------------------------------------------------
-- T1  Anna adds Bernd by code → pending; Bernd sees it incoming and accepts;
--     friends_board lists Bernd for Anna although he is not opted in; Chris
--     sees neither.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.add_friend_by_code(lower(pg_temp.code('bernd')));
  if r.user_id <> pg_temp.id('bernd') or r.status <> 'pending' or r.incoming or r.display_name <> 'Bernd' then
    raise exception 'T1: add_friend_by_code row wrong: %', r;
  end if;
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('bernd') and status = 'pending' and not incoming;
  if n <> 1 then raise exception 'T1: anna should see her outgoing request'; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'T1: pending is not a friend yet, expected self only, got %', n; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('anna') and status = 'pending' and incoming;
  if n <> 1 then raise exception 'T1: bernd should see the request as incoming'; end if;
  perform public.accept_friend(pg_temp.id('anna'));
  select count(*) into n from public.friends_list() where user_id = pg_temp.id('anna') and status = 'accepted';
  if n <> 1 then raise exception 'T1: accepted status missing for bernd'; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = pg_temp.id('bernd');
  if r is null then raise exception 'T1: bernd (opted out) must appear on anna''s friends_board'; end if;
  if r.rank <> 1 or r.value <> 4000 or r.total <> 2 or r.day_count <> 1 then raise exception 'T1: bernd board row wrong: %', r; end if;
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = pg_temp.id('anna');
  if r.rank <> 2 or r.value <> 3000 then raise exception 'T1: anna board row wrong: %', r; end if;
  -- the public leaderboard still hides bernd (no opt-in)
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0) where user_id = pg_temp.id('bernd');
  if n <> 0 then raise exception 'T1: friendship must not leak bernd onto the public leaderboard'; end if;

  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'T1: chris has no friends → self only, got %', n; end if;
  select count(*) into n from public.friends_list();
  if n <> 0 then raise exception 'T1: chris friends_list must be empty'; end if;
  select count(*) into n from public.friendships;
  if n <> 0 then raise exception 'T1: chris must not read other pairs'' friendships via RLS'; end if;
  perform pg_temp.pass('T1 request → accept → friends_board without opt-in gate; strangers see nothing');
end $$;

-- ---------------------------------------------------------------------------
-- T2  Errors: code_not_found, self, already_friends (both directions);
--     bad metric; anon denied.
-- ---------------------------------------------------------------------------
do $$
declare ok boolean := false; denied int := 0;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin perform public.add_friend_by_code('ZZZZZ2');
  exception when sqlstate 'P0002' then
    if sqlerrm <> 'code_not_found' then raise exception 'T2: wrong message %', sqlerrm; end if; ok := true;
  end;
  if not ok then raise exception 'T2: unknown code must raise code_not_found'; end if;
  ok := false;
  begin perform public.add_friend_by_code(pg_temp.code('anna'));
  exception when sqlstate 'P0004' then
    if sqlerrm <> 'self' then raise exception 'T2: wrong message %', sqlerrm; end if; ok := true;
  end;
  if not ok then raise exception 'T2: own code must raise self'; end if;
  ok := false;
  begin perform public.add_friend_by_code(pg_temp.code('bernd'));
  exception when sqlstate 'P0005' then
    if sqlerrm <> 'already_friends' then raise exception 'T2: wrong message %', sqlerrm; end if; ok := true;
  end;
  if not ok then raise exception 'T2: duplicate must raise already_friends'; end if;
  perform pg_temp.login(pg_temp.id('bernd'));
  ok := false;
  begin perform public.add_friend_by_code(pg_temp.code('anna'));
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T2: duplicate from the other side must raise already_friends'; end if;
  ok := false;
  begin perform public.friends_board('2025/26', 'nope');
  exception when sqlstate '22023' then ok := true;
  end;
  if not ok then raise exception 'T2: bad metric must raise'; end if;
  ok := false;
  begin perform public.accept_friend(pg_temp.id('chris'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: accepting a non-existent request must raise request_not_found'; end if;

  perform pg_temp.login(null, 'anon');
  begin perform public.add_friend_by_code('ABCDEF'); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.accept_friend(pg_temp.id('anna')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.remove_friend(pg_temp.id('anna')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.friends_list(); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.friends_board('2025/26', 'drop_m'); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 5 then raise exception 'T2: anon should be denied 5 times, got %', denied; end if;
  perform pg_temp.pass('T2 code_not_found / self / already_friends / bad_metric / request_not_found; anon denied');
end $$;

-- ---------------------------------------------------------------------------
-- T3  friend_code: alphabet without 0/O/1/I/L, immutable, unique over 1000
--     fresh profiles.
-- ---------------------------------------------------------------------------
do $$
declare c text; n int; total int;
begin
  reset role;
  select friend_code into c from public.profiles where id = pg_temp.id('anna');
  if c !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$' then raise exception 'T3: code format wrong: %', c; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  update public.profiles set friend_code = 'AAAAAA', display_name = 'Anna K.' where id = pg_temp.id('anna');
  reset role;
  select friend_code into c from public.profiles where id = pg_temp.id('anna');
  if c = 'AAAAAA' then raise exception 'T3: friend_code must be immutable from the client'; end if;
  select count(*) into n from public.profiles where id = pg_temp.id('anna') and display_name = 'Anna K.';
  if n <> 1 then raise exception 'T3: the rest of the update must go through'; end if;

  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  select ('f0000000-0000-4000-8000-' || lpad((7000 + i)::text, 12, '0'))::uuid, '00000000-0000-0000-0000-000000000000',
         'authenticated', 'authenticated', 'code' || i || '@test7.slopetrack.invalid', '', now(),
         '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
  from generate_series(1, 1000) i;
  insert into public.profiles (id, display_name)
  select ('f0000000-0000-4000-8000-' || lpad((7000 + i)::text, 12, '0'))::uuid, 'Code ' || i from generate_series(1, 1000) i;
  select count(*), count(distinct friend_code) into total, n from public.profiles
    where display_name like 'Code %';
  if total <> 1000 or n <> 1000 then raise exception 'T3: expected 1000 distinct codes, got % of %', n, total; end if;
  select count(*) into n from public.profiles
    where display_name like 'Code %' and friend_code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$';
  if n <> 0 then raise exception 'T3: % codes outside the alphabet', n; end if;
  perform pg_temp.pass('T3 friend_code alphabet, immutable, 1000 unique codes');
end $$;

-- ---------------------------------------------------------------------------
-- T4  Reverse request accepts; remove_friend works from either side and is
--     idempotent; no direct writes on friendships.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean := false;
begin
  -- Chris asks Anna; Anna adds Chris' code instead of accepting → accepted.
  perform pg_temp.login(pg_temp.id('chris'));
  perform public.add_friend_by_code(pg_temp.code('anna'));
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.add_friend_by_code(pg_temp.code('chris'));
  if r.status <> 'accepted' or not r.incoming then raise exception 'T4: adding the requester''s code must accept: %', r; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 3 then raise exception 'T4: anna should have 2 friends + self, got %', n; end if;

  -- Chris removes Anna (row was created by Chris as user_id)
  perform pg_temp.login(pg_temp.id('chris'));
  perform public.remove_friend(pg_temp.id('anna'));
  perform public.remove_friend(pg_temp.id('anna')); -- idempotent
  select count(*) into n from public.friends_list();
  if n <> 0 then raise exception 'T4: chris should have no friends after remove'; end if;
  -- Anna removes Bernd (row was created by Anna) — decline/unfriend from the other side
  perform pg_temp.login(pg_temp.id('bernd'));
  perform public.remove_friend(pg_temp.id('anna'));
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'T4: anna should be alone again, got %', n; end if;

  begin
    insert into public.friendships (user_id, friend_id) values (pg_temp.id('anna'), pg_temp.id('chris'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T4: direct insert into friendships must be denied'; end if;
  perform pg_temp.pass('T4 reverse request accepts; remove_friend either side, idempotent; no direct writes');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
