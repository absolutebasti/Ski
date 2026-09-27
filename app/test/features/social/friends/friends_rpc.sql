-- SQL acceptance test for supabase/migrations/0007_friends.sql (SOC-FRIENDS).
-- Runs as one DO block that always ends in RAISE EXCEPTION, so everything it
-- inserts is rolled back — safe against the live project. The exception text
-- is the report: it starts with 'OK' when every assertion held.
-- (Handlers list SQLSTATEs explicitly: the management API's query endpoint
-- does not honour `when others`.)
--
--   TOKEN=$(security find-generic-password -s "Supabase CLI" -w)
--   POST https://api.supabase.com/v1/projects/<ref>/database/query {"query": <this file>}
--
-- Covers: A adds B by code → pending; B accepts → friends_board(A) lists B
-- although B has share_leaderboards = false; C sees neither A nor B; wrong
-- code → code_not_found; own code → self; duplicate → already_friends;
-- remove_friend; RLS: C cannot read A/B rows; 10 000 profiles get 10 000
-- distinct codes from the alphabet.
do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  code_a text; code_b text;
  r record;
  n int;
  msg text;
  report text := '';
begin
  -- users + profiles (postgres role, bypasses RLS)
  insert into auth.users (id, instance_id, aud, role, email)
    values (a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@test.local'),
           (b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@test.local'),
           (c, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c@test.local');
  insert into public.profiles (id, display_name, share_leaderboards, country_code)
    values (a, 'Anna', true, 'AT'), (b, 'Ben', false, 'DE'), (c, 'Cem', true, 'CH');
  select friend_code into code_a from public.profiles where id = a;
  select friend_code into code_b from public.profiles where id = b;
  if code_a !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$' then raise exception 'FAIL code alphabet %', code_a; end if;
  -- friend_code is immutable from the client side
  update public.profiles set friend_code = 'AAAAAA' where id = a;
  if (select friend_code from public.profiles where id = a) <> code_a then raise exception 'FAIL friend_code mutable'; end if;
  report := report || 'codes ok; ';

  -- B has one plausible day, one suspicious day, one deleted day
  -- elapsed_ms / ski_ms set so the 0006 cross-field plausibility rules pass
  insert into public.days (id, user_id, started_at, ended_at, season_key, drop_m, run_count, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
    values (gen_random_uuid(), b, '2026-01-10 09:00+01', '2026-01-10 15:00+01', '2025/26', 3200, 12, 30000, 20, 7200000, 21600000, now()),
           (gen_random_uuid(), b, '2026-01-11 09:00+01', '2026-01-11 15:00+01', '2025/26', 900, 5, 9000, 60, 3600000, 21600000, now());
  insert into public.days (id, user_id, started_at, ended_at, season_key, drop_m, run_count, ski_distance_m, ski_ms, elapsed_ms, device_updated_at, deleted_at)
    values (gen_random_uuid(), b, '2026-01-12 09:00+01', '2026-01-12 15:00+01', '2025/26', 5000, 9, 40000, 7200000, 21600000, now(), now());

  -- act as A
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select * into r from public.add_friend_by_code(lower(code_b));
  if r.status <> 'pending' or r.user_id <> b or r.display_name <> 'Ben' then raise exception 'FAIL add: %', r; end if;
  if (select status from public.friendships where user_id = a and friend_id = b) <> 'pending' then raise exception 'FAIL pending row'; end if;
  report := report || 'A→B pending; ';

  begin
    perform * from public.add_friend_by_code(code_a); raise exception 'FAIL self accepted';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlerrm <> 'self' then raise exception 'FAIL self: %', sqlerrm; end if;
  end;
  begin
    perform * from public.add_friend_by_code(code_b); raise exception 'FAIL duplicate accepted';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlerrm <> 'already_friends' then raise exception 'FAIL duplicate: %', sqlerrm; end if;
  end;
  begin
    perform * from public.add_friend_by_code('ZZZZZZ'); raise exception 'FAIL unknown code accepted';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlerrm <> 'code_not_found' then raise exception 'FAIL code_not_found: %', sqlerrm; end if;
  end;
  begin
    perform * from public.friends_board('2025/26', 'nope'); raise exception 'FAIL bad metric accepted';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlerrm <> 'bad_metric' then raise exception 'FAIL bad_metric: %', sqlerrm; end if;
  end;
  report := report || 'self/already_friends/code_not_found/bad_metric raise; ';

  -- before acceptance A's board is A alone
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'FAIL board before accept has % rows', n; end if;

  -- B accepts; C tries to accept something that is not there
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  begin
    perform public.accept_friend(a); raise exception 'FAIL C accepted A''s request to B';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlerrm <> 'request_not_found' then raise exception 'FAIL request_not_found: %', sqlerrm; end if;
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.accept_friend(a);
  if (select status from public.friendships where user_id = a and friend_id = b) <> 'accepted' then raise exception 'FAIL accept'; end if;
  -- B's list shows A as accepted, not incoming any more
  select * into r from public.friends_list();
  if r.user_id <> a or r.status <> 'accepted' or r.incoming <> true then raise exception 'FAIL friends_list B: %', r; end if;
  report := report || 'B accepted; ';

  -- A's board lists B (share_leaderboards = false) with the plausible day only
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = b;
  if not found then raise exception 'FAIL B missing from A''s board'; end if;
  if r.value <> 3200 or r.day_count <> 1 or r.rank <> 1 or r.total <> 2 or r.country_code <> 'DE' then raise exception 'FAIL B row: %', r; end if;
  select * into r from public.friends_board('2025/26', 'drop_m') where user_id = a;
  if r.value <> 0 or r.rank <> 2 or r.last_day is not null then raise exception 'FAIL A row: %', r; end if;
  -- month / week keys and other metrics
  select value into r from public.friends_board('2026-01', 'run_count') where user_id = b;
  if r.value <> 12 then raise exception 'FAIL month key'; end if;
  select value into r from public.friends_board('2026-W02', 'day_count') where user_id = b;
  if r.value <> 1 then raise exception 'FAIL week key'; end if;
  select value into r from public.friends_board('2025/26', 'points') where user_id = b;
  if r.value <> round(3200/10.0 + 30000/100.0 + 12*5 + 50) then raise exception 'FAIL points %', r.value; end if;
  report := report || 'board lists B (opted out) with 3200 hm; ';

  -- C is nobody's friend: only self on the board, no friendship rows readable
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  select count(*) into n from public.friends_board('2025/26', 'drop_m') where user_id in (a, b);
  if n <> 0 then raise exception 'FAIL C sees % friend rows', n; end if;
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.friendships;
  if n <> 0 then raise exception 'FAIL RLS: C reads % friendship rows', n; end if;
  begin
    insert into public.friendships (user_id, friend_id) values (c, a); raise exception 'FAIL RLS: C inserted directly';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlstate <> '42501' then raise exception 'FAIL RLS insert: % %', sqlstate, sqlerrm; end if;
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into n from public.friendships;
  if n <> 1 then raise exception 'FAIL RLS: A reads % rows', n; end if;
  perform set_config('role', 'none', true);
  report := report || 'C sees nothing, RLS holds; ';

  -- reverse pending is accepted by adding the code
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  perform * from public.add_friend_by_code(code_a);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select * into r from public.add_friend_by_code((select friend_code from public.profiles where id = c));
  if r.status <> 'accepted' then raise exception 'FAIL reverse accept: %', r; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 3 then raise exception 'FAIL board after reverse accept has % rows', n; end if;

  -- remove_friend (either direction), idempotent
  perform public.remove_friend(b);
  perform public.remove_friend(b);
  if exists (select 1 from public.friendships where a in (user_id, friend_id) and b in (user_id, friend_id)) then raise exception 'FAIL remove'; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 2 then raise exception 'FAIL board after remove has % rows', n; end if;
  report := report || 'remove ok; ';

  -- anon has no execute
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'anon', true);
  begin
    perform * from public.friends_list(); raise exception 'FAIL anon may call friends_list';
  exception when sqlstate 'P0001' or sqlstate 'P0002' or sqlstate 'P0003' or sqlstate 'P0004' or sqlstate 'P0005' or sqlstate '42501' or sqlstate '22023' or sqlstate '23505' or sqlstate '23514' then
    if sqlstate <> '42501' then raise exception 'FAIL anon grant: % %', sqlstate, sqlerrm; end if;
  end;
  perform set_config('role', 'none', true);

  -- 10 000 profiles → 10 000 distinct codes
  insert into auth.users (id, instance_id, aud, role)
    select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated' from generate_series(1, 10000);
  insert into public.profiles (id) select id from auth.users where email is null and aud = 'authenticated' and created_at is null;
  select count(*) as rows_n, count(distinct friend_code) as distinct_n, count(*) filter (where friend_code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$') as bad_n into r from public.profiles;
  if r.rows_n < 10003 or r.rows_n <> r.distinct_n or r.bad_n <> 0 then raise exception 'FAIL uniqueness: % rows, % distinct, % off-alphabet', r.rows_n, r.distinct_n, r.bad_n; end if;
  report := report || format('%s profiles, %s distinct codes, %s off-alphabet', r.rows_n, r.distinct_n, r.bad_n);

  raise exception 'OK: %', report;
end $$;
