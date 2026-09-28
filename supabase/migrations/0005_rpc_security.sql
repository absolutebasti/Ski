-- 0005: RPC security (docs/BACKEND.md "Definer pattern")
--
-- Blocker fixed here: public.days has a single owner-only policy and
-- leaderboard / country_board / group_board were `security invoker`, so every
-- rider saw only their own days and was alone on rank 1.
--
--  1. blocks(user_id, blocked_id): a rider hides another rider from their own
--     leaderboard and duel board. Own-row RLS; the exclusion happens server-side.
--  2. Policy helpers move to schema `private` (not exposed by PostgREST, so not
--     callable via /rpc) and use auth.uid() — the user-id parameters of the
--     public versions are ignored from now on. The public helpers stay for
--     definer RPCs but lose every client grant.
--  3. leaderboard / country_board / group_board / my_rank are `security definer
--     set search_path = public` and enforce visibility themselves:
--     share_leaderboards opt-in, plausible days, blocks, group membership.
--  4. Team semantics (GAMIFICATION §5): a rider scores for the country chosen in
--     onboarding — coalesce(profiles.country_code, days.country_code);
--     days.country_code stays "skied in".
--  5. leaderboard also returns country_code, last_day, day_count; p_limit is
--     clamped to 1…200; an unknown p_metric raises 'bad_metric' (22023).
--  6. Grants: every function in public loses EXECUTE for public/anon/
--     authenticated; only join_group, leaderboard, country_board, group_board
--     and my_rank are granted back to authenticated. anon gets nothing.
--
-- Idempotent: safe to re-run. Later migrations must not redefine
-- leaderboard / country_board / group_board / my_rank until 0009 (group_board)
-- and 0011 (all-time) — see docs/BACKLOG.md.

-- ---------------------------------------------------------------------------
-- 1. blocks
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  user_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_id),
  constraint blocks_not_self check (user_id <> blocked_id)
);
create index if not exists blocks_blocked on public.blocks(blocked_id);

alter table public.blocks enable row level security;
drop policy if exists "blocks own" on public.blocks;
create policy "blocks own" on public.blocks for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

revoke all on table public.blocks from public, anon;
grant select, insert, delete on table public.blocks to authenticated;
grant all on table public.blocks to service_role;

-- ---------------------------------------------------------------------------
-- 2. private schema: helpers for policies and the shared board CTE.
--    Not in PostgREST's exposed schemas → never reachable via /rpc.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to postgres, anon, authenticated, service_role;

create or replace function private.is_group_member(p_group_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = auth.uid()
  );
$$;

create or replace function private.shares_group_with(p_user_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.group_members a
    join public.group_members b on b.group_id = a.group_id
    where a.user_id = p_user_id and b.user_id = auth.uid()
  );
$$;

-- Season/month/week window shared by every board. 0011 extends it with 'all'.
create or replace function private.season_match(p_season_key text, d_season_key text, d_started_at timestamptz)
returns boolean language sql stable as $$
  select d_season_key = p_season_key
    or (p_season_key ~ '^\d{4}-\d{2}$'
        and to_char(d_started_at at time zone 'Europe/Vienna', 'YYYY-MM') = p_season_key)
    or (p_season_key ~ '^\d{4}-W\d{2}$'
        and to_char(d_started_at at time zone 'Europe/Vienna', 'IYYY-"W"IW') = p_season_key);
$$;

-- The one ranked set behind leaderboard() and my_rank(): opted-in riders,
-- plausible days, optional resort/country filter, riders blocked by the caller
-- removed before ranking. No limit here.
drop function if exists private.board(text, text, text, text);
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
        where b.user_id = auth.uid() and b.blocked_id = d.user_id
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

