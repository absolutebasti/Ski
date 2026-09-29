-- 0014: moderation for the store review (docs/BACKLOG-2.md BE-14)
--
--  1. reports: the founder is notified. A before-insert guard stamps
--     report_day (Europe/Vienna), forces created_at/handled_at, raises
--     'rate_limited' (P0005) at the 11th report of a reporter per day and
--     'already_reported' (23505) for a second report of the same rider on the
--     same day (a unique index is the hard guard behind it). An after-insert
--     trigger posts the report via pg_net to the Edge Function `report-notify`
--     (supabase/functions/report-notify) which e-mails hello@torchtechnology.de.
--     URL and shared secret come from Supabase Vault — without them the trigger
--     is a no-op, a report insert never fails because of the notification.
--     reports.handled_at + view private.open_reports = the founder's inbox.
--  2. Blocks are invisible both ways (decision, docs/BACKEND.md): a block in
--     either direction hides the pair from each other in private.board
--     (leaderboard/my_rank), group_board and challenge_board — friends_board,
--     friends_list (0013) and rider_profile (0008) already did that. A block
--     deletes the friendships row of the pair (any status); unblocking does not
--     resurrect it. A friendships insert is rejected while a block exists.
--  3. Grant hygiene: is_opted_in(uuid) loses its client grant (no policy uses
--     it since 0010), anon loses every table grant in public (the app never
--     runs anonymous sessions; RLS already returned nothing), friendships is
--     read-only for clients (writes only via the definer RPCs),
--     touch_updated_at() is a trigger function and not a client RPC.
--  4. group_members: 'members join self' is gone — a client may only insert
--     themselves into a group they created; everybody else joins through
--     join_group (max_members, duel_expired). create_duel(p_name, p_day, p_tz,
--     p_resort_id) creates group + creator membership in one transaction with a
--     server-generated code (SOC-DUEL-INVITES switches the client to it).
--
-- Definer pattern (docs/BACKEND.md): every function revokes and grants
-- itself, policies use private.* helpers, RPCs use auth.uid(). Idempotent;
-- drops no table, deletes no rows (the blocks trigger deletes a friendship at
-- runtime — that is the feature).

create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;
-- Async HTTP from triggers. Objects live in schema `net` (not relocatable).
create extension if not exists pg_net;

-- ---------------------------------------------------------------------------
-- 1. reports: guard, notify, founder view
-- ---------------------------------------------------------------------------
alter table public.reports add column if not exists report_day date not null default current_date;
alter table public.reports add column if not exists handled_at timestamptz;

create unique index if not exists reports_reporter_target_day
  on public.reports (reporter, target_user_id, report_day);
create index if not exists reports_reporter_day on public.reports (reporter, report_day);

create or replace function private.reports_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  max_per_day constant int := 10;
  n int;
begin
  -- Server clock only; the client cannot pre-date or pre-handle a report.
  new.created_at := now();
  new.handled_at := null;
  new.report_day := (now() at time zone 'Europe/Vienna')::date;
  if new.reporter is null or new.reporter <> auth.uid() then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if exists (select 1 from public.reports r
             where r.reporter = new.reporter and r.target_user_id = new.target_user_id
               and r.report_day = new.report_day) then
    raise exception 'already_reported' using errcode = '23505';
  end if;
  select count(*) into n from public.reports r
    where r.reporter = new.reporter and r.report_day = new.report_day;
  if n >= max_per_day then
    raise exception 'rate_limited' using errcode = 'P0005';
  end if;
  return new;
end;
$$;
revoke all on function private.reports_guard() from public, anon, authenticated;

drop trigger if exists reports_guard on public.reports;
create trigger reports_guard before insert on public.reports
  for each row execute function private.reports_guard();

-- Posts the report to the Edge Function. Configuration lives in Vault:
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/report-notify', 'report_notify_url');
--   select vault.create_secret('<random shared secret>', 'report_notify_secret');
-- Missing pg_net, missing Vault or missing secrets → nothing happens. Any
-- error is swallowed: the report row must land no matter what.
create or replace function private.reports_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_secret text;
  v_reporter text;
  v_target text;
  v_recent int;
  v_body jsonb;
