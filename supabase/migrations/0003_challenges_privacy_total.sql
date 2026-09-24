-- 0003: weekly challenges are generated server-side, profiles are only readable
-- where needed, the leaderboard returns the participant count.

-- 1. Weekly challenges: three per ISO week, created idempotently. pg_cron runs
--    ensure_weekly_challenges() every Monday 04:00 UTC for this and next week.
create extension if not exists pg_cron;

create or replace function public.ensure_weekly_challenges(p_week_start date default date_trunc('week', now())::date)
returns int language plpgsql security definer set search_path = public as $$
declare
  n int := 0;
  w date := p_week_start;
  r record;
begin
  for r in select * from (values
      ('Wochen-Challenge: 5.000 Höhenmeter', 'drop_m', 5000::double precision),
      ('Wochen-Challenge: 20 Abfahrten', 'run_count', 20::double precision),
      ('Wochen-Challenge: 3 Skitage', 'day_count', 3::double precision)
    ) as v(title, metric, target)
  loop
    if not exists (select 1 from public.challenges c where c.starts_on = w and c.metric = r.metric) then
      insert into public.challenges (title, metric, target, starts_on, ends_on)
      values (r.title, r.metric, r.target, w, w + 6);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.ensure_weekly_challenges(date) from public;

select public.ensure_weekly_challenges(date_trunc('week', now())::date);
select public.ensure_weekly_challenges((date_trunc('week', now()) + interval '7 days')::date);

select cron.unschedule(jobid) from cron.job where jobname = 'weekly-challenges';
select cron.schedule('weekly-challenges', '0 4 * * 1',
  $$select public.ensure_weekly_challenges(date_trunc('week', now())::date),
           public.ensure_weekly_challenges((date_trunc('week', now()) + interval '7 days')::date)$$);

-- 2. Profiles: readable by the owner, by anyone for opted-in users, and by
--    members of a shared duel group (group_board needs their names).
create or replace function public.shares_group_with(p_user_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.group_members a
    join public.group_members b on b.group_id = a.group_id
    where a.user_id = p_user_id and b.user_id = p_viewer
  );
$$;
revoke all on function public.shares_group_with(uuid, uuid) from public;
grant execute on function public.shares_group_with(uuid, uuid) to authenticated;

drop policy if exists "profiles public read" on public.profiles;
drop policy if exists "profiles limited read" on public.profiles;
create policy "profiles limited read" on public.profiles for select
  using (id = auth.uid() or share_leaderboards or public.shares_group_with(id));

-- 3. Leaderboard returns the participant count in every row (window count).
drop function if exists public.leaderboard(text, text, text, int);
create or replace function public.leaderboard(p_resort_id text, p_season_key text, p_metric text, p_limit int default 100)
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
      end as value
    from public.days d
    join public.profiles p on p.id = d.user_id
    where p.share_leaderboards and d.deleted_at is null and not d.suspicious
      and (p_resort_id is null or d.resort_id = p_resort_id)
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
