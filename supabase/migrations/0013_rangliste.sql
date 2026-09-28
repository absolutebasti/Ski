-- 0013: Rangliste core (docs/BACKLOG.md SOC-RANGLISTE)
--  1. add_friend_by_id(p_user_id) — the RiderSheet's 'Freund hinzufügen':
--     same semantics as add_friend_by_code (0007), addressed by user id; a
--     block in either direction hides the rider (rider_not_found).
--  2. friends_list / friends_board exclude public.blocks in both directions;
--     friends_board ranks with the team country
--     coalesce(profiles.country_code, max(days.country_code)) like leaderboard().
--  3. leaderboard() gains p_offset (default 0, clamped ≥ 0) so the client can
--     load the window around the caller's own rank ('Zu mir springen').
--     private.board / private.season_match / my_rank are NOT touched.
--  4. new_friend_code() and profiles_set_friend_code() lose their client grant:
--     both run inside the security-definer trigger, no client needs them.
-- Idempotent; drops no table, deletes no row. Definer pattern per
-- docs/BACKEND.md: every function revokes and grants itself.

-- ---------------------------------------------------------------------------
-- 1. add_friend_by_id
-- ---------------------------------------------------------------------------
-- Raises: not_signed_in (42501), rider_not_found (P0002 — unknown id or a
-- block in either direction), self (P0004), already_friends (P0005). When the
-- other side already asked, the call accepts instead (status 'accepted').
drop function if exists public.add_friend_by_id(uuid);
create or replace function public.add_friend_by_id(p_user_id uuid)
returns table (user_id uuid, display_name text, avatar_url text, country_code text, status text, incoming boolean, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  other public.profiles%rowtype;
  existing public.friendships%rowtype;
  st text := 'pending';
  incoming_row boolean := false;
  since timestamptz := now();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  if p_user_id = me then
    raise exception 'self' using errcode = 'P0004';
  end if;
  select * into other from public.profiles p where p.id = p_user_id;
  if not found then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.blocks b
             where (b.user_id = me and b.blocked_id = p_user_id)
                or (b.user_id = p_user_id and b.blocked_id = me)) then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  select * into existing from public.friendships f
    where (f.user_id = me and f.friend_id = other.id) or (f.user_id = other.id and f.friend_id = me);
  if found then
    if existing.status = 'pending' and existing.user_id = other.id then
      update public.friendships f set status = 'accepted'
        where f.user_id = other.id and f.friend_id = me;
      st := 'accepted';
      incoming_row := true;
      since := existing.created_at;
    else
      raise exception 'already_friends' using errcode = 'P0005';
    end if;
  else
    insert into public.friendships (user_id, friend_id) values (me, other.id);
  end if;
  return query select other.id, other.display_name, other.avatar_url, other.country_code, st, incoming_row, since;
end;
$$;
revoke all on function public.add_friend_by_id(uuid) from public, anon, authenticated;
grant execute on function public.add_friend_by_id(uuid) to authenticated;
comment on function public.add_friend_by_id(uuid) is
  'Friend request by user id (RiderSheet). Same semantics as add_friend_by_code; blocked riders raise rider_not_found.';

-- ---------------------------------------------------------------------------
-- 2. friends_list / friends_board without blocked riders
-- ---------------------------------------------------------------------------
drop function if exists public.friends_list();
create or replace function public.friends_list()
returns table (user_id uuid, display_name text, avatar_url text, country_code text, status text, incoming boolean, created_at timestamptz)
language sql security definer stable set search_path = public as $$
  select p.id, p.display_name, p.avatar_url, p.country_code, f.status::text,
         f.friend_id = auth.uid() as incoming, f.created_at
  from public.friendships f
  join public.profiles p on p.id = case when f.user_id = auth.uid() then f.friend_id else f.user_id end
  where auth.uid() is not null and (f.user_id = auth.uid() or f.friend_id = auth.uid())
    and not exists (select 1 from public.blocks b
                    where (b.user_id = auth.uid() and b.blocked_id = p.id)
                       or (b.user_id = p.id and b.blocked_id = auth.uid()))
  order by f.status desc, f.created_at desc;