begin
  if to_regclass('vault.decrypted_secrets') is null then
    return new;
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'net' and p.proname = 'http_post') then
    return new;
  end if;
  begin
    select s.decrypted_secret into v_url from vault.decrypted_secrets s where s.name = 'report_notify_url';
    select s.decrypted_secret into v_secret from vault.decrypted_secrets s where s.name = 'report_notify_secret';
    if coalesce(v_url, '') = '' or coalesce(v_secret, '') = '' then
      return new;
    end if;
    select p.display_name into v_reporter from public.profiles p where p.id = new.reporter;
    select p.display_name into v_target from public.profiles p where p.id = new.target_user_id;
    select count(*) into v_recent from public.reports r
      where r.target_user_id = new.target_user_id and r.created_at > now() - interval '7 days';
    v_body := jsonb_build_object(
      'type', 'report',
      'id', new.id,
      'reporter', new.reporter,
      'reporter_name', v_reporter,
      'target_user_id', new.target_user_id,
      'target_name', v_target,
      'reason', new.reason,
      'created_at', new.created_at,
      'target_reports_7d', v_recent);
    perform net.http_post(
      url := v_url,
      body := v_body,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-report-secret', v_secret),
      timeout_milliseconds := 5000);
  exception when others then
    raise warning 'reports_notify skipped: % (%)', sqlerrm, sqlstate;
  end;
  return new;
end;
$$;
revoke all on function private.reports_notify() from public, anon, authenticated;

drop trigger if exists reports_notify on public.reports;
create trigger reports_notify after insert on public.reports
  for each row execute function private.reports_notify();

-- Founder's inbox (SQL editor, as postgres): open reports of the last 7 days.
-- Close one with: update public.reports set handled_at = now() where id = '<id>';
create or replace view private.open_reports as
  select r.id, r.created_at, r.reason,
         r.reporter, rp.display_name as reporter_name,
         r.target_user_id, tp.display_name as target_name,
         (select count(*) from public.reports x
           where x.target_user_id = r.target_user_id and x.created_at > now() - interval '7 days') as target_reports_7d
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter
  left join public.profiles tp on tp.id = r.target_user_id
  where r.handled_at is null and r.created_at > now() - interval '7 days'
  order by r.created_at desc;
revoke all on private.open_reports from public, anon, authenticated;

comment on table public.reports is
  'Rider reports (0006). 0014: max 10 per reporter and Vienna day, one per (reporter, target, day); after-insert trigger notifies the founder via pg_net → report-notify; handled_at closes a report; inbox = private.open_reports.';

-- ---------------------------------------------------------------------------
-- 2. blocks: invisible both ways
-- ---------------------------------------------------------------------------

-- 2a. private.board — same signature and row shape as 0005; only the block
--     test changes (either direction). leaderboard()/my_rank() keep calling it.
create or replace function private.board(p_resort_id text, p_season_key text, p_metric text, p_country text)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  country_code text,
  value double precision,
  total bigint,
  last_day timestamptz,
  day_count bigint
)
language plpgsql security definer stable set search_path = public as $$
begin
  if p_metric is null or p_metric not in ('drop_m', 'ski_distance_m', 'run_count', 'max_speed_ms', 'day_count', 'points') then
    raise exception 'bad_metric' using errcode = '22023', detail = coalesce(p_metric, 'null');
  end if;
  if p_season_key is null then
    raise exception 'bad_season_key' using errcode = '22023';
  end if;
  return query
  with agg as (
    select d.user_id as uid,
      case p_metric
        when 'drop_m' then sum(d.drop_m)
        when 'ski_distance_m' then sum(d.ski_distance_m)
        when 'run_count' then sum(d.run_count)::double precision
        when 'max_speed_ms' then max(d.max_speed_ms)
        when 'day_count' then count(*)::double precision
        when 'points' then sum(d.points)::double precision
      end as val,
      max(d.started_at) as last_started,
      count(*) as n_days,
      max(d.country_code) as any_country
    from public.days d
    join public.profiles p on p.id = d.user_id
    where p.share_leaderboards
      and d.deleted_at is null
      and not d.suspicious
      and (p_resort_id is null or d.resort_id = p_resort_id)
      and (p_country is null or coalesce(p.country_code, d.country_code) = p_country)
      and private.season_match(p_season_key, d.season_key, d.started_at)
      and not exists (
        select 1 from public.blocks b
        where (b.user_id = auth.uid() and b.blocked_id = d.user_id)
           or (b.user_id = d.user_id and b.blocked_id = auth.uid())
      )
    group by d.user_id
  )
  select rank() over (order by a.val desc) as rank,
         a.uid,
         p.display_name,
         p.avatar_url,
         coalesce(p.country_code, a.any_country),
         a.val,
         count(*) over () as total,
         a.last_started,
         a.n_days
  from agg a
  join public.profiles p on p.id = a.uid;
end;
$$;
revoke all on function private.board(text, text, text, text) from public, anon, authenticated;

