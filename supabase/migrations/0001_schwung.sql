-- Schwung backend v1.5 — apply to a dedicated Supabase project.
create extension if not exists "pgcrypto";

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Skifahrer',
  avatar_url text,
  home_resort_id text,
  share_leaderboards boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.days (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  resort_id text,
  resort_name text,
  season_key text not null,
  run_count int not null default 0,
  lift_count int not null default 0,
  drop_m double precision not null default 0,
  ascent_m double precision not null default 0,
  ski_distance_m double precision not null default 0,
  lift_distance_m double precision not null default 0,
  max_speed_ms double precision not null default 0,
  avg_ski_speed_ms double precision not null default 0,
  ski_ms bigint not null default 0,
  lift_ms bigint not null default 0,
  pause_ms bigint not null default 0,
  elapsed_ms bigint not null default 0,
  max_alt_m double precision,
  min_alt_m double precision,
  engine_version int not null default 1,
  has_barometer boolean not null default false,
  vehicle_flag boolean not null default false,
  suspicious boolean generated always as (max_speed_ms > 45 or drop_m > 15000 or run_count > 80) stored,
  track_path text,
  device_updated_at timestamptz not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index days_user_started on public.days(user_id, started_at desc);
create index days_resort_season on public.days(resort_id, season_key) where deleted_at is null;

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  day date not null,
  resort_id text,
  created_by uuid not null references auth.users(id) on delete cascade,
  max_members int not null default 3,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  metric text not null check (metric in ('drop_m','ski_distance_m','run_count','day_count')),
  target double precision not null,
  starts_on date not null,
  ends_on date not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.challenge_progress (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  value double precision not null default 0,
  updated_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

-- updated_at triggers
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger days_touch before update on public.days for each row execute function public.touch_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.days enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_progress enable row level security;

create policy "profiles own" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles public read" on public.profiles for select using (true);

create policy "days own" on public.days for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "groups member read" on public.groups for select
  using (exists (select 1 from public.group_members m where m.group_id = id and m.user_id = auth.uid()) or created_by = auth.uid());
create policy "groups create" on public.groups for insert with check (created_by = auth.uid());
create policy "members read" on public.group_members for select
  using (exists (select 1 from public.group_members m where m.group_id = group_id and m.user_id = auth.uid()));
create policy "members join self" on public.group_members for insert with check (user_id = auth.uid());
create policy "members leave self" on public.group_members for delete using (user_id = auth.uid());

create policy "challenges read" on public.challenges for select using (true);
create policy "challenges create" on public.challenges for insert with check (created_by = auth.uid());
create policy "progress own" on public.challenge_progress for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "progress read" on public.challenge_progress for select using (true);

-- Leaderboard: only opted-in users, plausible days, current metric
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
      and (p_resort_id is null or d.resort_id = p_resort_id) and d.season_key = p_season_key
    group by d.user_id
  )
  select rank() over (order by a.value desc) as rank, a.user_id, p.display_name, p.avatar_url, a.value
  from agg a join public.profiles p on p.id = a.user_id
  order by a.value desc limit p_limit;
$$;

create or replace function public.group_board(p_group_id uuid)
returns table (user_id uuid, display_name text, run_count bigint, drop_m double precision, ski_distance_m double precision, max_speed_ms double precision, avg_ski_speed_ms double precision)
language sql security invoker stable as $$
  select m.user_id, p.display_name,
    coalesce(sum(d.run_count),0), coalesce(sum(d.drop_m),0), coalesce(sum(d.ski_distance_m),0),
    coalesce(max(d.max_speed_ms),0),
    case when coalesce(sum(d.ski_ms),0) > 0 then sum(d.ski_distance_m) / (sum(d.ski_ms) / 1000.0) else 0 end
  from public.group_members m
  join public.groups g on g.id = m.group_id
  join public.profiles p on p.id = m.user_id
  left join public.days d on d.user_id = m.user_id and d.deleted_at is null and not d.suspicious
    and (d.started_at at time zone 'Europe/Vienna')::date = g.day
    and (g.resort_id is null or d.resort_id = g.resort_id)
  where m.group_id = p_group_id
  group by m.user_id, p.display_name;
$$;

-- Storage bucket for raw track backups (owner only)
insert into storage.buckets (id, name, public) values ('tracks', 'tracks', false) on conflict do nothing;
create policy "tracks own" on storage.objects for all
  using (bucket_id = 'tracks' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'tracks' and (storage.foldername(name))[1] = auth.uid()::text);
