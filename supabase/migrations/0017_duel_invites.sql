-- 0017: Duell-Einladungen in-app (docs/BACKLOG-2.md SOC-DUEL-INVITES)
--
--  1. duel_invites: one row per invitation into a Tagesduell — sender,
--     recipient, group, the duel day and a status (pending → accepted or
--     declined). Own-row RLS for reads (either side); every write goes
--     through the definer RPCs, clients have no insert/update/delete grant.
--     At most one pending invite per (group, recipient).
--  2. invite_to_duel(p_user_id, p_group_id): the caller must be a member of
--     the group, the group must not be expired (day ≥ yesterday in groups.tz),
--     the rider must exist, be somebody else, not be blocked either way, not
--     already be a member, and the duel must have room. A pending invite for
--     the same pair is returned as is (idempotent). 30 invites per sender and
--     24 h.
--  3. respond_duel_invite(p_id, p_accept): only the recipient of a pending
--     invite. Accept = join_group path (max_members → duel_full P0003,
--     duel_expired P0006; the status update rolls back with the exception) and
--     returns the group row incl. tz. Decline returns no row. Accept while a
--     block exists between sender and recipient (either direction) raises
--     rider_not_found (P0002) — nobody joins the duel of a rider who blocked
--     them or whom they blocked.
--  4. my_duel_invites(): pending invites addressed to the caller for duels
--     that are not expired and that the caller is not a member of yet, with
--     the sender's name and avatar, the group's code/name/day/tz and its
--     member count. Newest first, blocked pairs hidden.
--  5. blocks_decline_invites: a new block (either direction) declines every
--     pending invite between the two riders (after-insert trigger on
--     public.blocks, next to 0014's blocks_unfriend). Unblocking does not
--     revive them. A one-off UPDATE declines pending invites of pairs that
--     were already blocked when this section was applied.
--
-- Errors: 42501 not_signed_in / not_a_member, P0002 rider_not_found /
-- invite_not_found, 23505 already_member, P0003 duel_full, P0006
-- duel_expired, P0005 rate_limited.
--
-- Definer pattern (docs/BACKEND.md): every function revokes and grants
-- itself, policies use private.* helpers, RPCs use auth.uid(). Idempotent;
-- drops no table, deletes no rows.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- 1. duel_invites
-- ---------------------------------------------------------------------------
create table if not exists public.duel_invites (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users (id) on delete cascade,
  to_user uuid not null references auth.users (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  day date not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint duel_invites_status_check check (status in ('pending', 'accepted', 'declined')),
  constraint duel_invites_not_self check (from_user <> to_user)
);

create unique index if not exists duel_invites_pending_once
  on public.duel_invites (group_id, to_user) where status = 'pending';
create index if not exists duel_invites_to_user_status on public.duel_invites (to_user, status);
create index if not exists duel_invites_from_user_created on public.duel_invites (from_user, created_at);

alter table public.duel_invites enable row level security;

drop policy if exists "duel_invites read own" on public.duel_invites;
create policy "duel_invites read own" on public.duel_invites for select
  using (from_user = auth.uid() or to_user = auth.uid());

revoke all on table public.duel_invites from public, anon, authenticated;
grant select on table public.duel_invites to authenticated;
grant all on table public.duel_invites to service_role;

comment on table public.duel_invites is
  'In-app invitations into a Tagesduell (0017). Reads: own rows (sender or recipient). Writes only via invite_to_duel / respond_duel_invite. One pending invite per (group, recipient).';

-- ---------------------------------------------------------------------------
-- 2. invite_to_duel
-- ---------------------------------------------------------------------------
drop function if exists public.invite_to_duel(uuid, uuid);
create or replace function public.invite_to_duel(p_user_id uuid, p_group_id uuid)
returns table (id uuid, from_user uuid, to_user uuid, group_id uuid, day date, status text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  max_per_day constant int := 30;
  me uuid := auth.uid();
  g public.groups%rowtype;
  inv public.duel_invites%rowtype;
  v_today date;
  n int;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = me then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  select * into g from public.groups where groups.id = p_group_id;
  if not found or not exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = me) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  v_today := (now() at time zone g.tz)::date;
  if g.day < v_today - 1 then
    raise exception 'duel_expired' using errcode = 'P0006';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id)
     or exists (select 1 from public.blocks b
                where (b.user_id = me and b.blocked_id = p_user_id)
                   or (b.user_id = p_user_id and b.blocked_id = me)) then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = p_user_id) then
    raise exception 'already_member' using errcode = '23505';
  end if;
  select count(*) into n from public.group_members m where m.group_id = g.id;
  if n >= g.max_members then
    raise exception 'duel_full' using errcode = 'P0003';
  end if;
  -- idempotent: the pending invite of this pair is the answer
  select * into inv from public.duel_invites i
    where i.group_id = g.id and i.to_user = p_user_id and i.status = 'pending';
  if found then
    return query select inv.id, inv.from_user, inv.to_user, inv.group_id, inv.day, inv.status, inv.created_at;
    return;
  end if;
  select count(*) into n from public.duel_invites i
    where i.from_user = me and i.created_at > now() - interval '24 hours';
  if n >= max_per_day then
    raise exception 'rate_limited' using errcode = 'P0005';
  end if;
  insert into public.duel_invites (from_user, to_user, group_id, day)
    values (me, p_user_id, g.id, g.day)
    returning * into inv;
  return query select inv.id, inv.from_user, inv.to_user, inv.group_id, inv.day, inv.status, inv.created_at;
