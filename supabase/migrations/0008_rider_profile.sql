-- 0008: rider_profile(p_user_id) — the profile behind a leaderboard row
-- (SOC-RIDER). One security-definer RPC that returns the public face of a
-- rider: name, avatar, team country, home resort, the current season's
-- numbers, and the lifetime totals the client needs to derive level
-- (docs/GAMIFICATION.md §2, from lifetime ski distance) and medals (§4, from
-- the totals below — every one of the 12 medal metrics is covered, so the
-- device catalogue can be evaluated 1:1 on the server totals).
--
-- Visibility (the row comes back only if one of these holds, else the result
-- is empty — the client shows "Dieses Profil ist privat."):
--   * the target is the caller,
--   * the target has profiles.share_leaderboards = true,
--   * the target and the caller are members of the same duel group,
--   * an accepted friendship exists between them (table friendships from
--     SOC-FRIENDS / 0007). The table may not exist yet when this migration
--     runs, and wave-1 migrations apply in any order, so the friendship clause
--     is guarded with to_regclass('public.friendships') and evaluated via
--     dynamic SQL. Decision documented here: no later ALTER is needed — the
--     function picks the table up as soon as it exists. Same guard for
--     blocks (BE-01 / 0005): a block in either direction hides the profile.
--
-- Plausibility: like the leaderboard, every sum/max/points figure ignores
-- suspicious days (days.suspicious). day_count and the streak count every
-- non-deleted day — a ski day is a ski day even when its numbers are off.
-- Time zone for calendar days is Europe/Vienna, as in 0001–0004 (see BE-TZ).
--
-- Signed-out callers get 42501 (not_signed_in); anon/public have no execute.
-- Idempotent: create or replace + revoke/grant.

create or replace function public.rider_profile(p_user_id uuid)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  country_code text,
  home_resort_id text,
  season_key text,
  season_drop_m double precision,
  season_ski_distance_m double precision,
  season_run_count bigint,
  season_day_count bigint,
  season_points double precision,
  lifetime_drop_m double precision,
  lifetime_ski_distance_m double precision,
  lifetime_run_count bigint,
  lifetime_day_count bigint,
  lifetime_max_speed_ms double precision,
  lifetime_points double precision,
  lifetime_avg_ski_speed_ms double precision,
  best_day_drop_m double precision,
  best_day_run_count bigint,
  longest_streak int,
  resort_count bigint,
  country_count bigint,
  last_day timestamptz
)
language plpgsql security definer stable set search_path = public as $$
declare
  v_viewer uuid := auth.uid();
  v_visible boolean;
  v_blocked boolean := false;
  v_season text;
  v_year int;
begin
  if v_viewer is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if p_user_id is null then
    return;
  end if;

  -- blocks(user_id, blocked_id) from BE-01 — optional at this point.
  if to_regclass('public.blocks') is not null then
    execute 'select exists (select 1 from public.blocks b '
         || ' where (b.user_id = $1 and b.blocked_id = $2) or (b.user_id = $2 and b.blocked_id = $1))'
      into v_blocked using v_viewer, p_user_id;
    if v_blocked then
      return;
    end if;
  end if;

  -- own profile, opted in, or a shared duel group.
  select (p.id = v_viewer
          or p.share_leaderboards
          or exists (select 1 from public.group_members a
                     join public.group_members b on b.group_id = a.group_id
                     where a.user_id = p.id and b.user_id = v_viewer))
    into v_visible
  from public.profiles p where p.id = p_user_id;
  if v_visible is null then
    return; -- no such profile
  end if;

  -- friendships(user_id, friend_id, status) from SOC-FRIENDS — optional.
  if not v_visible and to_regclass('public.friendships') is not null then
    execute 'select exists (select 1 from public.friendships f where f.status::text = ''accepted'''
         || ' and ((f.user_id = $1 and f.friend_id = $2) or (f.user_id = $2 and f.friend_id = $1)))'
      into v_visible using v_viewer, p_user_id;
  end if;
  if not coalesce(v_visible, false) then
    return;
  end if;

  -- current season key, '2025/26' (Jul 1 – Jun 30), Europe/Vienna.
  v_year := extract(year from (now() at time zone 'Europe/Vienna'))::int;
  if extract(month from (now() at time zone 'Europe/Vienna'))::int < 7 then
    v_year := v_year - 1;
  end if;
  v_season := v_year::text || '/' || lpad(((v_year + 1) % 100)::text, 2, '0');

  return query
  with d as (
    select x.* from public.days x where x.user_id = p_user_id and x.deleted_at is null
  ),
  s as (
    select
      count(*) filter (where d.season_key = v_season)                                          as s_days,
      coalesce(sum(d.drop_m)         filter (where not d.suspicious and d.season_key = v_season), 0) as s_drop,
      coalesce(sum(d.ski_distance_m) filter (where not d.suspicious and d.season_key = v_season), 0) as s_dist,
      coalesce(sum(d.run_count)      filter (where not d.suspicious and d.season_key = v_season), 0) as s_runs,
      coalesce(sum(d.points)         filter (where not d.suspicious and d.season_key = v_season), 0) as s_points,
      count(*)                                                                                 as l_days,
      coalesce(sum(d.drop_m)         filter (where not d.suspicious), 0)                       as l_drop,
      coalesce(sum(d.ski_distance_m) filter (where not d.suspicious), 0)                       as l_dist,
      coalesce(sum(d.run_count)      filter (where not d.suspicious), 0)                       as l_runs,
      coalesce(max(d.max_speed_ms)   filter (where not d.suspicious), 0)                       as l_max,
      coalesce(sum(d.points)         filter (where not d.suspicious), 0)                       as l_points,
      coalesce(sum(d.ski_ms)         filter (where not d.suspicious), 0)                       as l_ski_ms,
      coalesce(max(d.drop_m)         filter (where not d.suspicious), 0)                       as best_drop,
      coalesce(max(d.run_count)      filter (where not d.suspicious), 0)                       as best_runs,
      count(distinct d.resort_id)                                                              as resorts,
      count(distinct d.country_code)                                                           as countries,
      max(d.started_at)                                                                        as last_day
    from d
  ),
  st as (
    -- longest run of consecutive calendar days (gaps and islands).
    select coalesce(max(c.cnt), 0)::int as longest from (
      select count(*) as cnt from (
        select dd.day - (row_number() over (order by dd.day))::int as grp
        from (select distinct (d.started_at at time zone 'Europe/Vienna')::date as day from d) dd
      ) g group by g.grp
    ) c
  )
  select p.id, p.display_name, p.avatar_url, p.country_code, p.home_resort_id, v_season,
         s.s_drop::double precision, s.s_dist::double precision, s.s_runs::bigint, s.s_days::bigint, s.s_points::double precision,
         s.l_drop::double precision, s.l_dist::double precision, s.l_runs::bigint, s.l_days::bigint, s.l_max::double precision,
         s.l_points::double precision,
         (case when s.l_ski_ms > 0 then s.l_dist / (s.l_ski_ms / 1000.0) else 0 end)::double precision,
         s.best_drop::double precision, s.best_runs::bigint, st.longest, s.resorts::bigint, s.countries::bigint, s.last_day
  from public.profiles p cross join s cross join st
  where p.id = p_user_id;
end;
$$;

revoke all on function public.rider_profile(uuid) from public, anon, authenticated;
grant execute on function public.rider_profile(uuid) to authenticated;
