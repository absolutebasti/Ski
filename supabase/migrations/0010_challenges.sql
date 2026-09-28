-- 0010: Wochen-Challenge with participants, server-side progress, board and
-- history (docs/BACKLOG.md SOC-CHALLENGE). Applies after 0005/0006.
--
-- Before: challenge_progress(value) was a client-trusted snapshot written once
-- on 'Mitmachen' — no participant count, no board, no history, German-only
-- titles. Now:
--  1. challenges.title_de / title_en — both written by ensure_weekly_challenges
--     (cron-only) via private.challenge_title(metric, target, lang); `title`
--     stays = title_de for the 1.0.0 client. The app derives the title from
--     metric + target when a column is missing, so copy never needs a migration.
--  2. challenge_participants(challenge_id, user_id, joined_at): own-row RLS,
--     insert only (challenge_id, user_id) by column-level grant — there is no
--     client-writable value anywhere. Joining is only possible while the
--     challenge is still open. Existing challenge_progress rows are migrated;
--     the old table becomes read-only (select + delete of own rows, the latter
--     because AuthService.deleteAccount's fallback still deletes there) until
--     the next release drops it.
--  3. private.challenge_values(challenge) — value per participant from days
--     inside starts_on…ends_on (Europe/Vienna calendar days, deleted and
--     suspicious days excluded — the leaderboard's plausibility filters).
--     Joining a challenge is explicit consent like a friendship, so there is no
--     share_leaderboards gate on the board (friends_board precedent, 0007).
--  4. challenge_board(p_challenge_id): rank, user_id, display_name, avatar_url,
--     country_code, value, done, participants, done_count — riders blocked by
--     the caller removed before ranking (same as leaderboard / group_board).
--     Errors: 42501 not_signed_in, P0002 challenge_not_found.
--  5. my_challenge_history(p_limit): ended challenges the caller joined with the
--     final value, done, rank and participant count. Limit clamped 1…100.
--
-- Does NOT touch leaderboard / country_board / group_board / friends_* / my_rank.
-- Idempotent: create or replace, if not exists, drop policy if exists; never
-- drops tables or deletes rows.

-- ---------------------------------------------------------------------------
-- 1. Titles in both languages
-- ---------------------------------------------------------------------------
alter table public.challenges add column if not exists title_de text;
alter table public.challenges add column if not exists title_en text;
alter table public.challenges drop constraint if exists challenges_title_de_len;
alter table public.challenges add constraint challenges_title_de_len check (title_de is null or char_length(title_de) <= 60);
alter table public.challenges drop constraint if exists challenges_title_en_len;
alter table public.challenges add constraint challenges_title_en_len check (title_en is null or char_length(title_en) <= 60);

create schema if not exists private;

-- 'Wochen-Challenge: 5.000 Höhenmeter' / 'Weekly challenge: 5,000 m vertical'.
-- Mirrors ChallengeStrings.title() in the app (challenge_strings.dart).
create or replace function private.challenge_title(p_metric text, p_target double precision, p_lang text)
returns text language sql immutable as $$
  select case
    when p_lang = 'en' then
      'Weekly challenge: ' || case p_metric
        when 'drop_m' then trim(to_char(round(p_target)::bigint, 'FM999,999,999')) || ' m vertical'
        when 'ski_distance_m' then trim(to_char(round(p_target / 1000)::bigint, 'FM999,999,999')) || ' km'
        when 'run_count' then trim(to_char(round(p_target)::bigint, 'FM999,999,999')) || case when round(p_target) = 1 then ' run' else ' runs' end
        when 'day_count' then trim(to_char(round(p_target)::bigint, 'FM999,999,999')) || case when round(p_target) = 1 then ' ski day' else ' ski days' end
        when 'max_speed_ms' then trim(to_char(round(p_target * 3.6)::bigint, 'FM999,999,999')) || ' km/h top speed'
        when 'points' then trim(to_char(round(p_target)::bigint, 'FM999,999,999')) || ' points'
        else trim(to_char(round(p_target)::bigint, 'FM999,999,999'))
      end
    else
      'Wochen-Challenge: ' || case p_metric
        when 'drop_m' then replace(trim(to_char(round(p_target)::bigint, 'FM999,999,999')), ',', '.') || ' Höhenmeter'
        when 'ski_distance_m' then replace(trim(to_char(round(p_target / 1000)::bigint, 'FM999,999,999')), ',', '.') || ' Ski-km'
        when 'run_count' then replace(trim(to_char(round(p_target)::bigint, 'FM999,999,999')), ',', '.') || case when round(p_target) = 1 then ' Abfahrt' else ' Abfahrten' end
        when 'day_count' then replace(trim(to_char(round(p_target)::bigint, 'FM999,999,999')), ',', '.') || case when round(p_target) = 1 then ' Skitag' else ' Skitage' end
        when 'max_speed_ms' then replace(trim(to_char(round(p_target * 3.6)::bigint, 'FM999,999,999')), ',', '.') || ' km/h Top-Speed'
        when 'points' then replace(trim(to_char(round(p_target)::bigint, 'FM999,999,999')), ',', '.') || ' Punkte'
        else replace(trim(to_char(round(p_target)::bigint, 'FM999,999,999')), ',', '.')
      end
  end;
$$;
revoke all on function private.challenge_title(text, double precision, text) from public, anon, authenticated;

-- Backfill: the German title is what 0003 wrote; English derived.
update public.challenges set title_de = title where title_de is null;
update public.challenges set title_en = private.challenge_title(metric, target, 'en') where title_en is null;

-- ensure_weekly_challenges now writes all three title columns. Same three
-- targets, same idempotency (one per metric per week). Cron-only: no grant.
create or replace function public.ensure_weekly_challenges(p_week_start date default date_trunc('week', now())::date)
returns int language plpgsql security definer set search_path = public as $$
declare
  n int := 0;
  w date := p_week_start;
  r record;
begin
  for r in select * from (values
      ('drop_m', 5000::double precision),
      ('run_count', 20::double precision),
      ('day_count', 3::double precision)
    ) as v(metric, target)
  loop
    if not exists (select 1 from public.challenges c where c.starts_on = w and c.metric = r.metric) then
      insert into public.challenges (title, title_de, title_en, metric, target, starts_on, ends_on)
      values (private.challenge_title(r.metric, r.target, 'de'),
              private.challenge_title(r.metric, r.target, 'de'),
              private.challenge_title(r.metric, r.target, 'en'),
              r.metric, r.target, w, w + 6);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.ensure_weekly_challenges(date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. challenge_participants — who is in; nothing else is client-writable
-- ---------------------------------------------------------------------------
create table if not exists public.challenge_participants (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
create index if not exists challenge_participants_user on public.challenge_participants(user_id);

alter table public.challenge_participants enable row level security;

drop policy if exists "participants read own" on public.challenge_participants;
create policy "participants read own" on public.challenge_participants for select
  using (auth.uid() = user_id);

-- Joining only while the challenge is still open (Europe/Vienna calendar).
drop policy if exists "participants join self" on public.challenge_participants;
create policy "participants join self" on public.challenge_participants for insert
  with check (
    auth.uid() = user_id
    and exists (select 1 from public.challenges c
                where c.id = challenge_id and c.ends_on >= (now() at time zone 'Europe/Vienna')::date)
  );

drop policy if exists "participants leave self" on public.challenge_participants;
create policy "participants leave self" on public.challenge_participants for delete
  using (auth.uid() = user_id);

revoke all on table public.challenge_participants from public, anon, authenticated;
grant select, delete on table public.challenge_participants to authenticated;
-- Column-level insert: joined_at always comes from the default.
grant insert (challenge_id, user_id) on table public.challenge_participants to authenticated;
grant all on table public.challenge_participants to service_role;

-- Migrate the 1.0.0 snapshots: whoever wrote a progress row had joined.
insert into public.challenge_participants (challenge_id, user_id, joined_at)
select cp.challenge_id, cp.user_id, cp.updated_at from public.challenge_progress cp
on conflict do nothing;

-- challenge_progress becomes read-only for clients: own rows readable and
-- deletable (deleteAccount fallback), no insert/update. Dropped next release.
drop policy if exists "progress own" on public.challenge_progress;
drop policy if exists "progress read" on public.challenge_progress;
drop policy if exists "progress read own" on public.challenge_progress;
create policy "progress read own" on public.challenge_progress for select
  using (auth.uid() = user_id);
drop policy if exists "progress delete own" on public.challenge_progress;
create policy "progress delete own" on public.challenge_progress for delete
  using (auth.uid() = user_id);
revoke all on table public.challenge_progress from public, anon, authenticated;
grant select, delete on table public.challenge_progress to authenticated;
grant all on table public.challenge_progress to service_role;

-- ---------------------------------------------------------------------------
-- 3. private.challenge_values — the one place progress is computed
-- ---------------------------------------------------------------------------
drop function if exists private.challenge_values(uuid);
create or replace function private.challenge_values(p_challenge_id uuid)
returns table (user_id uuid, value double precision, day_count bigint)
language sql security definer stable set search_path = public as $$
  select cp.user_id,
         coalesce(case c.metric
           when 'drop_m' then sum(d.drop_m)
           when 'ski_distance_m' then sum(d.ski_distance_m)
           when 'run_count' then sum(d.run_count)::double precision
           when 'max_speed_ms' then max(d.max_speed_ms)
           when 'day_count' then count(d.id)::double precision
           when 'points' then sum(d.points)::double precision
         end, 0)::double precision as value,
         count(d.id) as day_count
  from public.challenge_participants cp
  join public.challenges c on c.id = cp.challenge_id
  left join public.days d on d.user_id = cp.user_id
    and d.deleted_at is null
    and not d.suspicious
    and (d.started_at at time zone 'Europe/Vienna')::date between c.starts_on and c.ends_on
  where cp.challenge_id = p_challenge_id
  group by cp.user_id, c.metric;
$$;
revoke all on function private.challenge_values(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. challenge_board — every participant, ranked, blocked riders hidden
-- ---------------------------------------------------------------------------
drop function if exists public.challenge_board(uuid);
create or replace function public.challenge_board(p_challenge_id uuid)
returns table (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  country_code text,
  value double precision,
  done boolean,
  participants bigint,
  done_count bigint
)
language plpgsql security definer stable set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  tgt double precision;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  select c.target into tgt from public.challenges c where c.id = p_challenge_id;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0002';
  end if;
  return query
  with v as (
    select cv.user_id as uid, cv.value as val
    from private.challenge_values(p_challenge_id) cv
    where not exists (select 1 from public.blocks b where b.user_id = me and b.blocked_id = cv.user_id)
  )
  select rank() over (order by v.val desc, p.display_name, v.uid) as rank,
         v.uid,
         p.display_name,
         p.avatar_url,
         p.country_code,
         v.val,
         v.val >= tgt as done,
         count(*) over () as participants,
         count(*) filter (where v.val >= tgt) over () as done_count
  from v
  join public.profiles p on p.id = v.uid
  order by v.val desc, p.display_name, v.uid;
end;
$$;
revoke all on function public.challenge_board(uuid) from public, anon, authenticated;
grant execute on function public.challenge_board(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. my_challenge_history — ended challenges the caller joined
-- ---------------------------------------------------------------------------
drop function if exists public.my_challenge_history(int);
create or replace function public.my_challenge_history(p_limit int default 20)
returns table (
  challenge_id uuid,
  title text,
  title_de text,
  title_en text,
  metric text,
  target double precision,
  starts_on date,
  ends_on date,
  value double precision,
  done boolean,
  rank bigint,
  participants bigint,
  done_count bigint
)
language plpgsql security definer stable set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  return query
  select c.id, c.title, c.title_de, c.title_en, c.metric, c.target, c.starts_on, c.ends_on,
         r.val, r.val >= c.target, r.rnk, r.n, r.n_done
  from public.challenge_participants cp
  join public.challenges c on c.id = cp.challenge_id
  cross join lateral (
    select x.val, x.rnk, x.n, x.n_done from (
      select cv.user_id as uid, cv.value as val,
             rank() over (order by cv.value desc) as rnk,
             count(*) over () as n,
             count(*) filter (where cv.value >= c.target) over () as n_done
      from private.challenge_values(c.id) cv
    ) x where x.uid = me
  ) r
  where cp.user_id = me
    and c.ends_on < (now() at time zone 'Europe/Vienna')::date
  order by c.ends_on desc, c.metric
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
end;
$$;
revoke all on function public.my_challenge_history(int) from public, anon, authenticated;
grant execute on function public.my_challenge_history(int) to authenticated;

comment on table public.challenge_participants is
  'Who joined a weekly challenge. Own-row RLS; insert only (challenge_id, user_id) while the challenge is open. Progress is computed server-side (challenge_board).';
comment on function public.challenge_board(uuid) is
  'Participants of one challenge ranked by their value over days in starts_on..ends_on; riders blocked by the caller hidden. 42501 not_signed_in, P0002 challenge_not_found.';
comment on function public.my_challenge_history(int) is
  'Ended challenges the caller joined with final value, done, rank and participant count; newest first, p_limit clamped 1..100.';
