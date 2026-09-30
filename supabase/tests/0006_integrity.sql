-- Smoke test for migration 0006 (+0006b) as it stands after 0014/0015: days
-- check constraints and the cross-field `suspicious`, days_guard
-- (too_many_days, rate_limited), profiles hardening, challenges/groups,
-- reports and the storage buckets with the avatars policies. One transaction,
-- rolled back at the end — safe against the live project
-- (tools/supabase-test.sh, pattern of 0005_rpc_security.sql).
--
-- Seed: Anna, Bernd, Chris (all opted in). Every day is written inside the
-- tests by the rider themselves, so constraints and guard see client writes.

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
  ('anna',  'a0000000-0000-4000-8000-000000000006'),
  ('bernd', 'b0000000-0000-4000-8000-000000000006'),
  ('chris', 'c0000000-0000-4000-8000-000000000006');

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

-- One plausible day (5 runs, 1.000 hm, 8 km, 54 km/h, one hour); every test
-- overrides just the column it is about.
create function pg_temp.ins_day(
  p_uid uuid, p_started timestamptz,
  p_id uuid default gen_random_uuid(),
  p_ended timestamptz default null,
  p_run_count int default 5,
  p_drop double precision default 1000,
  p_dist double precision default 8000,
  p_speed double precision default 15,
  p_ski_ms bigint default 2000000,
  p_elapsed bigint default 3600000,
  p_season text default '2025/26'
) returns uuid language sql as $$
  insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                           run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
  values (p_id, p_uid, p_started, coalesce(p_ended, p_started + interval '1 hour'), 'kitzbuehel', 'Kitzbühel', p_season, 'AT',
          p_run_count, p_drop, p_dist, p_speed, p_ski_ms, p_elapsed, now())
  returning id;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test06.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u;

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true, 'DE'),
  (pg_temp.id('bernd'), 'Bernd', true, 'AT'),
  (pg_temp.id('chris'), 'Chris', true, 'CH');

-- ---------------------------------------------------------------------------
-- T1  days check constraints: negative metric, end before start, start in the
--     future, more than 20 h, wrong season key → check_violation each.
-- ---------------------------------------------------------------------------
do $$
declare bad int := 0; a constant uuid := pg_temp.id('anna');
begin
  perform pg_temp.login(a);
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_drop => -1);
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_run_count => -1);
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_ended => '2026-01-10 08:00+01');
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, now() + interval '2 days');
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_elapsed => 20 * 3600 * 1000 + 1);
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_season => '2025-26');
  exception when check_violation then bad := bad + 1; end;
  begin perform pg_temp.ins_day(a, '2026-01-10 09:00+01', p_season => '2026-01');
  exception when check_violation then bad := bad + 1; end;
  if bad <> 7 then raise exception 'T1: % of 7 invalid days were rejected', bad; end if;
  -- the limits themselves are fine: 20 h exactly, start within the next day
  perform pg_temp.ins_day(a, '2026-01-10 04:00+01', p_ended => '2026-01-11 00:00+01', p_elapsed => 20 * 3600 * 1000);
  perform pg_temp.ins_day(a, now() + interval '12 hours');
  perform pg_temp.pass('T1 days check constraints');
end $$;