-- 2b. group_board — 0009's definition, block test in both directions.
drop function if exists public.group_board(uuid);
create or replace function public.group_board(p_group_id uuid)
returns table (
  user_id uuid,
  display_name text,
  run_count bigint,
  drop_m double precision,
  ski_distance_m double precision,
  max_speed_ms double precision,
  avg_ski_speed_ms double precision,
  is_live boolean,
  updated_at timestamptz
)
language plpgsql security definer stable set search_path = public as $$
begin
  if auth.uid() is null or not private.is_group_member(p_group_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  return query
  with fin as (
    select m.user_id as uid,
           sum(d.run_count)::bigint as run_count,
           sum(d.drop_m)::double precision as drop_m,
           sum(d.ski_distance_m)::double precision as ski_distance_m,
           max(d.max_speed_ms)::double precision as max_speed_ms,
           sum(d.ski_ms)::bigint as ski_ms,
           max(d.updated_at) as updated_at
    from public.group_members m
    join public.groups g on g.id = m.group_id
    join public.days d on d.user_id = m.user_id
      and d.deleted_at is null and not d.suspicious
      and (d.started_at at time zone g.tz)::date = g.day
    where m.group_id = p_group_id
    group by m.user_id
  )
  select m.user_id,
         p.display_name,
         coalesce(f.run_count, l.run_count, 0)::bigint,
         coalesce(f.drop_m, l.drop_m, 0)::double precision,
         coalesce(f.ski_distance_m, l.ski_distance_m, 0)::double precision,
         coalesce(f.max_speed_ms, l.max_speed_ms, 0)::double precision,
         (case when coalesce(f.ski_ms, 0) > 0
               then f.ski_distance_m / (f.ski_ms / 1000.0)
               else 0 end)::double precision,
         (f.uid is null and l.user_id is not null) as is_live,
         coalesce(f.updated_at, l.updated_at) as updated_at
  from public.group_members m
  join public.groups g on g.id = m.group_id
  join public.profiles p on p.id = m.user_id
  left join fin f on f.uid = m.user_id
  left join public.live_days l on l.user_id = m.user_id and l.day = g.day
  where m.group_id = p_group_id
    and not exists (
      select 1 from public.blocks b
      where (b.user_id = auth.uid() and b.blocked_id = m.user_id)
         or (b.user_id = m.user_id and b.blocked_id = auth.uid())
    )
  order by 4 desc, 2, 1;
end;
$$;
revoke all on function public.group_board(uuid) from public, anon, authenticated;
grant execute on function public.group_board(uuid) to authenticated;
comment on function public.group_board(uuid) is
  'Duel board for members only (42501 otherwise). Finished days of the duel day (in groups.tz) win; otherwise the live_days row with is_live = true. No resort filter. Blocked pairs (either direction) hidden.';

-- 2c. challenge_board — 0010's definition, block test in both directions.
drop function if exists public.challenge_board(uuid);
create or replace function public.challenge_board(p_challenge_id uuid)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  country_code text,
  value double precision,
  done boolean,
  participants bigint,
  done_count bigint
)
language plpgsql security definer stable set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  tgt double precision;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  select c.target into tgt from public.challenges c where c.id = p_challenge_id;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0002';
  end if;
  return query
  with v as (
    select cv.user_id as uid, cv.value as val
    from private.challenge_values(p_challenge_id) cv
    where not exists (select 1 from public.blocks b
                      where (b.user_id = me and b.blocked_id = cv.user_id)
                         or (b.user_id = cv.user_id and b.blocked_id = me))
  )
  select rank() over (order by v.val desc, p.display_name, v.uid) as rank,
         v.uid,
         p.display_name,
         p.avatar_url,
         p.country_code,
         v.val,
         v.val >= tgt as done,
         count(*) over () as participants,
         count(*) filter (where v.val >= tgt) over () as done_count
  from v
  join public.profiles p on p.id = v.uid
  order by v.val desc, p.display_name, v.uid;
end;
$$;
revoke all on function public.challenge_board(uuid) from public, anon, authenticated;
grant execute on function public.challenge_board(uuid) to authenticated;
comment on function public.challenge_board(uuid) is
  'Participants of one challenge ranked by their value over days in starts_on..ends_on; blocked pairs (either direction) hidden. 42501 not_signed_in, P0002 challenge_not_found.';

-- 2d. A block ends the friendship (pending or accepted) — and no new one can
--     be made while the block exists. Unblocking does not bring it back.
create or replace function private.blocks_unfriend()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if to_regclass('public.friendships') is not null then
    delete from public.friendships f
      where (f.user_id = new.user_id and f.friend_id = new.blocked_id)
         or (f.user_id = new.blocked_id and f.friend_id = new.user_id);
  end if;
  return new;
end;
$$;
revoke all on function private.blocks_unfriend() from public, anon, authenticated;