revoke all on function private.is_group_member(uuid) from public, anon, authenticated;
revoke all on function private.shares_group_with(uuid) from public, anon, authenticated;
revoke all on function private.season_match(text, text, timestamptz) from public, anon, authenticated;
revoke all on function private.board(text, text, text, text) from public, anon, authenticated;
-- Policies run as the querying role, so the two policy helpers need EXECUTE
-- for anon and authenticated. They are unreachable via /rpc regardless.
grant execute on function private.is_group_member(uuid) to anon, authenticated;
grant execute on function private.shares_group_with(uuid) to anon, authenticated;

-- Policies now use the private helpers (0002/0003 pointed at the public ones).
drop policy if exists "groups member read" on public.groups;
create policy "groups member read" on public.groups for select
  using (created_by = auth.uid() or private.is_group_member(id));

drop policy if exists "members read" on public.group_members;
create policy "members read" on public.group_members for select
  using (user_id = auth.uid() or private.is_group_member(group_id));

-- 0006 replaces this policy with own-row only ("profiles read own"); when 0005
-- is re-run after 0006 the narrower policy must survive.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
                 and policyname = 'profiles read own') then
    drop policy if exists "profiles limited read" on public.profiles;
    create policy "profiles limited read" on public.profiles for select
      using (id = auth.uid() or share_leaderboards or private.shares_group_with(id));
  end if;
end;
$$;

-- Public helpers: kept for definer RPCs (0009 etc.), user-id parameters ignored.
create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql security definer stable set search_path = public as $$
  select private.is_group_member(p_group_id);
$$;

