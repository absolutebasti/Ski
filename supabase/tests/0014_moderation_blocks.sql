-- Smoke test for migration 0014 (moderation: reports guard + notify, blocks
-- both ways, grant hygiene, group_members policy, create_duel). One
-- transaction, rolled back at the end — safe against the live project
-- (tools/supabase-test.sh, pattern of 0005_rpc_security.sql).
--
-- Seed: Anna (DE, opted in), Bernd (AT, opted in), Chris (opted out), Dora
-- (opted in), 12 targets for the report limit; one duel Anna+Bernd (day
-- 2026-01-15), a second duel created by Anna alone, one weekly challenge with
-- Anna + Bernd, an accepted friendship Anna–Bernd.

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
  ('anna',  'a0000000-0000-4000-8000-000000000014'),
  ('bernd', 'b0000000-0000-4000-8000-000000000014'),
  ('chris', 'c0000000-0000-4000-8000-000000000014'),
  ('dora',  'e0000000-0000-4000-8000-000000000014'),
  ('duel',  'd0000000-0000-4000-8000-000000000014'),
  ('duel2', 'd0000000-0000-4000-8000-000000000114'),
  ('chal',  '90000000-0000-4000-8000-000000000014');
insert into t_ids select 'target' || i, ('f0000000-0000-4000-8000-' || lpad((1400 + i)::text, 12, '0'))::uuid
from generate_series(1, 12) i;

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test14.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u where u.k not in ('duel', 'duel2', 'chal');

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true,  'DE'),
  (pg_temp.id('bernd'), 'Bernd', true,  'AT'),
  (pg_temp.id('chris'), 'Chris', false, 'DE'),
  (pg_temp.id('dora'),  'Dora',  true,  'CH');
insert into public.profiles (id, display_name, share_leaderboards, country_code)
select pg_temp.id('target' || i), 'Target ' || i, true, 'CH' from generate_series(1, 12) i;

insert into public.days (id, user_id, started_at, ended_at, resort_id, resort_name, season_key, country_code,
                         run_count, drop_m, ski_distance_m, max_speed_ms, ski_ms, elapsed_ms, device_updated_at)
values
  (gen_random_uuid(), pg_temp.id('anna'),  '2026-01-15 09:00+01', '2026-01-15 15:00+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 10, 3000, 20000, 18, 3600000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('bernd'), '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'AT', 12, 4000, 30000, 20, 4000000, 21600000, now()),
  (gen_random_uuid(), pg_temp.id('dora'),  '2026-01-15 09:30+01', '2026-01-15 15:30+01', 'kitzbuehel', 'Kitzbühel',
   '2025/26', 'CH', 5, 1000, 8000, 15, 2000000, 21600000, now());

insert into public.groups (id, code, name, day, resort_id, created_by, max_members)
values (pg_temp.id('duel'), 'TST014', 'Testduell', '2026-01-15', null, pg_temp.id('anna'), 3),
       (pg_temp.id('duel2'), 'TST114', 'Annas Duell', current_date, null, pg_temp.id('anna'), 3);
insert into public.group_members (group_id, user_id) values
  (pg_temp.id('duel'), pg_temp.id('anna')),
  (pg_temp.id('duel'), pg_temp.id('bernd')),
  (pg_temp.id('duel2'), pg_temp.id('anna'));

insert into public.challenges (id, title, title_de, title_en, metric, target, starts_on, ends_on)
values (pg_temp.id('chal'), 'Test-Challenge', 'Test-Challenge', 'Test challenge', 'drop_m', 2000, '2026-01-12', '2026-01-18');
insert into public.challenge_participants (challenge_id, user_id) values
  (pg_temp.id('chal'), pg_temp.id('anna')),
  (pg_temp.id('chal'), pg_temp.id('bernd'));

insert into public.friendships (user_id, friend_id, status) values (pg_temp.id('anna'), pg_temp.id('bernd'), 'accepted');

