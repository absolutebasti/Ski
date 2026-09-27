-- 0004: country teams (docs/GAMIFICATION.md §5 "Team = country")
--  * profiles.country_code / days.country_code — ISO-3166 alpha-2, the team a
--    rider competes for; the client fills days.country_code from the resort
--    and falls back to the rider's own country
--  * days.points — server-side points for a day. Same formula as the device
--    (hm ÷ 10 + km × 10 + runs × 5 + 50) WITHOUT the +25 streak bonus: the
--    streak is a device-side notion over consecutive local days and cannot be
--    derived from one row. Leaderboard points are therefore the "raw" day
--    points; the profile's lifetime points on the device may be higher.
--  * leaderboard(): optional country filter (p_country) and the metric 'points'
--  * country_board(p_season_key): country vs country, ordered by points
-- RLS is unchanged.

alter table public.profiles
  add column if not exists country_code text
  check (country_code is null or char_length(country_code) = 2);

alter table public.days
  add column if not exists country_code text
  check (country_code is null or char_length(country_code) = 2);

alter table public.days
  add column if not exists points int
  generated always as (round(drop_m / 10 + ski_distance_m / 100 + run_count * 5 + 50)::int) stored;

create index if not exists days_country_season on public.days(country_code, season_key) where deleted_at is null;

-- leaderboard: same shape as 0003 (incl. total), plus p_country and 'points'.
drop function if exists public.leaderboard(text, text, text, int);
create or replace function public.leaderboard(
  p_resort_id text,
  p_season_key text,
  p_metric text,
  p_limit int default 100,
  p_country text default null
)
returns table (rank bigint, user_id uuid, display_name text, avatar_url text, value double precision, total bigint)
language sql security invoker stable as $$
  with agg as (
    select d.user_id,
      case p_metric
        when 'drop_m' then sum(d.drop_m)
        when 'ski_distance_m' then sum(d.ski_distance_m)
        when 'run_count' then sum(d.run_count)::double precision
        when 'max_speed_ms' then max(d.max_speed_ms)
        when 'day_count' then count(*)::double precision
        when 'points' then sum(d.points)::double precision
      end as value
    from public.days d
    join public.profiles p on p.id = d.user_id
    where p.share_leaderboards and d.deleted_at is null and not d.suspicious
      and (p_resort_id is null or d.resort_id = p_resort_id)
      and (p_country is null or d.country_code = p_country)
      and (
        d.season_key = p_season_key
        or (p_season_key ~ '^\d{4}-\d{2}$'
            and to_char(d.started_at at time zone 'Europe/Vienna', 'YYYY-MM') = p_season_key)
        or (p_season_key ~ '^\d{4}-W\d{2}$'
            and to_char(d.started_at at time zone 'Europe/Vienna', 'IYYY-"W"IW') = p_season_key)
      )
    group by d.user_id
  )
  select rank() over (order by a.value desc) as rank, a.user_id, p.display_name, p.avatar_url, a.value,
         count(*) over () as total
  from agg a join public.profiles p on p.id = a.user_id
  order by a.value desc limit p_limit;
$$;
grant execute on function public.leaderboard(text, text, text, int, text) to authenticated;

-- country_board: one row per country with at least one opted-in, plausible day
-- in the window. riders = distinct users, points = sum of day points.
drop function if exists public.country_board(text);
create or replace function public.country_board(p_season_key text)
returns table (country_code text, riders bigint, points double precision, drop_m double precision)
language sql security invoker stable as $$
  select d.country_code,
         count(distinct d.user_id) as riders,
         sum(d.points)::double precision as points,
         sum(d.drop_m) as drop_m
  from public.days d
  join public.profiles p on p.id = d.user_id
  where p.share_leaderboards and d.deleted_at is null and not d.suspicious
    and d.country_code is not null
    and (
      d.season_key = p_season_key
      or (p_season_key ~ '^\d{4}-\d{2}$'
          and to_char(d.started_at at time zone 'Europe/Vienna', 'YYYY-MM') = p_season_key)
      or (p_season_key ~ '^\d{4}-W\d{2}$'
          and to_char(d.started_at at time zone 'Europe/Vienna', 'IYYY-"W"IW') = p_season_key)
    )
  group by d.country_code
  order by points desc;
$$;
grant execute on function public.country_board(text) to authenticated;
