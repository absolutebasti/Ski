-- 0006: data integrity, moderation schema, profile hardening (docs/BACKLOG.md BE-02)
--
-- Independent of 0005: leaderboard / country_board / group_board are NOT
-- redefined here. Everything is idempotent (drop … if exists / create or
-- replace / on conflict), nothing is dropped or deleted.
--
--  1. days: check constraints, wider `suspicious`, before-insert/update guard
--     ('too_many_days' = 4th non-deleted day per user per local date,
--     'rate_limited' = more than 30 upserts per user per hour)
--  2. profiles: display_name 1…24 chars, avatar_url https only, own-row read
--     only (other riders are reached through security-definer RPCs)
--  3. challenges: no client inserts, title ≤ 60; challenge_progress readable
--     for own rows or opted-in riders
--  4. groups: max_members 2…3, created_by nullable on delete set null,
--     creator may delete; join_group raises 'duel_expired'
--  5. storage: tracks 20 MB / application/gzip, public avatars bucket
--  6. reports: insert-own, no client read
--
-- Error codes raised for the client (message = the token the app matches on):
--   too_many_days P0004 · rate_limited P0005 · duel_expired P0006
--
-- NOTE season_key: the app writes ski-season keys as 'YYYY/YY' (core/season.dart,
-- e.g. '2025/26'); 'YYYY-MM' is the month key of leaderboard(). The check
-- therefore enforces '^\d{4}/\d{2}$' — the backlog text's '-' would have
-- rejected every day the app pushes.

-- ---------------------------------------------------------------------------
-- 1. days
-- ---------------------------------------------------------------------------
alter table public.days drop constraint if exists days_metrics_nonneg;
alter table public.days add constraint days_metrics_nonneg check (
  run_count >= 0 and lift_count >= 0
  and drop_m >= 0 and ascent_m >= 0
  and ski_distance_m >= 0 and lift_distance_m >= 0
  and max_speed_ms >= 0 and avg_ski_speed_ms >= 0
  and ski_ms >= 0 and lift_ms >= 0 and pause_ms >= 0 and elapsed_ms >= 0
);

alter table public.days drop constraint if exists days_ended_after_started;
alter table public.days add constraint days_ended_after_started check (ended_at is null or ended_at >= started_at);

alter table public.days drop constraint if exists days_started_not_future;
alter table public.days add constraint days_started_not_future check (started_at <= now() + interval '1 day');

alter table public.days drop constraint if exists days_elapsed_max;
alter table public.days add constraint days_elapsed_max check (elapsed_ms <= 20 * 3600 * 1000);

alter table public.days drop constraint if exists days_season_key_format;
alter table public.days add constraint days_season_key_format check (season_key ~ '^\d{4}/\d{2}$');

-- suspicious: the 0001 thresholds plus cross-field plausibility. Postgres 17
-- can swap the expression in place; older servers get drop + add (no index or
-- view depends on the column).
do $$
declare
  expr text := '(max_speed_ms > 45 or drop_m > 15000 or run_count > 80'
    || ' or drop_m > run_count * 1500 + 500'
    || ' or ski_distance_m > drop_m * 20'
    || ' or run_count > elapsed_ms / 120000.0'
    || ' or (max_speed_ms > 0 and ski_ms = 0))';
begin
  if current_setting('server_version_num')::int >= 170000 then
    execute format('alter table public.days alter column suspicious set expression as %s', expr);
  else
    execute 'alter table public.days drop column if exists suspicious';
    execute format('alter table public.days add column suspicious boolean generated always as %s stored', expr);
  end if;
end $$;

-- Per-user write counter for the rate limit (fixed one-hour window). No client
-- access at all: RLS on, no policies, written only by the definer trigger.
create table if not exists public.day_write_counters (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  writes int not null default 0
);
alter table public.day_write_counters enable row level security;
revoke all on public.day_write_counters from public, anon, authenticated;