-- ---------------------------------------------------------------------------
-- T1  Bernd blocks Anna → invisible both ways; friendship gone; unblock does
--     not resurrect it; no new friendship while blocked.
-- ---------------------------------------------------------------------------
do $$
declare n int; r record; ok boolean := false;
begin
  -- before: everybody sees everybody
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0);
  if n <> 3 then raise exception 'T1: expected 3 rows before the block, got %', n; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 2 then raise exception 'T1: friends_board should list anna + bernd, got %', n; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('bernd'), pg_temp.id('anna'));

  -- the blocked side (Anna) no longer sees the blocker anywhere
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0) where user_id = pg_temp.id('bernd');
  if n <> 0 then raise exception 'T1: anna must not see bernd on the leaderboard'; end if;
  select * into r from public.my_rank('kitzbuehel', '2025/26', 'drop_m', null);
  if r.rank <> 1 or r.total <> 2 then raise exception 'T1: anna my_rank should be 1 of 2, got %', r; end if;
  select count(*) into n from public.group_board(pg_temp.id('duel')) where user_id = pg_temp.id('bernd');
  if n <> 0 then raise exception 'T1: anna must not see bernd on the duel board'; end if;
  select count(*) into n from public.challenge_board(pg_temp.id('chal')) where user_id = pg_temp.id('bernd');
  if n <> 0 then raise exception 'T1: anna must not see bernd on the challenge board'; end if;
  select * into r from public.challenge_board(pg_temp.id('chal')) where user_id = pg_temp.id('anna');
  if r.participants <> 1 or r.rank <> 1 then raise exception 'T1: challenge counts for anna wrong: %', r; end if;
  select count(*) into n from public.friends_board('2025/26', 'drop_m');
  if n <> 1 then raise exception 'T1: friends_board for anna should be self only, got %', n; end if;
  select count(*) into n from public.rider_profile(pg_temp.id('bernd'));
  if n <> 0 then raise exception 'T1: rider_profile of the blocker must be empty'; end if;

  -- the blocker (Bernd) does not see Anna either
  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0) where user_id = pg_temp.id('anna');
  if n <> 0 then raise exception 'T1: bernd must not see anna on the leaderboard'; end if;
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 1 then raise exception 'T1: bernd duel board should be self only, got %', n; end if;
  select count(*) into n from public.challenge_board(pg_temp.id('chal'));
  if n <> 1 then raise exception 'T1: bernd challenge board should be self only, got %', n; end if;
  -- others are unaffected
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0);
  if n <> 3 then raise exception 'T1: dora must still see all 3, got %', n; end if;

  -- friendship row deleted by the block
  reset role;
  select count(*) into n from public.friendships f
    where (f.user_id = pg_temp.id('anna') and f.friend_id = pg_temp.id('bernd'))
       or (f.user_id = pg_temp.id('bernd') and f.friend_id = pg_temp.id('anna'));
  if n <> 0 then raise exception 'T1: friendship must be deleted by the block'; end if;

  -- no new friendship while the block exists
  perform pg_temp.login(pg_temp.id('anna'));
  begin
    perform public.add_friend_by_code((select p.friend_code from public.profiles p where p.id = pg_temp.id('anna')));
  exception when sqlstate 'P0004' then null; -- self, just to prove the RPC is reachable
  end;
  begin
    perform public.add_friend_by_id(pg_temp.id('bernd'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T1: add_friend_by_id while blocked must raise rider_not_found'; end if;
  reset role;
  ok := false;
  begin
    insert into public.friendships (user_id, friend_id) values (pg_temp.id('anna'), pg_temp.id('bernd'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T1: friendships insert while blocked must raise (trigger)'; end if;

  -- unblock: visible again, friendship stays gone
  perform pg_temp.login(pg_temp.id('bernd'));
  delete from public.blocks where blocked_id = pg_temp.id('anna');
  perform pg_temp.login(pg_temp.id('anna'));
  select count(*) into n from public.leaderboard('kitzbuehel', '2025/26', 'drop_m', 100, null, 0);
  if n <> 3 then raise exception 'T1: unblock should restore 3 rows, got %', n; end if;
  select count(*) into n from public.friends_list();
  if n <> 0 then raise exception 'T1: unblock must not resurrect the friendship, got % rows', n; end if;
  perform pg_temp.pass('T1 block hides both ways (leaderboard, my_rank, duel, challenge, friends, profile); friendship deleted, not resurrected');
end $$;

-- ---------------------------------------------------------------------------
-- T2  reports: 11th of the day → rate_limited; duplicate → already_reported;
--     self → check violation; server timestamps; no client read.
-- ---------------------------------------------------------------------------
do $$
declare i int; ok boolean := false; n int; r record;
begin
  perform pg_temp.login(pg_temp.id('chris'));
  for i in 1..10 loop
    insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('chris'), pg_temp.id('target' || i), 'cheating: test ' || i);
  end loop;
  begin
    insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('chris'), pg_temp.id('target11'), 'other');
  exception when sqlstate 'P0005' then
    if sqlerrm <> 'rate_limited' then raise exception 'T2: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T2: 11th report must raise rate_limited'; end if;

  -- another reporter is not limited by chris' count, but duplicates per day are
  perform pg_temp.login(pg_temp.id('dora'));
  insert into public.reports (reporter, target_user_id, reason, created_at) values (pg_temp.id('dora'), pg_temp.id('target1'), 'offensive_name', '2000-01-01');
  ok := false;
  begin
    insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('dora'), pg_temp.id('target1'), 'offensive_name again');
  exception when unique_violation then
    if sqlerrm <> 'already_reported' then raise exception 'T2: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T2: duplicate report must raise already_reported'; end if;
  ok := false;
  begin
    insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('dora'), pg_temp.id('dora'), 'me');
  exception when check_violation then ok := true;
  end;
  if not ok then raise exception 'T2: self-report must be rejected'; end if;
  ok := false;
  begin
    insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('anna'), pg_temp.id('target2'), 'forged reporter');
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T2: reporting as somebody else must be denied'; end if;
  ok := false;
  begin
    select count(*) into n from public.reports;
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T2: clients must not read reports'; end if;

  reset role;
  select * into r from public.reports where reporter = pg_temp.id('dora');
  if r.created_at < now() - interval '1 minute' then raise exception 'T2: created_at must be server-set, got %', r.created_at; end if;
  if r.report_day <> (now() at time zone 'Europe/Vienna')::date then raise exception 'T2: report_day wrong: %', r.report_day; end if;
  if r.handled_at is not null then raise exception 'T2: handled_at must start null'; end if;
  select count(*) into n from private.open_reports where reporter = pg_temp.id('chris');
  if n <> 10 then raise exception 'T2: open_reports should list 10 of chris, got %', n; end if;
  select target_reports_7d into n from private.open_reports where reporter = pg_temp.id('dora');
  if n <> 2 then raise exception 'T2: target1 has 2 reports in 7 days, got %', n; end if;
  update public.reports set handled_at = now() where reporter = pg_temp.id('dora');
  select count(*) into n from private.open_reports where reporter = pg_temp.id('dora');
  if n <> 0 then raise exception 'T2: handled reports must leave open_reports'; end if;
  perform pg_temp.pass('T2 reports: 10/day limit, one per target per day, self/forged rejected, no client read, open_reports');
