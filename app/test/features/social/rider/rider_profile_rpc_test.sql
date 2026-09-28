-- SQL smoke test for rider_profile() (supabase/migrations/0008_rider_profile.sql).
--
-- Runs as ONE DO block: it seeds three riders (A opted in, B private, C = the
-- caller), one duel group (B + C), one day per rider, then calls the RPC as C
-- with request.jwt.claims set. The block always ends in RAISE EXCEPTION, so
-- nothing it inserted survives — on success the message starts with
-- RIDER_PROFILE_TEST_OK, on failure the failed assertion is the message.
--
-- Run: app/test/features/social/rider/rider_profile_rpc_test.sh (live project
-- via the Supabase management API; Docker is not needed).
do $t$
declare
  a uuid := gen_random_uuid(); -- opted-in stranger
  b uuid := gen_random_uuid(); -- private, but in a duel with c
  x uuid := gen_random_uuid(); -- private stranger
  c uuid := gen_random_uuid(); -- the caller
  g uuid;
  r record;
  n int;
  season text;
begin
  -- Workaround (rolled back with the block): 0007's profiles_set_friend_code
  -- trigger runs with search_path = public but gen_random_bytes lives in
  -- extensions, so every profile insert fails on the live project. Shim it
  -- here so this test can seed profiles; the real fix belongs to 0007.
  if to_regprocedure('public.gen_random_bytes(integer)') is null and to_regprocedure('extensions.gen_random_bytes(integer)') is not null then
    create function public.gen_random_bytes(integer) returns bytea language sql as 'select extensions.gen_random_bytes($1)';
  end if;

  insert into auth.users (id) values (a), (b), (x), (c);
  insert into public.profiles (id, display_name, share_leaderboards, country_code, home_resort_id)
  values (a, 'Lena Bergmann', true, 'AT', 'kitzbuehel'),
         (b, 'Paul Moser', false, 'DE', null),
         (x, 'Nina Aigner', false, 'CH', null),
         (c, 'Caller', false, 'AT', null);

  season := case when extract(month from now() at time zone 'Europe/Vienna') >= 7
                 then extract(year from now() at time zone 'Europe/Vienna')::int
                 else extract(year from now() at time zone 'Europe/Vienna')::int - 1 end;
  season := season || '/' || lpad(((season::int + 1) % 100)::text, 2, '0');

  -- A: two consecutive plausible days this season + one old day + one suspicious day.
  insert into public.days (id, user_id, started_at, ended_at, resort_id, season_key, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, device_updated_at, country_code)
  values
    (gen_random_uuid(), a, now() - interval '2 days', now() - interval '2 days' + interval '5 hours', 'kitzbuehel', season, 12, 3000, 30000, 20, 3600000, now(), 'AT'),
    (gen_random_uuid(), a, now() - interval '1 day',  now() - interval '1 day'  + interval '5 hours', 'ischgl',     season, 10, 2500, 25000, 22, 3600000, now(), 'AT'),
    (gen_random_uuid(), a, now() - interval '400 days', now() - interval '400 days' + interval '5 hours', 'ischgl', '2000/01', 8, 2000, 20000, 18, 3600000, now(), 'CH'),
    (gen_random_uuid(), a, now() - interval '10 days', now() - interval '10 days' + interval '5 hours', 'ischgl', season, 90, 20000, 50000, 50, 3600000, now(), 'AT');
  insert into public.days (id, user_id, started_at, ended_at, resort_id, season_key, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, device_updated_at, country_code)
  values (gen_random_uuid(), b, now() - interval '1 day', now() - interval '1 day' + interval '4 hours', 'kitzbuehel', season, 7, 1800, 18000, 17, 3000000, now(), 'AT');

  -- duel group with B and C
  insert into public.groups (code, name, day, created_by) values ('TESTAA', 'Test', current_date, b) returning id into g;
  insert into public.group_members (group_id, user_id) values (g, b), (g, c);

  -- 1. signed out → 42501
  perform set_config('request.jwt.claims', '', true);
  begin
    perform * from public.rider_profile(a);
    raise exception 'FAIL: signed-out call did not raise';
  exception when insufficient_privilege then null;
  end;

  -- act as C
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);

  -- 2. opted-in stranger → row with the right totals
  select * into r from public.rider_profile(a);
  if r.user_id is null then raise exception 'FAIL: opted-in stranger returned no row'; end if;
  if r.display_name <> 'Lena Bergmann' or r.country_code <> 'AT' or r.home_resort_id <> 'kitzbuehel' then raise exception 'FAIL: identity columns %', r; end if;
  if r.season_key <> season then raise exception 'FAIL: season_key % <> %', r.season_key, season; end if;
  if r.season_drop_m <> 5500 then raise exception 'FAIL: season_drop_m % (suspicious day must not count)', r.season_drop_m; end if;
  if r.season_ski_distance_m <> 55000 then raise exception 'FAIL: season_ski_distance_m %', r.season_ski_distance_m; end if;
  if r.season_run_count <> 22 then raise exception 'FAIL: season_run_count %', r.season_run_count; end if;
  if r.season_day_count <> 3 then raise exception 'FAIL: season_day_count % (day count includes the suspicious day)', r.season_day_count; end if;
  if r.season_points <> (round(3000/10.0 + 30000/100.0 + 12*5 + 50) + round(2500/10.0 + 25000/100.0 + 10*5 + 50)) then raise exception 'FAIL: season_points %', r.season_points; end if;
  if r.lifetime_drop_m <> 7500 then raise exception 'FAIL: lifetime_drop_m %', r.lifetime_drop_m; end if;
  if r.lifetime_ski_distance_m <> 75000 then raise exception 'FAIL: lifetime_ski_distance_m %', r.lifetime_ski_distance_m; end if;
  if r.lifetime_run_count <> 30 then raise exception 'FAIL: lifetime_run_count %', r.lifetime_run_count; end if;
  if r.lifetime_day_count <> 4 then raise exception 'FAIL: lifetime_day_count %', r.lifetime_day_count; end if;
  if r.lifetime_max_speed_ms <> 22 then raise exception 'FAIL: lifetime_max_speed_ms % (suspicious 50 must not win)', r.lifetime_max_speed_ms; end if;
  if r.best_day_drop_m <> 3000 or r.best_day_run_count <> 12 then raise exception 'FAIL: best day % / %', r.best_day_drop_m, r.best_day_run_count; end if;
  if abs(r.lifetime_avg_ski_speed_ms - 75000 / (3 * 3600.0)) > 1e-6 then raise exception 'FAIL: avg speed %', r.lifetime_avg_ski_speed_ms; end if;
  if r.longest_streak <> 2 then raise exception 'FAIL: longest_streak %', r.longest_streak; end if;
  if r.resort_count <> 2 or r.country_count <> 2 then raise exception 'FAIL: resorts % countries %', r.resort_count, r.country_count; end if;
  if r.last_day is null or r.last_day < now() - interval '2 days' then raise exception 'FAIL: last_day %', r.last_day; end if;

  -- 3. private stranger → empty
  select count(*) into n from public.rider_profile(x);
  if n <> 0 then raise exception 'FAIL: private stranger visible (% rows)', n; end if;

  -- 4. duel partner (private) → row
  select * into r from public.rider_profile(b);
  if r.user_id is null or r.display_name <> 'Paul Moser' then raise exception 'FAIL: duel partner not visible'; end if;
  if r.season_drop_m <> 1800 or r.lifetime_day_count <> 1 then raise exception 'FAIL: duel partner totals %', r; end if;

  -- 5. own profile → row (self is always visible), unknown id → empty
  select count(*) into n from public.rider_profile(c);
  if n <> 1 then raise exception 'FAIL: own profile rows %', n; end if;
  select count(*) into n from public.rider_profile(gen_random_uuid());
  if n <> 0 then raise exception 'FAIL: unknown id rows %', n; end if;

  -- 6. friendship (0007, if present): accepted → visible, pending → not
  if to_regclass('public.friendships') is not null then
    insert into public.friendships (user_id, friend_id, status) values (c, x, 'pending');
    select count(*) into n from public.rider_profile(x);
    if n <> 0 then raise exception 'FAIL: pending friendship made the profile visible'; end if;
    update public.friendships set status = 'accepted' where user_id = c and friend_id = x;
    select count(*) into n from public.rider_profile(x);
    if n <> 1 then raise exception 'FAIL: accepted friendship did not make the profile visible (% rows)', n; end if;
  end if;

  -- 7. grants: anon has no execute, authenticated has
  if has_function_privilege('anon', 'public.rider_profile(uuid)', 'execute') then raise exception 'FAIL: anon may execute'; end if;
  if not has_function_privilege('authenticated', 'public.rider_profile(uuid)', 'execute') then raise exception 'FAIL: authenticated may not execute'; end if;

  raise exception 'RIDER_PROFILE_TEST_OK: 7 checks passed (signed-out 42501, opted-in stranger, private stranger empty, duel partner, self/unknown, friendship pending/accepted, grants); all test rows rolled back';
end $t$;
