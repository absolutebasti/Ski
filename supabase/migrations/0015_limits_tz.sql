-- 0015: rate-limit fix for track_path, live_days limits, join_group time
-- zone (docs/BACKLOG-2.md BE-15). Applies after 0014.
--
--  1. days_guard (0006/0006b): an UPDATE that leaves device_updated_at alone
--     and changes nothing but track_path (the gzip upload after the day
--     upsert, sync_api.setTrackPath) is not a client write: it neither counts
--     against the 200-per-hour throttle nor moves updated_at. A sync of 150
--     days is 150 upserts + 150 track_path updates = 150 counted writes.
--     The early return is deliberately stricter than "device_updated_at
--     unchanged": any other column change with a stale device_updated_at
--     still runs the three-days-per-date check, is counted and moves
--     updated_at. days_touch (0001) only fires for a device write; the guard
--     owns updated_at for every other update. Also fixed: a re-upsert of an
--     existing day was counted twice (once per trigger pass of `insert … on
--     conflict do update`) — a re-sync of 150 days cost 300 of the 200 writes.
--  2. live_days (0009): day must lie within current_date ± 1 (the server runs
--     in UTC, so a rider in any time zone is inside that window; stale rows
--     can no longer be written). The trigger live_days_touch raises
--     'rate_limited' (P0005) for a second UPDATE within 20 s (the app writes
--     every 120 s), then stamps updated_at. The 05:00 cron `live-days-cleanup`
--     (0009b) also drops day_write_counters rows whose window started more
--     than two hours ago.
--  3. join_group (0006): 'duel_expired' is judged in the group's own time zone
--     (groups.tz, 0009) via private.duel_expired(day, tz, at) — a Denver duel
--     stays joinable until Denver's next day is over, although Vienna is
--     already a date ahead. Same signature and row shape as 0006.
--  4. blocked_riders() (new RPC): the caller's blocks with name and avatar,
--     for the 'Blockierte Nutzer' page (rider_profile hides blocked pairs).
--
-- Definer pattern (docs/BACKEND.md): every function revokes and grants
-- itself, trigger functions and helpers get no client grant. Idempotent;
-- drops no table, deletes no row (the cron deletes transient rows at runtime —
-- that is the feature).

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- 1. days_guard + days_touch: track_path-only updates are free
-- ---------------------------------------------------------------------------
create or replace function public.days_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  max_days_per_date constant int := 3;
  max_writes_per_hour constant int := 200;
  tz constant text := 'Europe/Vienna';
  n int;
  cnt public.day_write_counters%rowtype;
  skip text[];
begin
  -- 0015: `insert … on conflict (id) do update` (the app's upsert) fires this
  -- trigger twice for an existing row — as INSERT for the proposed row, then
  -- as UPDATE. The UPDATE pass does the checks; the INSERT pass used to count
  -- the same write a second time. (A plain insert of an existing id fails on
  -- the primary key and takes this early return with it.)
  if tg_op = 'INSERT' and exists (select 1 from public.days d where d.id = new.id) then
    return new;
  end if;

  if tg_op = 'UPDATE' and new.device_updated_at = old.device_updated_at then
    -- 0015: the track_path upload (and a no-op re-upsert) is not a client
    -- write. Generated columns (suspicious, points) are null in NEW inside a
    -- before-trigger and are therefore left out of the comparison.
    select coalesce(array_agg(a.attname::text), '{}') into skip
      from pg_attribute a
     where a.attrelid = tg_relid and a.attnum > 0 and not a.attisdropped and a.attgenerated <> '';
    skip := skip || array['track_path', 'updated_at'];
    if (to_jsonb(new) - skip) = (to_jsonb(old) - skip) then
      new.updated_at := old.updated_at;  -- server-owned: the pull cursor does not move
      return new;
    end if;
    -- Anything else without a new device clock is still a write; days_touch
    -- does not fire for it, so the guard moves updated_at itself.
    new.updated_at := now();
  end if;

  -- a) at most three non-deleted days per rider per local date
  if new.deleted_at is null and (
       tg_op = 'INSERT'
       or old.deleted_at is not null
       or old.started_at is distinct from new.started_at
     ) then
    select count(*) into n from public.days d
     where d.user_id = new.user_id and d.deleted_at is null and d.id <> new.id
       and (d.started_at at time zone tz)::date = (new.started_at at time zone tz)::date;
    if n >= max_days_per_date then
      raise exception 'too_many_days' using errcode = 'P0004';
    end if;
  end if;

  -- b) more than max_writes_per_hour upserts in the current window → reject.
  --    The counter row is rolled back together with the rejected write, so it
  --    stays at the limit until the window expires.
  insert into public.day_write_counters (user_id, window_start, writes)
  values (new.user_id, now(), 1)
  on conflict (user_id) do update
    set window_start = case when public.day_write_counters.window_start < now() - interval '1 hour'
                            then now() else public.day_write_counters.window_start end,
        writes = case when public.day_write_counters.window_start < now() - interval '1 hour'
                      then 1 else public.day_write_counters.writes + 1 end
  returning * into cnt;
  if cnt.writes > max_writes_per_hour then
    raise exception 'rate_limited' using errcode = 'P0005';
  end if;
  return new;
end $$;
revoke all on function public.days_guard() from public, anon, authenticated;