$$;
revoke all on function public.friends_list() from public, anon, authenticated;
grant execute on function public.friends_list() to authenticated;

drop function if exists public.friends_board(text, text);
create or replace function public.friends_board(p_season_key text, p_metric text)
returns table (rank bigint, user_id uuid, display_name text, avatar_url text, country_code text,
               value double precision, total bigint, last_day timestamptz, day_count bigint)
language plpgsql security definer stable set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if p_metric is null or p_metric not in ('drop_m', 'ski_distance_m', 'run_count', 'max_speed_ms', 'day_count', 'points') then
    raise exception 'bad_metric' using errcode = '22023';
  end if;
  if p_season_key is null then
    raise exception 'bad_season_key' using errcode = '22023';
  end if;
  return query
  with circle as (
    select me as uid
    union
    select case when f.user_id = me then f.friend_id else f.user_id end
    from public.friendships f
    where f.status = 'accepted' and (f.user_id = me or f.friend_id = me)
  ),
  visible as (
    select c.uid from circle c
    where not exists (select 1 from public.blocks b
                      where (b.user_id = me and b.blocked_id = c.uid)
                         or (b.user_id = c.uid and b.blocked_id = me))
  ),
  agg as (
    select v.uid,
      coalesce(case p_metric
        when 'drop_m' then sum(d.drop_m)
        when 'ski_distance_m' then sum(d.ski_distance_m)
        when 'run_count' then sum(d.run_count)::double precision
        when 'max_speed_ms' then max(d.max_speed_ms)
        when 'day_count' then count(d.id)::double precision
        when 'points' then sum(d.points)::double precision
      end, 0) as value,
      max(d.started_at) as last_day,
      count(d.id) as day_count,
      max(d.country_code) as any_country
    from visible v
    left join public.days d on d.user_id = v.uid
      and d.deleted_at is null and not d.suspicious
      and private.season_match(p_season_key, d.season_key, d.started_at)
    group by v.uid
  )
  select rank() over (order by a.value desc, p.display_name) as rank,
         a.uid, p.display_name, p.avatar_url,
         coalesce(p.country_code, a.any_country) as country_code,
         a.value, count(*) over () as total, a.last_day, a.day_count
  from agg a join public.profiles p on p.id = a.uid
  order by a.value desc, p.display_name;
end;
$$;
revoke all on function public.friends_board(text, text) from public, anon, authenticated;
grant execute on function public.friends_board(text, text) to authenticated;
comment on function public.friends_board(text, text) is
  'Leaderboard row shape over accepted friends + self; blocked riders (either direction) hidden; team country = coalesce(profile, skied-in).';

-- ---------------------------------------------------------------------------
-- 3. leaderboard with p_offset
-- ---------------------------------------------------------------------------
drop function if exists public.leaderboard(text, text, text, int, text);
drop function if exists public.leaderboard(text, text, text, int, text, int);
create or replace function public.leaderboard(
  p_resort_id text,
  p_season_key text,
  p_metric text,
  p_limit int default 100,
  p_country text default null,
  p_offset int default 0
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
  limit least(greatest(coalesce(p_limit, 100), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;
revoke all on function public.leaderboard(text, text, text, int, text, int) from public, anon, authenticated;
grant execute on function public.leaderboard(text, text, text, int, text, int) to authenticated;
comment on function public.leaderboard(text, text, text, int, text, int) is
  'Ranked, opted-in riders for a resort/season/metric (definer). p_limit 1…200, p_offset ≥ 0 for the window around my_rank().';

-- ---------------------------------------------------------------------------
-- 4. trigger helpers are not client RPCs
-- ---------------------------------------------------------------------------
revoke all on function public.new_friend_code() from public, anon, authenticated;
revoke all on function public.profiles_set_friend_code() from public, anon, authenticated;

-- PostgREST picks up the new leaderboard signature.
notify pgrst, 'reload schema';
