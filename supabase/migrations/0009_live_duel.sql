-- 0009: Tagesduell live (docs/BACKLOG.md SOC-LIVE-DUEL)
--
-- Duel numbers used to appear only after a member ended the day — the board
-- read finished `days` rows only. Now:
--
--  1. live_days(user_id pk, day, resort_id, drop_m, run_count, ski_distance_m,
--     max_speed_ms, updated_at): one tiny row per rider, upserted by the app
--     every 120 s while recording inside a duel. Own-row write; readable by the
--     owner and everybody who shares a group with them (private.shares_group_with,
--     the definer RPC does the real work anyway). updated_at is set server-side.
--  2. groups.tz (IANA, default 'Europe/Vienna'): the creator's time zone. A
--     Colorado duel matches days by Denver's local date, not Vienna's. Unknown
--     names fall back to the default in a trigger, so `at time zone g.tz`
--     never raises inside group_board.
--  3. group_board(p_group_id) redefined (sole redefiner in wave 2, see 0005):
--     the finished days of the duel day win; a member without one is shown with
--     the live row and is_live = true; no resort filter any more (a duel is
--     not bound to a Gebiet); returns is_live + updated_at.
--  4. my_duels(p_limit): the caller's groups, newest day first, each with its
--     final board (jsonb array of group_board rows) and member_count — the
--     history list and the Tagesbilanz result card.
--
-- Definer pattern (docs/BACKEND.md): definer RPCs use auth.uid(), each function
-- revokes and grants itself, policies use the private.* helpers. Idempotent;
-- drops no table, deletes no row.

-- ---------------------------------------------------------------------------
-- 1. live_days
-- ---------------------------------------------------------------------------
create table if not exists public.live_days (
  user_id uuid primary key references auth.users(id) on delete cascade,
  day date not null,
  resort_id text,
  drop_m double precision not null default 0,
  run_count int not null default 0,
  ski_distance_m double precision not null default 0,
  max_speed_ms double precision not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.live_days drop constraint if exists live_days_non_negative;
alter table public.live_days add constraint live_days_non_negative
  check (drop_m >= 0 and run_count >= 0 and ski_distance_m >= 0 and max_speed_ms >= 0);
-- Same plausibility ceiling as days.suspicious (0001): a live row never shows
-- more than a day could.
alter table public.live_days drop constraint if exists live_days_plausible;
alter table public.live_days add constraint live_days_plausible
  check (drop_m <= 15000 and run_count <= 80 and max_speed_ms <= 45 and ski_distance_m <= 300000);

create index if not exists live_days_day on public.live_days(day);

-- updated_at comes from the server clock, never from the client.
create or replace function private.live_days_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.live_days_touch() from public, anon, authenticated;

drop trigger if exists live_days_touch on public.live_days;
create trigger live_days_touch before insert or update on public.live_days
  for each row execute function private.live_days_touch();

alter table public.live_days enable row level security;

drop policy if exists "live_days read" on public.live_days;
create policy "live_days read" on public.live_days for select
  using (user_id = auth.uid() or private.shares_group_with(user_id));

drop policy if exists "live_days insert own" on public.live_days;
create policy "live_days insert own" on public.live_days for insert
  with check (user_id = auth.uid());

drop policy if exists "live_days update own" on public.live_days;
create policy "live_days update own" on public.live_days for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "live_days delete own" on public.live_days;
create policy "live_days delete own" on public.live_days for delete
  using (user_id = auth.uid());

revoke all on table public.live_days from public, anon;
grant select, insert, update, delete on table public.live_days to authenticated;
grant all on table public.live_days to service_role;

comment on table public.live_days is
  'One live row per rider while recording inside a Tagesduell (0009). Own-row write; group_board coalesces it when no finished day exists.';

-- ---------------------------------------------------------------------------
-- 2. groups.tz
-- ---------------------------------------------------------------------------
alter table public.groups add column if not exists tz text not null default 'Europe/Vienna';

alter table public.groups drop constraint if exists groups_tz_shape;
alter table public.groups add constraint groups_tz_shape
  check (char_length(tz) between 1 and 64 and tz ~ '^[A-Za-z0-9_+/-]+$');

-- Unknown zone names (a client sending 'Europe/Nowhere') fall back to the
-- default instead of breaking every later `at time zone g.tz`.
create or replace function private.groups_tz_check()
returns trigger language plpgsql as $$
begin
  if new.tz is null or new.tz = '' then
    new.tz := 'Europe/Vienna';
    return new;
  end if;
  begin
    perform now() at time zone new.tz;
  exception when sqlstate '22023' then
    new.tz := 'Europe/Vienna';
  end;
  return new;
end;
$$;
revoke all on function private.groups_tz_check() from public, anon, authenticated;

drop trigger if exists groups_tz_check on public.groups;
create trigger groups_tz_check before insert or update of tz on public.groups
  for each row execute function private.groups_tz_check();

comment on column public.groups.tz is
  'IANA zone of the creator (default Europe/Vienna); group_board matches days by (started_at at time zone tz)::date = day.';

-- ---------------------------------------------------------------------------
-- 3. group_board — finished day wins, live row as fallback, no resort filter.
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
      where b.user_id = auth.uid() and b.blocked_id = m.user_id
    )
  order by 4 desc, 2, 1;
end;
$$;

revoke all on function public.group_board(uuid) from public, anon, authenticated;
grant execute on function public.group_board(uuid) to authenticated;

comment on function public.group_board(uuid) is
  'Duel board for members only (42501 otherwise). Finished days of the duel day (in groups.tz) win; otherwise the live_days row with is_live = true. No resort filter. Blocked members hidden.';

-- ---------------------------------------------------------------------------
-- 4. my_duels — the caller's duels, newest first, each with its board.
-- ---------------------------------------------------------------------------
drop function if exists public.my_duels(int);
create or replace function public.my_duels(p_limit int default 20)
returns table (
  id uuid,
  code text,
  name text,
  day date,
  resort_id text,
  created_by uuid,
  max_members int,
  tz text,
  member_count bigint,
  board jsonb
)
language plpgsql security definer stable set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  return query
  select g.id, g.code, g.name, g.day, g.resort_id, g.created_by, g.max_members, g.tz,
         (select count(*) from public.group_members mm where mm.group_id = g.id) as member_count,
         (select coalesce(jsonb_agg(jsonb_build_object(
                   'user_id', b.user_id,
                   'display_name', b.display_name,
                   'run_count', b.run_count,
                   'drop_m', b.drop_m,
                   'ski_distance_m', b.ski_distance_m,
                   'max_speed_ms', b.max_speed_ms,
                   'avg_ski_speed_ms', b.avg_ski_speed_ms,
                   'is_live', b.is_live,
                   'updated_at', b.updated_at
                 ) order by b.drop_m desc, b.display_name), '[]'::jsonb)
          from public.group_board(g.id) b) as board
  from public.groups g
  join public.group_members m on m.group_id = g.id and m.user_id = auth.uid()
  order by g.day desc, g.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
end;
$$;

revoke all on function public.my_duels(int) from public, anon, authenticated;
grant execute on function public.my_duels(int) to authenticated;

comment on function public.my_duels(int) is
  'The caller''s Tagesduelle, newest day first, each with member_count and the group_board rows as jsonb (p_limit clamped to 1..100).';
