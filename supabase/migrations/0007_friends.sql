-- 0007: friends (docs/BACKLOG.md SOC-FRIENDS)
--  * profiles.friend_code — six characters from an alphabet without 0/O/1/I/L,
--    assigned by a before-insert trigger, immutable afterwards, backfilled
--  * friendships(user_id = requester, friend_id = addressee, status) — one row
--    per pair, readable by either side; every write goes through a definer RPC
--  * RPCs add_friend_by_code, accept_friend, remove_friend, friends_list,
--    friends_board — friendship is explicit consent, so friends_board has no
--    share_leaderboards gate
-- Idempotent. Does NOT touch leaderboard / country_board / group_board (0005).

-- pgcrypto (gen_random_bytes) is installed in the `extensions` schema on Supabase.
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. friend_code
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists friend_code char(6);
create unique index if not exists profiles_friend_code_key on public.profiles(friend_code);

-- Same alphabet as the duel codes in the app (SupabaseSocialApi.codeAlphabet):
-- 31 symbols, no 0/O/1/I/L. Six symbols = 887 million codes.
create or replace function public.new_friend_code()
returns text language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea;
  code text;
  i int;
begin
  loop
    bytes := gen_random_bytes(6);
    code := '';
    for i in 0..5 loop
      code := code || substr(alphabet, 1 + (get_byte(bytes, i) % length(alphabet)), 1);
    end loop;
    exit when not exists (select 1 from public.profiles p where p.friend_code = code);
  end loop;
  return code;
end;
$$;
revoke all on function public.new_friend_code() from public, anon;
grant execute on function public.new_friend_code() to authenticated;

-- Insert: assign a code unless the row already carries one (never from the
-- client — the update trigger below also keeps it fixed).
create or replace function public.profiles_set_friend_code()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    new.friend_code := coalesce(old.friend_code, new.friend_code, public.new_friend_code());
    return new;
  end if;
  if new.friend_code is null then
    new.friend_code := public.new_friend_code();
  end if;
  return new;
end;
$$;
revoke all on function public.profiles_set_friend_code() from public, anon;
grant execute on function public.profiles_set_friend_code() to authenticated;

drop trigger if exists profiles_friend_code on public.profiles;
create trigger profiles_friend_code
  before insert or update on public.profiles
  for each row execute function public.profiles_set_friend_code();

-- Backfill existing profiles one by one so every code is checked for collisions.
do $$
declare r record;
begin
  for r in select id from public.profiles where friend_code is null loop
    update public.profiles set friend_code = public.new_friend_code() where id = r.id;
  end loop;
end $$;

alter table public.profiles alter column friend_code set not null;

-- ---------------------------------------------------------------------------
-- 2. friendships
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'friendship_status') then
    create type public.friendship_status as enum ('pending', 'accepted');
  end if;
end $$;

create table if not exists public.friendships (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status public.friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  constraint friendships_not_self check (user_id <> friend_id)
);
-- One row per pair regardless of who asked.
create unique index if not exists friendships_pair_key
  on public.friendships (least(user_id, friend_id), greatest(user_id, friend_id));
create index if not exists friendships_friend on public.friendships(friend_id);

alter table public.friendships enable row level security;
drop policy if exists "friendships own read" on public.friendships;
create policy "friendships own read" on public.friendships for select
  using (auth.uid() = user_id or auth.uid() = friend_id);
-- No insert/update/delete policy: writes only through the RPCs below.

-- ---------------------------------------------------------------------------
-- 3. RPCs
-- ---------------------------------------------------------------------------