-- T2  suspicious: the 0001 thresholds plus the cross-field rules of 0006.
do $$
declare a constant uuid := pg_temp.id('anna'); n int; d uuid;
begin
  perform pg_temp.login(a);
  d := pg_temp.ins_day(a, '2026-01-11 09:00+01');
  if (select suspicious from public.days where id = d) then raise exception 'T2: a plausible day must not be suspicious'; end if;
  -- one per rule; different dates so too_many_days stays out of the way
  perform pg_temp.ins_day(a, '2026-01-12 09:00+01', p_speed => 46);                       -- > 45 m/s
  perform pg_temp.ins_day(a, '2026-01-12 11:00+01', p_run_count => 2, p_drop => 3600);    -- > runs × 1500 + 500
  perform pg_temp.ins_day(a, '2026-01-12 13:00+01', p_dist => 20001);                     -- > drop × 20
  perform pg_temp.ins_day(a, '2026-01-13 09:00+01', p_run_count => 31, p_drop => 9000, p_dist => 60000);  -- > one run per 2 min
  perform pg_temp.ins_day(a, '2026-01-13 11:00+01', p_ski_ms => 0);                       -- speed without ski time
  perform pg_temp.ins_day(a, '2026-01-13 13:00+01', p_run_count => 81, p_drop => 14000, p_dist => 90000, p_elapsed => 36000000);  -- > 80 runs
  select count(*) into n from public.days where user_id = a and suspicious
     and (started_at at time zone 'Europe/Vienna')::date in ('2026-01-12', '2026-01-13');
  if n <> 6 then raise exception 'T2: % of 6 implausible days are suspicious', n; end if;
  -- … and they stay off the board: three plausible days so far (two from T1)
  select value into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0) where user_id = a;
  if n is distinct from 3000 then raise exception 'T2: only the three plausible days may count, got % hm', n; end if;
  perform pg_temp.pass('T2 suspicious cross-field rules, excluded from the board');
end $$;

-- ---------------------------------------------------------------------------
-- T3  too_many_days: a fourth non-deleted day on one Vienna date → P0004;
--     deleted days and other riders do not count.
-- ---------------------------------------------------------------------------
do $$
declare b constant uuid := pg_temp.id('bernd'); d1 uuid; bad int := 0; n int;
begin
  perform pg_temp.login(b);
  d1 := pg_temp.ins_day(b, '2026-01-20 09:00+01');
  perform pg_temp.ins_day(b, '2026-01-20 11:00+01');
  perform pg_temp.ins_day(b, '2026-01-20 13:00+01');
  begin perform pg_temp.ins_day(b, '2026-01-20 15:00+01');
  exception when sqlstate 'P0004' then bad := bad + 1; end;
  -- 23:30 UTC on the 19th is 00:30 on the 20th in Vienna
  begin perform pg_temp.ins_day(b, '2026-01-19 23:30+00');
  exception when sqlstate 'P0004' then bad := bad + 1; end;
  if bad <> 2 then raise exception 'T3: the fourth day of a Vienna date must be too_many_days (% of 2)', bad; end if;
  -- 23:30 UTC on the 20th is the 21st in Vienna → fine
  perform pg_temp.ins_day(b, '2026-01-20 23:30+00');

  -- a deleted day frees the slot; bringing it back is the fourth again
  update public.days set deleted_at = now(), device_updated_at = now() + interval '1 second' where id = d1;
  perform pg_temp.ins_day(b, '2026-01-20 15:00+01');
  bad := 0;
  begin update public.days set deleted_at = null, device_updated_at = now() + interval '2 seconds' where id = d1;
  exception when sqlstate 'P0004' then bad := bad + 1; end;
  -- moving another day onto the full date is the fourth as well
  begin update public.days set started_at = '2026-01-20 16:00+01', ended_at = '2026-01-20 17:00+01', device_updated_at = now() + interval '3 seconds'
         where user_id = b and started_at = '2026-01-20 23:30+00';
  exception when sqlstate 'P0004' then bad := bad + 1; end;
  if bad <> 2 then raise exception 'T3: undelete / move onto a full date must be too_many_days (% of 2)', bad; end if;
  select count(*) into n from public.days where user_id = b and deleted_at is null
     and (started_at at time zone 'Europe/Vienna')::date = '2026-01-20';
  if n <> 3 then raise exception 'T3: expected 3 live days on the date, got %', n; end if;

  -- the limit is per rider
  perform pg_temp.login(pg_temp.id('chris'));
  perform pg_temp.ins_day(pg_temp.id('chris'), '2026-01-20 09:00+01');
  perform pg_temp.pass('T3 too_many_days per rider and Vienna date');
end $$;

