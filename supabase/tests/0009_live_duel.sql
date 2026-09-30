begin;
create temporary table t_results (n serial, test text) on commit drop;
grant all on table t_results to public;
grant all on sequence t_results_n_seq to public;
create function pg_temp.login(p_uid uuid, p_role text default 'authenticated') returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', case when p_uid is null then json_build_object('role', p_role)::text else json_build_object('sub', p_uid, 'role', p_role)::text end, true);
  perform set_config('role', p_role, true);
end; $$;
create function pg_temp.pass(p_test text) returns void language sql as $$ insert into t_results (test) values (p_test); $$;
create temporary table t_ids (k text primary key, id uuid not null) on commit drop;
grant select on table t_ids to public;
insert into t_ids values
  ('anna',  'a0000000-0000-4000-8000-000000000009'),
  ('bernd', 'b0000000-0000-4000-8000-000000000009'),
  ('chris', 'c0000000-0000-4000-8000-000000000009'),
  ('duel',  'd0000000-0000-4000-8000-000000000009'),
  ('duel2', 'd0000000-0000-4000-8000-000000000019'),
  ('duelco','d0000000-0000-4000-8000-000000000029');
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t_ids where k = p_k; $$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u.k || '@test9.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
from t_ids u where u.k in ('anna','bernd','chris');
insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'), 'Anna', true, 'DE'), (pg_temp.id('bernd'), 'Bernd', true, 'AT'), (pg_temp.id('chris'), 'Chris', false, 'DE');
-- All fixtures hang off the duel day D = current_date - 1 (yesterday, server clock = UTC):
--  * D lies inside the 0015 live_days window (current_date ± 1), so no constraint is lifted;
--  * every started_at is ≤ now() + 1 day (0006 days_started_not_future) — the latest one,
--    D 20:00 Denver, is at most 03:00 UTC of today.
-- No ALTER TABLE / DISABLE TRIGGER: the file takes no table lock beyond ordinary row writes.
create function pg_temp.d() returns date language sql stable as $$ select current_date - 1; $$;
create function pg_temp.at(p_time time, p_tz text) returns timestamptz language sql stable as $$
  select (pg_temp.d() + p_time) at time zone p_tz;
$$;
-- Bernd: finished day D in kitzbuehel. Group bound to 'ischgl' → must be ignored.
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values (gen_random_uuid(), pg_temp.id('bernd'), pg_temp.at('09:30', 'Europe/Vienna'), pg_temp.at('15:30', 'Europe/Vienna'), 'kitzbuehel', 'Kitzbühel', '2025/26', 'AT', 12, 4000, 30000, 20, 4000000, 21600000, now());
insert into public.groups (id, code, name, day, resort_id, created_by, max_members)
values (pg_temp.id('duel'), 'TST009', 'Testduell', pg_temp.d(), 'ischgl', pg_temp.id('anna'), 3),
       (pg_temp.id('duel2'), 'TST010', 'Älteres Duell', pg_temp.d() - 5, null, pg_temp.id('anna'), 3);
insert into public.groups (id, code, name, day, resort_id, created_by, max_members, tz)
values (pg_temp.id('duelco'), 'TST011', 'Colorado', pg_temp.d(), null, pg_temp.id('anna'), 3, 'America/Denver');
insert into public.group_members (group_id, user_id) values
  (pg_temp.id('duel'), pg_temp.id('anna')), (pg_temp.id('duel'), pg_temp.id('bernd')),
  (pg_temp.id('duel2'), pg_temp.id('anna')), (pg_temp.id('duel2'), pg_temp.id('bernd')),
  (pg_temp.id('duelco'), pg_temp.id('anna')), (pg_temp.id('duelco'), pg_temp.id('bernd'));