end $$;

-- ---------------------------------------------------------------------------
-- T3  notify: with Vault secrets a report queues one pg_net request to the
--     configured URL with the shared secret. Skipped where pg_net or Vault is
--     missing (plain Postgres in CI).
-- ---------------------------------------------------------------------------
do $$
declare v_url text; v_secret text; v_body text; last_id bigint; r record; n int;
begin
  reset role;
  if to_regclass('vault.decrypted_secrets') is null or to_regclass('net.http_request_queue') is null then
    perform pg_temp.pass('T3 notify skipped: pg_net or Vault not installed here');
    return;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'report_notify_url';
  if v_url is null then
    v_url := 'https://example.invalid/functions/v1/report-notify';
    perform vault.create_secret(v_url, 'report_notify_url');
  end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'report_notify_secret';
  if v_secret is null then
    v_secret := 'test-secret-0014';
    perform vault.create_secret(v_secret, 'report_notify_secret');
  end if;
  select coalesce(max(id), 0) into last_id from net.http_request_queue;

  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.reports (reporter, target_user_id, reason) values (pg_temp.id('anna'), pg_temp.id('target3'), 'cheating: 9.000 hm');
  reset role;
  select count(*) into n from net.http_request_queue q where q.id > last_id and q.url = v_url;
  if n <> 1 then raise exception 'T3: expected one queued request to %, got %', v_url, n; end if;
  select * into r from net.http_request_queue q where q.id > last_id and q.url = v_url;
  if r.headers::jsonb->>'x-report-secret' is distinct from v_secret then raise exception 'T3: secret header missing: %', r.headers; end if;
  -- body is bytea in current pg_net (jsonb in older releases)
  v_body := r.body::text;
  if left(v_body, 2) = '\x' then v_body := convert_from(decode(substr(v_body, 3), 'hex'), 'utf8'); end if;
  if (v_body::jsonb)->>'target_name' is distinct from 'Target 3' or (v_body::jsonb)->>'reporter_name' is distinct from 'Anna'
     or ((v_body::jsonb)->>'target_reports_7d')::int <> 2 then
    raise exception 'T3: body wrong: %', v_body;
  end if;
  perform pg_temp.pass('T3 report insert queues one pg_net request with the shared secret');