-- ---------------------------------------------------------------------------
-- T4  rate_limited: the 201st write of an hour → P0005; the counter stays at
--     the limit and is invisible for clients.
-- ---------------------------------------------------------------------------
do $$
declare c constant uuid := pg_temp.id('chris'); n int; ok boolean := false;
begin
  reset role;
  insert into public.day_write_counters (user_id, window_start, writes) values (c, now(), 199)
    on conflict (user_id) do update set window_start = excluded.window_start, writes = excluded.writes;
  perform pg_temp.login(c);
  perform pg_temp.ins_day(c, '2026-01-21 09:00+01');   -- write 200
  begin
    perform pg_temp.ins_day(c, '2026-01-22 09:00+01'); -- write 201
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T4: the 201st write of the hour must be rate_limited'; end if;
  select count(*) into n from public.days where user_id = c and started_at = '2026-01-22 09:00+01';
  if n <> 0 then raise exception 'T4: the rejected day must not land'; end if;
  ok := false;
  begin
    perform count(*) from public.day_write_counters;
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T4: day_write_counters must not be readable for clients'; end if;
  reset role;
  select writes into n from public.day_write_counters where user_id = c;
  if n <> 200 then raise exception 'T4: counter must stay at the limit, got %', n; end if;
  perform pg_temp.pass('T4 rate_limited at the 201st write, counter hidden');
end $$;

-- ---------------------------------------------------------------------------
-- T5  profiles: display name 1…24, avatar https only, own row only.
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); bad int := 0; n int;
begin
  perform pg_temp.login(a);
  begin update public.profiles set display_name = '' where id = a;
  exception when check_violation then bad := bad + 1; end;
  begin update public.profiles set display_name = repeat('x', 25) where id = a;
  exception when check_violation then bad := bad + 1; end;
  begin update public.profiles set avatar_url = 'http://example.invalid/a.jpg' where id = a;
  exception when check_violation then bad := bad + 1; end;
  begin update public.profiles set avatar_url = 'javascript:alert(1)' where id = a;
  exception when check_violation then bad := bad + 1; end;
  if bad <> 4 then raise exception 'T5: % of 4 invalid profile updates were rejected', bad; end if;
  update public.profiles set display_name = repeat('ä', 24), avatar_url = 'https://example.invalid/a.jpg' where id = a;
  update public.profiles set display_name = 'Anna', avatar_url = null where id = a;

  select count(*) into n from public.profiles;
  if n <> 1 then raise exception 'T5: a rider reads only the own profile row, got %', n; end if;
  update public.profiles set display_name = 'Gehackt' where id = pg_temp.id('bernd');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T5: a foreign profile must not be writable'; end if;
  reset role;
  if (select display_name from public.profiles where id = pg_temp.id('bernd')) <> 'Bernd' then
    raise exception 'T5: foreign profile changed';
  end if;
  perform pg_temp.pass('T5 profiles: name 1…24, https avatar, own row only');
end $$;

-- ---------------------------------------------------------------------------
-- T6  challenges are server-made (no client insert, title ≤ 60); groups have
--     2…3 members, only the creator deletes, an old duel is duel_expired and
--     outlives its creator's account (created_by → null).
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); bad int := 0; n int; ok boolean := false;
  g constant uuid := 'd0000000-0000-4000-8000-000000000006';