drop trigger if exists blocks_unfriend on public.blocks;
create trigger blocks_unfriend after insert on public.blocks
  for each row execute function private.blocks_unfriend();

create or replace function private.friendships_block_check()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.blocks b
             where (b.user_id = new.user_id and b.blocked_id = new.friend_id)
                or (b.user_id = new.friend_id and b.blocked_id = new.user_id)) then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  return new;
end;
$$;
revoke all on function private.friendships_block_check() from public, anon, authenticated;

drop trigger if exists friendships_block_check on public.friendships;
create trigger friendships_block_check before insert on public.friendships
  for each row execute function private.friendships_block_check();

comment on table public.blocks is
  'A block hides both riders from each other (leaderboard, my_rank, duel, challenge, friends boards, rider_profile) and deletes their friendship (0014). Own-row RLS.';

-- ---------------------------------------------------------------------------
-- 3. Grant hygiene
-- ---------------------------------------------------------------------------
revoke all on function public.is_opted_in(uuid) from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;

-- anon gets nothing in public (docs/BACKEND.md: anonymous sessions are not
-- used; every policy already tests auth.uid()). Includes challenges.
do $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'v', 'p')
  loop
    execute format('revoke all on table public.%I from public, anon', t.relname);
  end loop;
end $$;

-- friendships: reads via RLS, every write through the definer RPCs (0007/0013).
revoke insert, update, delete, truncate, references, trigger on table public.friendships from authenticated;
grant select on table public.friendships to authenticated;
grant all on table public.friendships to service_role;

-- ---------------------------------------------------------------------------
-- 4. group_members insert policy + create_duel
-- ---------------------------------------------------------------------------
drop policy if exists "members join self" on public.group_members;
drop policy if exists "members insert creator" on public.group_members;
create policy "members insert creator" on public.group_members for insert
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.groups g where g.id = group_id and g.created_by = auth.uid())
  );

-- create_duel: group + creator membership in one transaction, code generated
-- server-side (same 31-symbol alphabet as the app and friend codes).
-- Errors: not_signed_in (42501), bad_day (22023: p_day outside yesterday…+7
-- days in p_tz). p_day null = today in p_tz; unknown p_tz falls back to
-- Europe/Vienna (groups_tz_check, 0009). p_name empty = 'Tagesduell'.
drop function if exists public.create_duel(text, date, text, text);
create or replace function public.create_duel(p_name text, p_day date default null, p_tz text default null, p_resort_id text default null)
returns table (id uuid, code text, name text, day date, resort_id text, created_by uuid, max_members int, tz text)
language plpgsql security definer set search_path = public, extensions as $$
#variable_conflict use_column
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  me uuid := auth.uid();
  v_tz text := coalesce(nullif(trim(p_tz), ''), 'Europe/Vienna');
  v_today date;
  v_day date;
  v_name text := left(coalesce(nullif(trim(p_name), ''), 'Tagesduell'), 60);
  v_code text;
  bytes bytea;
  i int;
  attempt int := 0;
  g public.groups%rowtype;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  begin
    v_today := (now() at time zone v_tz)::date;
  exception when sqlstate '22023' then
    v_tz := 'Europe/Vienna';
    v_today := (now() at time zone v_tz)::date;
  end;
  v_day := coalesce(p_day, v_today);
  if v_day < v_today - 1 or v_day > v_today + 7 then
    raise exception 'bad_day' using errcode = '22023';
  end if;
  loop
    attempt := attempt + 1;
    bytes := gen_random_bytes(6);
    v_code := '';
    for i in 0..5 loop
      v_code := v_code || substr(alphabet, 1 + (get_byte(bytes, i) % length(alphabet)), 1);
    end loop;
    begin
      insert into public.groups (code, name, day, resort_id, created_by, max_members, tz)
      values (v_code, v_name, v_day, nullif(trim(p_resort_id), ''), me, 3, v_tz)
      returning * into g;
      exit;
    exception when unique_violation then
      if attempt >= 5 then raise; end if;
    end;
  end loop;
  insert into public.group_members (group_id, user_id) values (g.id, me);
  return query select g.id, g.code, g.name, g.day, g.resort_id, g.created_by, g.max_members, g.tz;
end;
$$;
revoke all on function public.create_duel(text, date, text, text) from public, anon, authenticated;
grant execute on function public.create_duel(text, date, text, text) to authenticated;
comment on function public.create_duel(text, date, text, text) is
  'Creates a Tagesduell (group + creator membership) with a server-generated code; returns the group row incl. tz. 42501 not_signed_in, 22023 bad_day.';

-- PostgREST picks up create_duel and the changed grants.
notify pgrst, 'reload schema';