end $$;

-- ---------------------------------------------------------------------------
-- T4  grants: is_opted_in not client-callable; anon has no table grants;
--     friendships read-only for clients; trigger functions not callable.
-- ---------------------------------------------------------------------------
do $$
declare ok boolean := false; bad text; denied int := 0; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin
    perform public.is_opted_in(pg_temp.id('bernd'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T4: is_opted_in must be denied for authenticated'; end if;
  ok := false;
  begin
    insert into public.friendships (user_id, friend_id) values (pg_temp.id('anna'), pg_temp.id('dora'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T4: direct friendships insert must be denied'; end if;
  ok := false;
  begin
    delete from public.friendships where user_id = pg_temp.id('anna');
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T4: direct friendships delete must be denied'; end if;
  select count(*) into n from public.challenges where id = pg_temp.id('chal');
  if n <> 1 then raise exception 'T4: authenticated must still read challenges'; end if;

  perform pg_temp.login(null, 'anon');
  begin perform count(*) from public.challenges; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.friendships; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.groups; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.group_members; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.profiles; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform count(*) from public.days; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.create_duel('x', null, null, null); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 7 then raise exception 'T4: anon should be denied 7 times, got %', denied; end if;

  reset role;
  select string_agg(c.relname, ', ' order by c.relname) into bad
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'v', 'p')
    and has_table_privilege('anon', c.oid, 'select');
  if bad is not null then raise exception 'T4: anon may still select: %', bad; end if;
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.is_opted_in(uuid)', 'public.touch_updated_at()', 'private.reports_guard()', 'private.reports_notify()',
      'private.blocks_unfriend()', 'private.friendships_block_check()']) sig
  where has_function_privilege('authenticated', to_regprocedure(sig), 'execute')
     or has_function_privilege('anon', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T4: must not be client-callable: %', bad; end if;
  if not has_function_privilege('authenticated', 'public.create_duel(text, date, text, text)', 'execute') then
    raise exception 'T4: create_duel must be granted to authenticated';
  end if;
  perform pg_temp.pass('T4 grants: is_opted_in hidden, anon has no table access, friendships read-only, create_duel granted');
end $$;

-- ---------------------------------------------------------------------------
-- T5  group_members: only the creator inserts (themselves); create_duel;
--     join_group still enforces max_members.
-- ---------------------------------------------------------------------------
do $$
declare ok boolean := false; r record; n int; g_id uuid; g_code text;
begin
  -- Chris knows the id of Anna's group but is not the creator → RLS violation
  perform pg_temp.login(pg_temp.id('chris'));
  begin
    insert into public.group_members (group_id, user_id) values (pg_temp.id('duel2'), pg_temp.id('chris'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: non-creator insert into group_members must be denied'; end if;
  -- …and nobody inserts somebody else, not even the creator
  perform pg_temp.login(pg_temp.id('anna'));
  ok := false;
  begin
    insert into public.group_members (group_id, user_id) values (pg_temp.id('duel2'), pg_temp.id('chris'));
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: creator inserting another rider must be denied'; end if;

  -- the 1.0 client path (insert group, then insert self) keeps working
  insert into public.groups (code, name, day, created_by, max_members, tz) values ('TST214', 'Client-Pfad', current_date, pg_temp.id('anna'), 3, 'Europe/Vienna');
  insert into public.group_members (group_id, user_id) select g.id, pg_temp.id('anna') from public.groups g where g.code = 'TST214';
  select count(*) into n from public.group_members m join public.groups g on g.id = m.group_id where g.code = 'TST214';
  if n <> 1 then raise exception 'T5: creator self-insert must work'; end if;

  -- create_duel: group + membership in one call, server-generated code
  perform pg_temp.login(pg_temp.id('chris'));
  select * into r from public.create_duel('Mittwoch', null, 'America/Denver', 'aspen');
  if r.id is null or r.code !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$' then raise exception 'T5: create_duel row wrong: %', r; end if;
  if r.created_by <> pg_temp.id('chris') or r.max_members <> 3 or r.tz <> 'America/Denver' or r.name <> 'Mittwoch' or r.resort_id <> 'aspen' then
    raise exception 'T5: create_duel fields wrong: %', r;
  end if;
  if r.day <> (now() at time zone 'America/Denver')::date then raise exception 'T5: default day must be today in p_tz, got %', r.day; end if;
  g_id := r.id; g_code := r.code;
  select count(*) into n from public.group_members m where m.group_id = g_id and m.user_id = pg_temp.id('chris');
  if n <> 1 then raise exception 'T5: creator must be a member after create_duel'; end if;
  select count(*) into n from public.my_duels(5) where id = g_id and member_count = 1;
  if n <> 1 then raise exception 'T5: my_duels must list the new duel'; end if;
  -- name/tz/day fallbacks
  select * into r from public.create_duel('   ', current_date, 'Europe/Nowhere', '');
  if r.name <> 'Tagesduell' or r.tz <> 'Europe/Vienna' or r.resort_id is not null then raise exception 'T5: fallbacks wrong: %', r; end if;
  ok := false;
  begin
    perform public.create_duel('alt', current_date - 30, 'Europe/Vienna', null);
  exception when sqlstate '22023' then ok := true;
  end;
  if not ok then raise exception 'T5: a day 30 days ago must raise bad_day'; end if;

  -- join_group: 2nd and 3rd member fine, 4th → duel_full
  perform pg_temp.login(pg_temp.id('bernd'));
  perform public.join_group(g_code);
  perform pg_temp.login(pg_temp.id('dora'));
  perform public.join_group(lower(g_code));
  perform pg_temp.login(pg_temp.id('anna'));
  ok := false;
  begin
    perform public.join_group(g_code);
  exception when sqlstate 'P0003' then ok := true;
  end;
  if not ok then raise exception 'T5: 4th member must raise duel_full'; end if;
  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.group_board(g_id);
  if n <> 3 then raise exception 'T5: duel should have 3 members, got %', n; end if;
  perform pg_temp.pass('T5 group_members insert only for the creator; create_duel; join_group max_members');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
