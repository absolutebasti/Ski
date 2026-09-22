-- 0002: social fixes after WP-16 review
--  * group membership checks via a security-definer helper (the 0001 policy
--    compared a column with itself and would recurse under RLS)
--  * join_group(p_code): invitees cannot read groups they are not in, so joining
--    by code needs a definer RPC that also enforces max_members server-side
--  * leaderboard accepts month ('YYYY-MM') and ISO-week ('YYYY-Www') keys

create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.group_members m where m.group_id = p_group_id and m.user_id = p_user_id);
$$;
revoke all on function public.is_group_member(uuid, uuid) from public;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;

drop policy if exists "groups member read" on public.groups;
create policy "groups member read" on public.groups for select
  using (created_by = auth.uid() or public.is_group_member(id));

drop policy if exists "members read" on public.group_members;
create policy "members read" on public.group_members for select
  using (user_id = auth.uid() or public.is_group_member(group_id));

create or replace function public.join_group(p_code text)
returns table (id uuid, code text, name text, day date, resort_id text, created_by uuid, max_members int)
language plpgsql security definer set search_path = public as $$
declare
  g public.groups%rowtype;
  n int;
begin
  if auth.uid() is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  select * into g from public.groups where groups.code = upper(p_code);
  if not found then
    raise exception 'code_not_found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = auth.uid()) then
    select count(*) into n from public.group_members m where m.group_id = g.id;
    if n >= g.max_members then
      raise exception 'duel_full' using errcode = 'P0003';
    end if;
    insert into public.group_members (group_id, user_id) values (g.id, auth.uid());
  end if;
  return query select g.id, g.code, g.name, g.day, g.resort_id, g.created_by, g.max_members;
end;
$$;
revoke all on function public.join_group(text) from public;
grant execute on function public.join_group(text) to authenticated;

create or replace function public.leaderboard(p_resort_id text, p_season_key text, p_metric text, p_limit int default 100)
returns table (rank bigint, user_id uuid, display_name text, avatar_url text, value double precision)
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
  select rank() over (order by a.value desc) as rank, a.user_id, p.display_name, p.avatar_url, a.value
  from agg a join public.profiles p on p.id = a.user_id
  order by a.value desc limit p_limit;
$$;