-- add_friend_by_code: creates a pending request to the owner of p_code.
-- Raises: not_signed_in (42501), code_not_found (P0002), self (P0004),
-- already_friends (P0005 — pending or accepted, either direction).
-- If the other side already asked us, the request is accepted instead.
drop function if exists public.add_friend_by_code(text);
create or replace function public.add_friend_by_code(p_code text)
returns table (user_id uuid, display_name text, avatar_url text, country_code text, status text, incoming boolean, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  other public.profiles%rowtype;
  existing public.friendships%rowtype;
  st text := 'pending';
  incoming_row boolean := false;
  since timestamptz := now();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  select * into other from public.profiles p where p.friend_code = code;
  if not found then
    raise exception 'code_not_found' using errcode = 'P0002';
  end if;
  if other.id = me then
    raise exception 'self' using errcode = 'P0004';
  end if;
  select * into existing from public.friendships f
    where (f.user_id = me and f.friend_id = other.id) or (f.user_id = other.id and f.friend_id = me);
  if found then
    if existing.status = 'pending' and existing.user_id = other.id then
      -- They asked first: adding their code is the acceptance.
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
revoke all on function public.add_friend_by_code(text) from public, anon;
grant execute on function public.add_friend_by_code(text) to authenticated;

-- accept_friend: the addressee accepts a pending request from p_user_id.
-- Raises request_not_found (P0002) when there is nothing to accept.
drop function if exists public.accept_friend(uuid);
create or replace function public.accept_friend(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  update public.friendships f set status = 'accepted'
    where f.user_id = p_user_id and f.friend_id = me and f.status = 'pending';
  if not found then
    raise exception 'request_not_found' using errcode = 'P0002';
  end if;
end;
$$;
revoke all on function public.accept_friend(uuid) from public, anon;
grant execute on function public.accept_friend(uuid) to authenticated;

-- remove_friend: deletes the row in either direction — unfriend, withdraw a
-- request or decline one. Idempotent.
drop function if exists public.remove_friend(uuid);
create or replace function public.remove_friend(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  delete from public.friendships f
    where (f.user_id = me and f.friend_id = p_user_id) or (f.user_id = p_user_id and f.friend_id = me);
end;
$$;
revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;

-- friends_list: every friendship of the caller with the other party's profile.
-- incoming = the other party asked (pending rows waiting for our answer).
-- Profiles are only readable via RPC for anyone but the owner, hence definer.
drop function if exists public.friends_list();
create or replace function public.friends_list()
returns table (user_id uuid, display_name text, avatar_url text, country_code text, status text, incoming boolean, created_at timestamptz)
language sql security definer stable set search_path = public as $$
  select p.id, p.display_name, p.avatar_url, p.country_code, f.status::text,
         f.friend_id = auth.uid() as incoming, f.created_at
  from public.friendships f
  join public.profiles p on p.id = case when f.user_id = auth.uid() then f.friend_id else f.user_id end
  where auth.uid() is not null and (f.user_id = auth.uid() or f.friend_id = auth.uid())
  order by f.status desc, f.created_at desc;
$$;
revoke all on function public.friends_list() from public, anon;
grant execute on function public.friends_list() to authenticated;

-- friends_board: the leaderboard row shape over accepted friends + self.
-- Friends without a day in the window are listed with value 0 so the board is
-- never empty once you have friends. Plausible, non-deleted days only. Same
-- season / month ('YYYY-MM') / ISO-week ('YYYY-Www') keys as leaderboard().
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
  if p_metric not in ('drop_m', 'ski_distance_m', 'run_count', 'max_speed_ms', 'day_count', 'points') then
    raise exception 'bad_metric' using errcode = '22023';
  end if;
  return query
  with circle as (
    select me as uid
    union
    select case when f.user_id = me then f.friend_id else f.user_id end
    from public.friendships f
    where f.status = 'accepted' and (f.user_id = me or f.friend_id = me)
  ),
  agg as (
    select c.uid,
      coalesce(case p_metric
        when 'drop_m' then sum(d.drop_m)
        when 'ski_distance_m' then sum(d.ski_distance_m)
        when 'run_count' then sum(d.run_count)::double precision
        when 'max_speed_ms' then max(d.max_speed_ms)
        when 'day_count' then count(d.id)::double precision
        when 'points' then sum(d.points)::double precision
      end, 0) as value,
      max(d.started_at) as last_day,
      count(d.id) as day_count
    from circle c
    left join public.days d on d.user_id = c.uid
      and d.deleted_at is null and not d.suspicious
      and (
        d.season_key = p_season_key
        or (p_season_key ~ '^\d{4}-\d{2}$'
            and to_char(d.started_at at time zone 'Europe/Vienna', 'YYYY-MM') = p_season_key)
        or (p_season_key ~ '^\d{4}-W\d{2}$'
            and to_char(d.started_at at time zone 'Europe/Vienna', 'IYYY-"W"IW') = p_season_key)
      )
    group by c.uid
  )
  select rank() over (order by a.value desc, p.display_name) as rank,
         a.uid, p.display_name, p.avatar_url, p.country_code, a.value,
         count(*) over () as total, a.last_day, a.day_count
  from agg a join public.profiles p on p.id = a.uid
  order by a.value desc, p.display_name;
end;
$$;
revoke all on function public.friends_board(text, text) from public, anon;
grant execute on function public.friends_board(text, text) to authenticated;