drop trigger if exists days_guard on public.days;
create trigger days_guard before insert or update on public.days
  for each row execute function public.days_guard();

-- Fires after days_guard (alphabetical order) and only for a device write.
drop trigger if exists days_touch on public.days;
create trigger days_touch before update on public.days
  for each row
  when (old.device_updated_at is distinct from new.device_updated_at)
  execute function public.touch_updated_at();

comment on function public.days_guard() is
  'days before-insert/update guard: 3 non-deleted days per rider and Vienna date (P0004 too_many_days), 200 writes per rider and hour (P0005 rate_limited); 0015: an update that only sets track_path (device_updated_at unchanged) is free and leaves updated_at alone.';

-- ---------------------------------------------------------------------------
-- 2. live_days: day window, 20 s update throttle, counter cleanup
-- ---------------------------------------------------------------------------
-- The check is relative to the clock, so it stays NOT VALID on purpose: it is
-- enforced for every insert and update from now on, stored rows simply age out
-- of the window (the cron removes them) and a dump restores without tripping
-- over them.
alter table public.live_days drop constraint if exists live_days_day_window;
alter table public.live_days add constraint live_days_day_window
  check (day between current_date - 1 and current_date + 1) not valid;

-- Throttle + server clock in one before-trigger (same trigger name as 0009).
create or replace function private.live_days_touch()
returns trigger language plpgsql as $$
declare
  min_gap constant interval := interval '20 seconds';
begin
  if tg_op = 'UPDATE' and old.updated_at > now() - min_gap then
    raise exception 'rate_limited' using errcode = 'P0005';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.live_days_touch() from public, anon, authenticated;

drop trigger if exists live_days_touch on public.live_days;
create trigger live_days_touch before insert or update on public.live_days
  for each row execute function private.live_days_touch();

comment on table public.live_days is
  'One live row per rider while recording inside a Tagesduell (0009). Own-row write; day within current_date ± 1 (UTC); at most one update per 20 s (P0005 rate_limited); group_board coalesces it when no finished day exists.';

-- Cron (0009b): live rows older than two days + write counters whose hour
-- window started more than two hours ago. Rescheduled by name → idempotent,
-- and it also creates the job where 0009b was never applied (local stack).
select cron.unschedule(jobid) from cron.job where jobname = 'live-days-cleanup';
select cron.schedule('live-days-cleanup', '0 5 * * *',
  $cmd$delete from public.live_days where day < current_date - 2; delete from public.day_write_counters where window_start < now() - interval '2 hours'$cmd$);

-- ---------------------------------------------------------------------------
-- 3. join_group: expiry in the group's time zone
-- ---------------------------------------------------------------------------
-- A duel can be joined on its day and the day after, both read on the clock
-- of the group's zone. p_at exists for the tests; callers pass nothing.
create or replace function private.duel_expired(p_day date, p_tz text, p_at timestamptz default now())
returns boolean language sql stable as $$
  select p_day < (p_at at time zone coalesce(nullif(p_tz, ''), 'Europe/Vienna'))::date - 1;
$$;
revoke all on function private.duel_expired(date, text, timestamptz) from public, anon, authenticated;

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
    -- groups.tz is always a valid zone (trigger groups_tz_check, 0009).
    if private.duel_expired(g.day, g.tz) then
      raise exception 'duel_expired' using errcode = 'P0006';
    end if;
    select count(*) into n from public.group_members m where m.group_id = g.id;
    if n >= g.max_members then
      raise exception 'duel_full' using errcode = 'P0003';
    end if;
    insert into public.group_members (group_id, user_id) values (g.id, auth.uid());
  end if;
  return query select g.id, g.code, g.name, g.day, g.resort_id, g.created_by, g.max_members;
end;
$$;
revoke all on function public.join_group(text) from public, anon, authenticated;
grant execute on function public.join_group(text) to authenticated;

comment on function public.join_group(text) is
  'Joins the duel behind an invite code. P0002 code_not_found, P0003 duel_full, P0006 duel_expired (duel day is before yesterday on the clock of the group''s own tz, 0015).';

-- ---------------------------------------------------------------------------
-- 4. blocked_riders: names for Einstellungen › 'Blockierte Nutzer'
-- ---------------------------------------------------------------------------
-- rider_profile (0008/0014) returns no row for a blocked pair and profiles is
-- own-row (0006), so the unblock list had no names. Only the caller's own
-- blocks; left join so a rider without a profile row still shows up (the app
-- falls back to its placeholder name) and can be unblocked.
create or replace function public.blocked_riders()
returns table (user_id uuid, display_name text, avatar_url text, created_at timestamptz)
language plpgsql security definer stable set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  return query
  select b.blocked_id, p.display_name, p.avatar_url, b.created_at
    from public.blocks b
    left join public.profiles p on p.id = b.blocked_id
   where b.user_id = auth.uid()
   order by b.created_at desc, b.blocked_id;
end;
$$;
revoke all on function public.blocked_riders() from public, anon, authenticated;
grant execute on function public.blocked_riders() to authenticated;

comment on function public.blocked_riders() is
  'Riders the caller has blocked, newest first, with display_name/avatar_url (null without a profile row). 42501 not_signed_in. 0015.';

notify pgrst, 'reload schema';