create or replace function public.shares_group_with(p_user_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql security definer stable set search_path = public as $$
  select private.shares_group_with(p_user_id);
$$;

-- ---------------------------------------------------------------------------
-- 3. leaderboard — new row shape, definer, clamped limit, team country.
-- ---------------------------------------------------------------------------
drop function if exists public.leaderboard(text, text, text, int);
drop function if exists public.leaderboard(text, text, text, int, text);
create or replace function public.leaderboard(
  p_resort_id text,
  p_season_key text,
  p_metric text,
  p_limit int default 100,
  p_country text default null
)
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
language sql security definer stable set search_path = public as $$
  select b.rank, b.user_id, b.display_name, b.avatar_url, b.country_code, b.value, b.total, b.last_day, b.day_count
  from private.board(p_resort_id, p_season_key, p_metric, p_country) b
  order by b.rank, b.user_id
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

-- ---------------------------------------------------------------------------
-- 4. my_rank — the caller's own row from the same ranked set. Zero rows when
--    the caller is not ranked (not opted in, no plausible day in the window).
-- ---------------------------------------------------------------------------
drop function if exists public.my_rank(text, text, text, text);
create or replace function public.my_rank(
  p_resort_id text,
  p_season_key text,
  p_metric text,
  p_country text default null
)
returns table (rank bigint, total bigint, value double precision)
language sql security definer stable set search_path = public as $$
  select b.rank, b.total, b.value
  from private.board(p_resort_id, p_season_key, p_metric, p_country) b
  where b.user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- 5. country_board — team = chosen country, fallback skied-in country.
-- ---------------------------------------------------------------------------
drop function if exists public.country_board(text);
create or replace function public.country_board(p_season_key text)
returns table (country_code text, riders bigint, points double precision, drop_m double precision)
language sql security definer stable set search_path = public as $$
  select coalesce(p.country_code, d.country_code) as country_code,
         count(distinct d.user_id) as riders,
         sum(d.points)::double precision as points,
         sum(d.drop_m) as drop_m
  from public.days d
  join public.profiles p on p.id = d.user_id
  where p.share_leaderboards
    and d.deleted_at is null
    and not d.suspicious
    and coalesce(p.country_code, d.country_code) is not null
    and private.season_match(p_season_key, d.season_key, d.started_at)
  group by coalesce(p.country_code, d.country_code)
  order by points desc;
$$;

-- ---------------------------------------------------------------------------
-- 6. group_board — members only (42501 otherwise), blocked members hidden for
--    the caller. Row shape unchanged from 0001; 0009 is the next redefiner.
-- ---------------------------------------------------------------------------
drop function if exists public.group_board(uuid);
create or replace function public.group_board(p_group_id uuid)
returns table (
  user_id uuid,
  display_name text,
  run_count bigint,
  drop_m double precision,
  ski_distance_m double precision,
  max_speed_ms double precision,
  avg_ski_speed_ms double precision
)
language plpgsql security definer stable set search_path = public as $$
begin
  if auth.uid() is null or not private.is_group_member(p_group_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  return query
  select m.user_id,
         p.display_name,
         coalesce(sum(d.run_count), 0)::bigint,
         coalesce(sum(d.drop_m), 0)::double precision,
         coalesce(sum(d.ski_distance_m), 0)::double precision,
         coalesce(max(d.max_speed_ms), 0)::double precision,
         (case when coalesce(sum(d.ski_ms), 0) > 0
               then sum(d.ski_distance_m) / (sum(d.ski_ms) / 1000.0)
               else 0 end)::double precision
  from public.group_members m
  join public.groups g on g.id = m.group_id
  join public.profiles p on p.id = m.user_id
  left join public.days d on d.user_id = m.user_id
    and d.deleted_at is null and not d.suspicious
    and (d.started_at at time zone 'Europe/Vienna')::date = g.day
    and (g.resort_id is null or d.resort_id = g.resort_id)
  where m.group_id = p_group_id
    and not exists (
      select 1 from public.blocks b
      where b.user_id = auth.uid() and b.blocked_id = m.user_id
    )
  group by m.user_id, p.display_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Grants. Supabase's default privileges hand EXECUTE on every new public
--    function to anon/authenticated — take it all back, then allow-list.
--    Only the functions that exist up to 0005 are touched (a fixed list, not a
--    catalog loop): 0005 stays re-runnable without clobbering the grants that
--    0006+ set for their own functions. Every later migration revokes/grants
--    its own functions — see docs/BACKEND.md "Definer pattern".
-- ---------------------------------------------------------------------------
do $$
declare
  sig text;
begin
  foreach sig in array array[
    'public.leaderboard(text, text, text, int, text)',
    'public.my_rank(text, text, text, text)',
    'public.country_board(text)',
    'public.group_board(uuid)',
    'public.join_group(text)',
    'public.is_group_member(uuid, uuid)',
    'public.shares_group_with(uuid, uuid)',
    'public.ensure_weekly_challenges(date)'
  ]
  loop
    if to_regprocedure(sig) is not null then
      execute format('revoke execute on function %s from public, anon, authenticated', sig);
    end if;
  end loop;
end;
$$;

grant execute on function public.join_group(text) to authenticated;
grant execute on function public.leaderboard(text, text, text, int, text) to authenticated;
grant execute on function public.country_board(text) to authenticated;
grant execute on function public.group_board(uuid) to authenticated;
grant execute on function public.my_rank(text, text, text, text) to authenticated;
-- ensure_weekly_challenges, is_group_member, shares_group_with: no client grant.
-- service_role keeps EXECUTE (default privileges) for the dashboard and cron.

comment on function public.leaderboard(text, text, text, int, text) is
  'Ranked opted-in riders in a season/month/week window. Definer; clamps p_limit to 1..200; raises bad_metric.';
comment on function public.my_rank(text, text, text, text) is
  'The caller''s (rank, total, value) from the same ranked set as leaderboard(); zero rows when not ranked.';
comment on function public.country_board(text) is
  'Team board: riders/points/drop per country = coalesce(profiles.country_code, days.country_code).';
comment on function public.group_board(uuid) is
  'Duel board for members only (42501 otherwise); members blocked by the caller are hidden.';
comment on table public.blocks is
  'user_id hides blocked_id from their own leaderboard and duel boards. Own-row RLS.';