begin
  perform pg_temp.login(a);
  begin
    insert into public.challenges (title, metric, target, starts_on, ends_on) values ('Meine', 'drop_m', 1, current_date, current_date + 6);
  exception when insufficient_privilege then bad := bad + 1;
  end;
  begin
    update public.challenges set target = 1;
  exception when insufficient_privilege then bad := bad + 1;
  end;
  if bad <> 2 then raise exception 'T6: clients must not write challenges (% of 2)', bad; end if;
  reset role;
  begin
    insert into public.challenges (title, metric, target, starts_on, ends_on) values (repeat('x', 61), 'drop_m', 1, '2026-01-12', '2026-01-18');
  exception when check_violation then ok := true;
  end;
  if not ok then raise exception 'T6: a challenge title longer than 60 must be rejected'; end if;

  bad := 0;
  begin
    insert into public.groups (code, name, day, created_by, max_members) values ('TST906', 'Zu groß', current_date, a, 4);
  exception when check_violation then bad := bad + 1;
  end;
  begin
    insert into public.groups (code, name, day, created_by, max_members) values ('TST906', 'Zu klein', current_date, a, 1);
  exception when check_violation then bad := bad + 1;
  end;
  if bad <> 2 then raise exception 'T6: max_members outside 2…3 must be rejected (% of 2)', bad; end if;
  insert into public.groups (id, code, name, day, created_by) values (g, 'TST006', 'Altes Duell', current_date - 10, a);
  insert into public.group_members (group_id, user_id) values (g, a);
  if (select max_members from public.groups where id = g) <> 3 then raise exception 'T6: max_members default must be 3'; end if;
  if (select confdeltype from pg_constraint where conname = 'groups_created_by_fkey' and conrelid = 'public.groups'::regclass) <> 'n' then
    raise exception 'T6: groups.created_by must be ON DELETE SET NULL';
  end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  ok := false;
  begin
    perform public.join_group('TST006');
  exception when sqlstate 'P0006' then ok := true;
  end;
  if not ok then raise exception 'T6: a ten-day-old duel must be duel_expired'; end if;
  delete from public.groups where id = g;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T6: only the creator may delete a group'; end if;
  perform pg_temp.login(a);
  delete from public.groups where id = g;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'T6: the creator must be able to delete the group'; end if;
  perform pg_temp.pass('T6 challenges read-only, groups 2…3 members, creator deletes, duel_expired');
end $$;

-- ---------------------------------------------------------------------------
-- T7  reports: insert own only, never readable, reason 1…200, no self-report,
--     one per target and day, server-side timestamps.
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); b constant uuid := pg_temp.id('bernd'); c constant uuid := pg_temp.id('chris');
  bad int := 0; denied int := 0; ok boolean := false; r record;
begin
  perform pg_temp.login(a);
  begin insert into public.reports (reporter, target_user_id, reason) values (a, a, 'ich');
  exception when check_violation then bad := bad + 1; end;
  begin insert into public.reports (reporter, target_user_id, reason) values (a, b, '');
  exception when check_violation then bad := bad + 1; end;
  begin insert into public.reports (reporter, target_user_id, reason) values (a, b, repeat('x', 201));
  exception when check_violation then bad := bad + 1; end;
  if bad <> 3 then raise exception 'T7: % of 3 invalid reports were rejected', bad; end if;

  insert into public.reports (reporter, target_user_id, reason) values (a, b, 'cheating');
  -- the client cannot pre-date or pre-handle a report
  insert into public.reports (reporter, target_user_id, reason, created_at, handled_at, report_day)
  values (a, c, repeat('x', 200), '2000-01-01', now(), '2000-01-01');

  begin insert into public.reports (reporter, target_user_id, reason) values (a, b, 'noch einmal');
  exception when unique_violation then ok := true; end;
  if not ok then raise exception 'T7: a second report on the same rider and day must be already_reported'; end if;

  begin insert into public.reports (reporter, target_user_id, reason) values (b, c, 'gefälscht');
  exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.reports;
  exception when insufficient_privilege then denied := denied + 1; end;
  begin update public.reports set reason = 'x' where reporter = a;
  exception when insufficient_privilege then denied := denied + 1; end;
  begin delete from public.reports where reporter = a;
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 4 then raise exception 'T7: forged reporter / read / update / delete denied % of 4', denied; end if;

  reset role;
  select * into r from public.reports where reporter = a and target_user_id = c;
  if r.created_at <> now() or r.handled_at is not null or r.report_day <> (now() at time zone 'Europe/Vienna')::date then
    raise exception 'T7: report timestamps must come from the server: %', r;
  end if;
  if (select count(*) from public.reports where reporter = a) <> 2 then raise exception 'T7: expected exactly 2 reports of anna'; end if;
  perform pg_temp.pass('T7 reports: insert own, no read, limits, server timestamps');