-- Anna: live row only (updated_at is overwritten by the server clock).
insert into public.live_days (user_id, day, resort_id, drop_m, run_count, ski_distance_m, max_speed_ms, updated_at)
values (pg_temp.id('anna'), pg_temp.d(), 'kitzbuehel', 1200, 5, 9000, 15, '2000-01-01');
-- Bernd's Colorado day: D 20:00 Denver = D+1 03:00–05:00 Vienna (DST offsets) → not on D in Vienna.
insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values (gen_random_uuid(), pg_temp.id('bernd'), pg_temp.at('20:00', 'America/Denver'), pg_temp.at('23:00', 'America/Denver'), 'aspen', 'Aspen', '2025/26', 'US', 3, 777, 5000, 14, 1000000, 10800000, now());

-- T1 live row for Anna, finished for Bernd; then Anna's finished day wins.
do $$
declare r record; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 2 then raise exception 'T1: expected 2 rows, got %', n; end if;
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('anna');
  if r.drop_m <> 1200 or r.run_count <> 5 or not r.is_live then raise exception 'T1: anna live row wrong: %', r; end if;
  if r.updated_at < now() - interval '1 minute' then raise exception 'T1: updated_at must be server-set, got %', r.updated_at; end if;
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('bernd');
  if r.drop_m <> 4000 or r.is_live then raise exception 'T1: bernd finished row wrong: %', r; end if;
  reset role;
  insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code, run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
  values (gen_random_uuid(), pg_temp.id('anna'), pg_temp.at('09:00', 'Europe/Vienna'), pg_temp.at('15:00', 'Europe/Vienna'), 'kitzbuehel', 'Kitzbühel', '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now());
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('anna');
  if r.drop_m <> 3000 or r.is_live then raise exception 'T1: finished day must win: %', r; end if;
  perform pg_temp.pass('T1 live row shown with is_live, finished day wins');
end $$;

-- T2 resort filter gone (group is ischgl, days are kitzbuehel) — covered by T1 values ≠ 0; assert explicitly.
do $$
declare n int;
begin
  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.group_board(pg_temp.id('duel')) where drop_m > 0;
  if n <> 2 then raise exception 'T2: resort filter still active, %', n; end if;
  perform pg_temp.pass('T2 group_board ignores resort_id');
end $$;

-- T3 Colorado tz: Bernd's day at 20:00 Denver on the 15th counts for the Denver group, not for the Vienna one.
do $$
declare r record;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.group_board(pg_temp.id('duelco')) where user_id = pg_temp.id('bernd');
  if r.drop_m <> 4777 then raise exception 'T3: denver day not matched: %', r; end if;
  select * into r from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('bernd');
  if r.drop_m <> 4000 then raise exception 'T3: vienna group must not include the denver day: %', r; end if;
  perform pg_temp.pass('T3 g.tz matches a Colorado day');
end $$;

-- T4 my_duels: day desc, board jsonb, member_count.
do $$
declare r record; n int; first_day date;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.my_duels(20) where code like 'TST0%';
  if n <> 3 then raise exception 'T4: expected 3 duels, got %', n; end if;
  select day into first_day from public.my_duels(20) where code like 'TST0%' limit 1;
  if first_day <> pg_temp.d() then raise exception 'T4: newest first, got %', first_day; end if;
  select * into r from public.my_duels(20) where code = 'TST009';
  if r.member_count <> 2 or jsonb_array_length(r.board) <> 2 or r.tz <> 'Europe/Vienna' then raise exception 'T4: row wrong: %', r; end if;
  if (r.board->0->>'user_id')::uuid <> pg_temp.id('bernd') then raise exception 'T4: board must be sorted by drop_m desc: %', r.board; end if;
  if (r.board->0->>'is_live')::boolean then raise exception 'T4: is_live must be false for finished day'; end if;
  select count(*) into n from public.my_duels(1);
  if n <> 1 then raise exception 'T4: p_limit not honoured'; end if;
  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.my_duels(20);
  if n <> 0 then raise exception 'T4: chris has no duels'; end if;
  perform pg_temp.pass('T4 my_duels newest first with board + member_count');
end $$;

-- T5 live_days RLS: own upsert ok, foreign insert/update denied, group partner reads, stranger does not.
--    now() is frozen for the whole transaction, so the row's server-stamped updated_at is always
--    "0 s ago": the second upsert takes the UPDATE path and hits the 0015 20 s throttle (P0005) —
--    which also proves the "update own" policy let it through. The new value is written by
--    delete + insert (own-row policies) instead of backdating updated_at with the trigger disabled.
do $$
declare n int; ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('bernd'));
  insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('bernd'), pg_temp.d(), 100, 1)
    on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  begin
    insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('bernd'), pg_temp.d(), 150, 2)
      on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T5: a second upsert within 20 s must hit the update throttle'; end if;
  select count(*) into n from public.live_days where user_id = pg_temp.id('bernd') and drop_m = 100;
  if n <> 1 then raise exception 'T5: throttled upsert must leave the row unchanged'; end if;
  delete from public.live_days where user_id = pg_temp.id('bernd');
  insert into public.live_days (user_id, day, drop_m, run_count) values (pg_temp.id('bernd'), pg_temp.d(), 200, 2)
    on conflict (user_id) do update set day = excluded.day, drop_m = excluded.drop_m, run_count = excluded.run_count;
  select count(*) into n from public.live_days where user_id = pg_temp.id('bernd') and drop_m = 200;
  if n <> 1 then raise exception 'T5: own upsert failed'; end if;
  update public.live_days set drop_m = 1 where user_id = pg_temp.id('anna');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'T5: update of a partner''s live row must touch nothing, got %', n; end if;
  ok := false;
  begin
    insert into public.live_days (user_id, day, drop_m) values (pg_temp.id('chris'), pg_temp.d(), 5);
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: insert for another user must be denied'; end if;
  select count(*) into n from public.live_days where user_id = pg_temp.id('anna');
  if n <> 1 then raise exception 'T5: group partner must read anna''s live row'; end if;
  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.live_days where user_id = pg_temp.id('anna');
  if n <> 0 then raise exception 'T5: stranger must not read anna''s live row'; end if;
  perform pg_temp.pass('T5 live_days RLS own write / partner read');