create or replace function public.days_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  max_days_per_date constant int := 3;
  max_writes_per_hour constant int := 30;
  tz constant text := 'Europe/Vienna';
  n int;
  cnt public.day_write_counters%rowtype;
begin
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

-- ---------------------------------------------------------------------------
-- 2. profiles
-- ---------------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles add constraint profiles_display_name_len check (char_length(display_name) between 1 and 24);

alter table public.profiles drop constraint if exists profiles_avatar_https;
alter table public.profiles add constraint profiles_avatar_https check (avatar_url is null or avatar_url ~ '^https://');

-- Own row only. profile_api.dart / auth_service.dart / social_api.dart select
-- profiles exclusively with .eq('id', <own uid>); names of other riders come
-- from the definer RPCs (leaderboard, group_board, rider_profile …).
drop policy if exists "profiles public read" on public.profiles;
drop policy if exists "profiles limited read" on public.profiles;
drop policy if exists "profiles read own" on public.profiles;
create policy "profiles read own" on public.profiles for select using (id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. challenges / challenge_progress
-- ---------------------------------------------------------------------------
drop policy if exists "challenges create" on public.challenges;
revoke insert, update, delete on public.challenges from public, anon, authenticated;

alter table public.challenges drop constraint if exists challenges_title_len;
alter table public.challenges add constraint challenges_title_len check (char_length(title) <= 60);

-- Opt-in lookup that bypasses the own-row profiles policy (needed inside RLS
-- expressions, which run as the caller). share_leaderboards is public by
-- nature: opted-in riders appear on every board.
create or replace function public.is_opted_in(p_user_id uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce((select p.share_leaderboards from public.profiles p where p.id = p_user_id), false);
$$;
revoke all on function public.is_opted_in(uuid) from public, anon;
grant execute on function public.is_opted_in(uuid) to authenticated;

drop policy if exists "progress read" on public.challenge_progress;
create policy "progress read" on public.challenge_progress for select
  using (user_id = auth.uid() or public.is_opted_in(user_id));

-- ---------------------------------------------------------------------------
-- 4. groups / join_group
-- ---------------------------------------------------------------------------
alter table public.groups alter column created_by drop not null;
alter table public.groups drop constraint if exists groups_created_by_fkey;
alter table public.groups add constraint groups_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;

alter table public.groups alter column max_members set default 3;
alter table public.groups drop constraint if exists groups_max_members_range;
alter table public.groups add constraint groups_max_members_range check (max_members between 2 and 3);

drop policy if exists "groups delete own" on public.groups;
create policy "groups delete own" on public.groups for delete using (created_by = auth.uid());

-- join_group: same signature as 0002, plus 'duel_expired' for groups whose day
-- is before yesterday (local date, Europe/Vienna like group_board).
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
    if g.day < (now() at time zone 'Europe/Vienna')::date - 1 then
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
revoke all on function public.join_group(text) from public, anon;
grant execute on function public.join_group(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. storage
-- ---------------------------------------------------------------------------
update storage.buckets
   set file_size_limit = 20 * 1024 * 1024,
       allowed_mime_types = array['application/gzip']
 where id = 'tracks';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2 * 1024 * 1024, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read" on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars own insert" on storage.objects;
create policy "avatars own insert" on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars own update" on storage.objects;
create policy "avatars own update" on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars own delete" on storage.objects;
create policy "avatars own delete" on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- 6. reports
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 200),
  created_at timestamptz not null default now(),
  constraint reports_not_self check (reporter <> target_user_id)
);
create index if not exists reports_target_created on public.reports(target_user_id, created_at desc);
alter table public.reports enable row level security;

-- insert-own; no select/update/delete for clients at all (also no RETURNING —
-- the app must insert with `Prefer: return=minimal`, i.e. no .select() chained).
revoke all on public.reports from public, anon, authenticated;
grant insert on public.reports to authenticated;
drop policy if exists "reports insert own" on public.reports;
create policy "reports insert own" on public.reports for insert
  with check (reporter = auth.uid());