end $$;

-- ---------------------------------------------------------------------------
-- T8  storage: bucket limits; avatars are world-readable and writable only
--     inside the own folder, tracks stay private.
-- ---------------------------------------------------------------------------
do $$
declare a constant uuid := pg_temp.id('anna'); b constant uuid := pg_temp.id('bernd');
  r record; n int; denied int := 0;
begin
  reset role;
  select * into r from storage.buckets where id = 'tracks';
  if r.public or r.file_size_limit <> 20 * 1024 * 1024 or r.allowed_mime_types <> array['application/gzip'] then
    raise exception 'T8: tracks bucket wrong: public=% limit=% mime=%', r.public, r.file_size_limit, r.allowed_mime_types;
  end if;
  select * into r from storage.buckets where id = 'avatars';
  if not r.public or r.file_size_limit <> 2 * 1024 * 1024 or r.allowed_mime_types <> array['image/jpeg', 'image/png'] then
    raise exception 'T8: avatars bucket wrong: public=% limit=% mime=%', r.public, r.file_size_limit, r.allowed_mime_types;
  end if;
  select count(*) into n from pg_policies where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('avatars public read', 'avatars own insert', 'avatars own update', 'avatars own delete');
  if n <> 4 then raise exception 'T8: expected the four avatars policies, got %', n; end if;

  -- newer storage versions refuse SQL deletes unless this is set (no-op elsewhere)
  perform set_config('storage.allow_delete_query', 'true', true);

  perform pg_temp.login(a);
  insert into storage.objects (bucket_id, name, owner) values ('avatars', a || '/avatar.jpg', a);
  insert into storage.objects (bucket_id, name, owner) values ('tracks', a || '/day.json.gz', a);
  begin insert into storage.objects (bucket_id, name, owner) values ('avatars', b || '/avatar.jpg', a);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into storage.objects (bucket_id, name, owner) values ('avatars', 'avatar.jpg', a);
  exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into storage.objects (bucket_id, name, owner) values ('tracks', b || '/day.json.gz', a);
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T8: uploads outside the own folder denied % of 3', denied; end if;

  -- Bernd sees Anna's avatar but not her track, and can change neither
  perform pg_temp.login(b);
  select count(*) into n from storage.objects where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  if n <> 1 then raise exception 'T8: avatars must be readable for every rider'; end if;
  select count(*) into n from storage.objects where bucket_id = 'tracks' and name = a || '/day.json.gz';
  if n <> 0 then raise exception 'T8: a foreign track must stay invisible'; end if;
  update storage.objects set metadata = '{"x": 1}' where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T8: a foreign avatar must not be writable'; end if;
  delete from storage.objects where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T8: a foreign avatar must not be deletable'; end if;

  -- Anna replaces and removes her own, but cannot move it into Bernd's folder
  perform pg_temp.login(a);
  update storage.objects set metadata = '{"x": 1}' where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'T8: the own avatar must be writable'; end if;
  denied := 0;
  begin update storage.objects set name = b || '/stolen.jpg' where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 1 then raise exception 'T8: moving an avatar into a foreign folder must be denied'; end if;
  delete from storage.objects where bucket_id = 'avatars' and name = a || '/avatar.jpg';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'T8: the own avatar must be deletable'; end if;
  perform pg_temp.pass('T8 storage buckets + avatars policies');
end $$;

-- T9  anon gets nothing.
do $$
declare denied int := 0;
begin
  perform pg_temp.login(null, 'anon');
  begin perform count(*) from public.days; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.profiles; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.reports; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.day_write_counters; exception when insufficient_privilege then denied := denied + 1; end;
  begin insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('anna'), pg_temp.id('bernd'), 'anon');
  exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 5 then raise exception 'T9: anon denied % of 5', denied; end if;
  perform pg_temp.pass('T9 anon denied');
end $$;

reset role;
select n, test from t_results order by n;
rollback;