end $$;

-- T6 invalid tz falls back; anon denied.
do $$
declare z text; denied int := 0;
begin
  reset role;
  update public.groups set tz = 'Europe/Nowhere' where id = pg_temp.id('duel2');
  select tz into z from public.groups where id = pg_temp.id('duel2');
  if z <> 'Europe/Vienna' then raise exception 'T6: fallback failed: %', z; end if;
  update public.groups set tz = 'Asia/Tokyo' where id = pg_temp.id('duel2');
  select tz into z from public.groups where id = pg_temp.id('duel2');
  if z <> 'Asia/Tokyo' then raise exception 'T6: valid tz rejected: %', z; end if;
  perform pg_temp.login(null, 'anon');
  begin perform public.group_board(pg_temp.id('duel')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.my_duels(5); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.live_days; exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 3 then raise exception 'T6: anon denied % of 3', denied; end if;
  perform pg_temp.pass('T6 tz fallback + anon denied');
end $$;

-- T7 join_group still returns the group; created via client insert carries tz column.
do $$
declare r record;
begin
  reset role;
  insert into public.groups (id, code, name, day, created_by, tz) values ('d0000000-0000-4000-8000-000000000039', 'TST012', 'Heute', current_date, pg_temp.id('anna'), 'America/Denver');
  insert into public.group_members (group_id, user_id) values ('d0000000-0000-4000-8000-000000000039', pg_temp.id('anna'));
  perform pg_temp.login(pg_temp.id('chris'));
  select * into r from public.join_group('TST012');
  if r.id <> 'd0000000-0000-4000-8000-000000000039'::uuid then raise exception 'T7: join failed'; end if;
  if not exists (select 1 from public.my_duels(5) where code = 'TST012' and tz = 'America/Denver' and member_count = 2) then raise exception 'T7: my_duels after join'; end if;
  perform pg_temp.pass('T7 join_group unchanged');
end $$;

reset role;
select n, test from t_results order by n;
rollback;