end;
$$;
revoke all on function public.invite_to_duel(uuid, uuid) from public, anon, authenticated;
grant execute on function public.invite_to_duel(uuid, uuid) to authenticated;
comment on function public.invite_to_duel(uuid, uuid) is
  'Invites a rider into one of the caller''s duels; returns the (possibly existing) pending invite. 42501 not_signed_in/not_a_member, P0002 rider_not_found, 23505 already_member, P0003 duel_full, P0006 duel_expired, P0005 rate_limited (30 per 24 h).';

-- ---------------------------------------------------------------------------
-- 3. respond_duel_invite
-- ---------------------------------------------------------------------------
drop function if exists public.respond_duel_invite(uuid, boolean);
create or replace function public.respond_duel_invite(p_id uuid, p_accept boolean)
returns table (id uuid, code text, name text, day date, resort_id text, created_by uuid, max_members int, tz text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  inv public.duel_invites%rowtype;
  g public.groups%rowtype;
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  select * into inv from public.duel_invites i
    where i.id = p_id and i.to_user = me and i.status = 'pending';
  if not found then
    raise exception 'invite_not_found' using errcode = 'P0002';
  end if;
  if not coalesce(p_accept, false) then
    update public.duel_invites i set status = 'declined' where i.id = inv.id;
    return;
  end if;
  -- a block in either direction closes the door (the block trigger declines
  -- pending invites; this also covers a block racing the accept)
  if exists (select 1 from public.blocks b
             where (b.user_id = me and b.blocked_id = inv.from_user)
                or (b.user_id = inv.from_user and b.blocked_id = me)) then
    raise exception 'rider_not_found' using errcode = 'P0002';
  end if;
  select * into g from public.groups where groups.id = inv.group_id;
  if not found then
    raise exception 'invite_not_found' using errcode = 'P0002';
  end if;
  update public.duel_invites i set status = 'accepted' where i.id = inv.id;
  -- join_group enforces duel_expired (P0006) and max_members (P0003); an
  -- exception there rolls the status update back with it.
  perform public.join_group(g.code);
  return query select g.id, g.code, g.name, g.day, g.resort_id, g.created_by, g.max_members, g.tz;
end;
$$;
revoke all on function public.respond_duel_invite(uuid, boolean) from public, anon, authenticated;
grant execute on function public.respond_duel_invite(uuid, boolean) to authenticated;
comment on function public.respond_duel_invite(uuid, boolean) is
  'Recipient accepts (join_group path; returns the group row incl. tz) or declines (no row) a pending invite. 42501 not_signed_in, P0002 invite_not_found / rider_not_found (block between sender and recipient, either direction), P0003 duel_full, P0006 duel_expired.';

-- ---------------------------------------------------------------------------
-- 4. my_duel_invites
-- ---------------------------------------------------------------------------
drop function if exists public.my_duel_invites();
create or replace function public.my_duel_invites()
returns table (
  id uuid,
  from_user uuid,
  from_name text,
  from_avatar_url text,
  group_id uuid,
  code text,
  name text,
  day date,
  tz text,
  member_count bigint,
  max_members int,
  created_at timestamptz
)
language plpgsql security definer stable set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  return query
  select i.id, i.from_user, p.display_name, p.avatar_url,
         g.id, g.code, g.name, g.day, g.tz,
         (select count(*) from public.group_members mm where mm.group_id = g.id),
         g.max_members, i.created_at
  from public.duel_invites i
  join public.groups g on g.id = i.group_id
  join public.profiles p on p.id = i.from_user
  where i.to_user = me
    and i.status = 'pending'
    and g.day >= (now() at time zone g.tz)::date - 1
    and not exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = me)
    and not exists (select 1 from public.blocks b
                    where (b.user_id = me and b.blocked_id = i.from_user)
                       or (b.user_id = i.from_user and b.blocked_id = me))
  order by i.created_at desc
  limit 20;
end;
$$;
revoke all on function public.my_duel_invites() from public, anon, authenticated;
grant execute on function public.my_duel_invites() to authenticated;
comment on function public.my_duel_invites() is
  'Pending invites addressed to the caller (duel not expired, caller not a member yet, blocked pairs hidden), newest first, with sender name/avatar and the group incl. member_count. 42501 not_signed_in.';

-- ---------------------------------------------------------------------------
-- 5. A block declines the pending invites of the pair
-- ---------------------------------------------------------------------------
create or replace function private.blocks_decline_invites()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.duel_invites i set status = 'declined'
    where i.status = 'pending'
      and ((i.from_user = new.user_id and i.to_user = new.blocked_id)
        or (i.from_user = new.blocked_id and i.to_user = new.user_id));
  return new;
end;
$$;
revoke all on function private.blocks_decline_invites() from public, anon, authenticated;

drop trigger if exists blocks_decline_invites on public.blocks;
create trigger blocks_decline_invites after insert on public.blocks
  for each row execute function private.blocks_decline_invites();

-- pairs that were blocked before this trigger existed (UPDATE only; no-op on
-- re-apply)
update public.duel_invites i set status = 'declined'
  where i.status = 'pending'
    and exists (select 1 from public.blocks b
                where (b.user_id = i.from_user and b.blocked_id = i.to_user)
                   or (b.user_id = i.to_user and b.blocked_id = i.from_user));

-- PostgREST picks up the new table and RPCs.
notify pgrst, 'reload schema';
