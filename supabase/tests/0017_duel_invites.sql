-- Smoke test for migration 0017 (duel_invites: invite_to_duel,
-- respond_duel_invite, my_duel_invites, RLS + grants, block trigger). One transaction,
-- rolled back at the end — safe against the live project
-- (tools/supabase-test.sh, pattern of 0014_moderation_blocks.sql).
--
-- Seed: Anna, Bernd, Chris, Dora (all opted in) + 30 targets for the rate
-- limit; Anna's duel of today (Anna the only member), an expired duel of
-- Anna (five days ago).

begin;

create temporary table t_results (n serial, test text) on commit drop;
grant all on table t_results to public;
grant all on sequence t_results_n_seq to public;

create function pg_temp.login(p_uid uuid, p_role text default 'authenticated') returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims',
    case when p_uid is null then json_build_object('role', p_role)::text
         else json_build_object('sub', p_uid, 'role', p_role)::text end, true);
  perform set_config('role', p_role, true);
end;
$$;

create function pg_temp.pass(p_test text) returns void language sql as $$
  insert into t_results (test) values (p_test);
$$;

create temporary table t_ids (k text primary key, id uuid not null) on commit drop;
grant select on table t_ids to public;
insert into t_ids values
  ('anna',  'a0000000-0000-4000-8000-000000000017'),
  ('bernd', 'b0000000-0000-4000-8000-000000000017'),
  ('chris', 'c0000000-0000-4000-8000-000000000017'),
  ('dora',  'e0000000-0000-4000-8000-000000000017'),
  ('duel',  'd0000000-0000-4000-8000-000000000017'),
  ('old',   'd0000000-0000-4000-8000-000000000117');
insert into t_ids select 'target' || i, ('f0000000-0000-4000-8000-' || lpad((1700 + i)::text, 12, '0'))::uuid
from generate_series(1, 30) i;

create function pg_temp.id(p_k text) returns uuid language sql stable as $$
  select id from t_ids where k = p_k;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.k || '@test17.slopetrack.invalid', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
       '', '', '', ''
from t_ids u where u.k not in ('duel', 'old');

insert into public.profiles (id, display_name, share_leaderboards, country_code) values
  (pg_temp.id('anna'),  'Anna',  true, 'DE'),
  (pg_temp.id('bernd'), 'Bernd', true, 'AT'),
  (pg_temp.id('chris'), 'Chris', true, 'DE'),
  (pg_temp.id('dora'),  'Dora',  true, 'CH');
insert into public.profiles (id, display_name, share_leaderboards, country_code)
select pg_temp.id('target' || i), 'Target ' || i, true, 'CH' from generate_series(1, 30) i;

insert into public.groups (id, code, name, day, resort_id, created_by, max_members, tz)
values (pg_temp.id('duel'), 'TST017', 'Annas Duell', (now() at time zone 'Europe/Vienna')::date, null, pg_temp.id('anna'), 3, 'Europe/Vienna'),
       (pg_temp.id('old'),  'TST117', 'Altes Duell', (now() at time zone 'Europe/Vienna')::date - 5, null, pg_temp.id('anna'), 3, 'Europe/Vienna');
insert into public.group_members (group_id, user_id) values
  (pg_temp.id('duel'), pg_temp.id('anna')),
  (pg_temp.id('old'),  pg_temp.id('anna'));

-- ---------------------------------------------------------------------------
-- T1  Anna invites Bernd → Bernd's my_duel_invites lists it (sender name,
--     code, 1 / 3); a second invite is the same row; Chris reads nothing and
--     cannot respond; Bernd accepts → member, invite accepted and gone.
-- ---------------------------------------------------------------------------
do $$
declare r record; r2 record; n int; ok boolean := false; inv_id uuid;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select * into r from public.invite_to_duel(pg_temp.id('bernd'), pg_temp.id('duel'));
  if r.id is null or r.status <> 'pending' or r.from_user <> pg_temp.id('anna') or r.to_user <> pg_temp.id('bernd')
     or r.day <> (now() at time zone 'Europe/Vienna')::date then
    raise exception 'T1: invite row wrong: %', r;
  end if;
  inv_id := r.id;
  select * into r2 from public.invite_to_duel(pg_temp.id('bernd'), pg_temp.id('duel'));
  if r2.id <> inv_id then raise exception 'T1: a second invite must return the pending one'; end if;
  select count(*) into n from public.my_duel_invites();
  if n <> 0 then raise exception 'T1: the sender has no invites of their own, got %', n; end if;

  perform pg_temp.login(pg_temp.id('bernd'));
  select count(*) into n from public.my_duel_invites();
  if n <> 1 then raise exception 'T1: bernd should see one invite, got %', n; end if;
  select * into r from public.my_duel_invites();
  if r.id <> inv_id or r.from_name <> 'Anna' or r.code <> 'TST017' or r.name <> 'Annas Duell'
     or r.member_count <> 1 or r.max_members <> 3 or r.tz <> 'Europe/Vienna' or r.group_id <> pg_temp.id('duel') then
    raise exception 'T1: my_duel_invites row wrong: %', r;
  end if;
  select count(*) into n from public.duel_invites;
  if n <> 1 then raise exception 'T1: bernd must read his own invite row via RLS, got %', n; end if;

  -- Chris is neither side: nothing to read, nothing to answer
  perform pg_temp.login(pg_temp.id('chris'));
  select count(*) into n from public.duel_invites;
  if n <> 0 then raise exception 'T1: chris must not read the anna→bernd invite'; end if;
  select count(*) into n from public.my_duel_invites();
  if n <> 0 then raise exception 'T1: chris has no invites'; end if;
  begin
    perform public.respond_duel_invite(inv_id, true);
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T1: chris responding to a foreign invite must raise invite_not_found'; end if;
  reset role;
  select count(*) into n from public.group_members m where m.group_id = pg_temp.id('duel');
  if n <> 1 then raise exception 'T1: chris must not have joined, members = %', n; end if;

  -- Bernd accepts
  perform pg_temp.login(pg_temp.id('bernd'));
  select * into r from public.respond_duel_invite(inv_id, true);
  if r.id <> pg_temp.id('duel') or r.code <> 'TST017' or r.tz <> 'Europe/Vienna' or r.max_members <> 3 then
    raise exception 'T1: accept must return the group row, got %', r;
  end if;
  select count(*) into n from public.group_members m where m.group_id = pg_temp.id('duel') and m.user_id = pg_temp.id('bernd');
  if n <> 1 then raise exception 'T1: bernd must be a member after accepting'; end if;
  select count(*) into n from public.my_duel_invites();
  if n <> 0 then raise exception 'T1: an accepted invite must leave my_duel_invites'; end if;
  select count(*) into n from public.group_board(pg_temp.id('duel'));
  if n <> 2 then raise exception 'T1: duel board should have 2 members, got %', n; end if;
  ok := false;
  begin
    perform public.respond_duel_invite(inv_id, true);
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T1: answering twice must raise invite_not_found'; end if;

  reset role;
  select status into r from public.duel_invites where id = inv_id;
  if r.status <> 'accepted' then raise exception 'T1: status should be accepted, got %', r.status; end if;
  perform pg_temp.pass('T1 invite → my_duel_invites (name, code, 1 / 3) → accept joins; idempotent; third party reads/answers nothing');
end $$;

-- ---------------------------------------------------------------------------
-- T2  Guards: non-member → not_a_member; self → rider_not_found; already a
--     member → already_member; blocked either way → rider_not_found; expired
--     duel → duel_expired; unknown rider → rider_not_found.
-- ---------------------------------------------------------------------------
do $$
declare ok boolean := false;
begin
  perform pg_temp.login(pg_temp.id('chris'));
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel'));
  exception when sqlstate '42501' then ok := true;
  end;
  if not ok then raise exception 'T2: a non-member must not invite (not_a_member)'; end if;

  perform pg_temp.login(pg_temp.id('anna'));
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('anna'), pg_temp.id('duel'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: self-invite must raise rider_not_found'; end if;
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('bernd'), pg_temp.id('duel'));
  exception when unique_violation then
    if sqlerrm <> 'already_member' then raise exception 'T2: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T2: inviting a member must raise already_member'; end if;
  ok := false;
  begin
    perform public.invite_to_duel('00000000-0000-4000-8000-000000000000'::uuid, pg_temp.id('duel'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: unknown rider must raise rider_not_found'; end if;
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('old'));
  exception when sqlstate 'P0006' then ok := true;
  end;
  if not ok then raise exception 'T2: an expired duel must raise duel_expired'; end if;

  -- Dora blocks Anna → Anna cannot invite Dora; the other direction too
  perform pg_temp.login(pg_temp.id('dora'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('dora'), pg_temp.id('anna'));
  perform pg_temp.login(pg_temp.id('anna'));
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: inviting a rider who blocked you must raise rider_not_found'; end if;
  perform pg_temp.login(pg_temp.id('dora'));
  delete from public.blocks where user_id = pg_temp.id('dora');
  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('anna'), pg_temp.id('dora'));
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel'));
  exception when sqlstate 'P0002' then ok := true;
  end;
  if not ok then raise exception 'T2: inviting a rider you blocked must raise rider_not_found'; end if;
  delete from public.blocks where user_id = pg_temp.id('anna');
  perform pg_temp.pass('T2 guards: not_a_member, self, already_member, unknown, duel_expired, blocked both ways');
end $$;

-- ---------------------------------------------------------------------------
-- T3  Capacity: Anna invites Chris and Dora; Chris accepts (3 / 3); Dora's
--     accept → duel_full and her invite stays pending; Dora declines → gone;
--     inviting into a full duel → duel_full. (Blocks: T6.)
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean := false; chris_inv uuid; dora_inv uuid;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select id into chris_inv from public.invite_to_duel(pg_temp.id('chris'), pg_temp.id('duel'));
  select id into dora_inv from public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel'));

  perform pg_temp.login(pg_temp.id('chris'));
  perform public.respond_duel_invite(chris_inv, true);
  select count(*) into n from public.group_members m where m.group_id = pg_temp.id('duel');
  if n <> 3 then raise exception 'T3: duel should be full now, got %', n; end if;

  perform pg_temp.login(pg_temp.id('dora'));
  select * into r from public.my_duel_invites();
  if r.id <> dora_inv or r.member_count <> 3 then raise exception 'T3: dora should see the full duel invite, got %', r; end if;
  begin
    perform public.respond_duel_invite(dora_inv, true);
  exception when sqlstate 'P0003' then ok := true;
  end;
  if not ok then raise exception 'T3: the 4th member must raise duel_full'; end if;
  select count(*) into n from public.group_members m where m.group_id = pg_temp.id('duel') and m.user_id = pg_temp.id('dora');
  if n <> 0 then raise exception 'T3: dora must not be a member'; end if;
  reset role;
  select status into r from public.duel_invites where id = dora_inv;
  if r.status <> 'pending' then raise exception 'T3: a failed accept must leave the invite pending, got %', r.status; end if;

  -- decline
  perform pg_temp.login(pg_temp.id('dora'));
  select count(*) into n from public.respond_duel_invite(dora_inv, false);
  if n <> 0 then raise exception 'T3: decline returns no row'; end if;
  select count(*) into n from public.my_duel_invites();
  if n <> 0 then raise exception 'T3: a declined invite must leave my_duel_invites'; end if;
  reset role;
  select status into r from public.duel_invites where id = dora_inv;
  if r.status <> 'declined' then raise exception 'T3: status should be declined, got %', r.status; end if;

  -- inviting into a full duel
  perform pg_temp.login(pg_temp.id('anna'));
  ok := false;
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel'));
  exception when sqlstate 'P0003' then ok := true;
  end;
  if not ok then raise exception 'T3: inviting into a full duel must raise duel_full'; end if;
  perform pg_temp.pass('T3 accept on a 4th member → duel_full (invite stays pending); decline; full duel rejects invites');
end $$;

-- ---------------------------------------------------------------------------
-- T4  Rate limit: 30 invites per sender and 24 h, the 31st → rate_limited.
-- ---------------------------------------------------------------------------
do $$
declare n int; i int; ok boolean := false; g_id uuid;
begin
  -- a fresh duel of Bernd with room; Bernd has sent nothing yet
  perform pg_temp.login(pg_temp.id('bernd'));
  select id into g_id from public.create_duel('Limit', null, 'Europe/Vienna', null);
  for i in 1..30 loop
    perform public.invite_to_duel(pg_temp.id('target' || i), g_id);
  end loop;
  select count(*) into n from public.duel_invites where from_user = pg_temp.id('bernd');
  if n <> 30 then raise exception 'T4: 30 invites expected, got %', n; end if;
  begin
    perform public.invite_to_duel(pg_temp.id('dora'), g_id);
  exception when sqlstate 'P0005' then ok := true;
  end;
  if not ok then raise exception 'T4: the 31st invite must raise rate_limited'; end if;
  -- an existing pending invite is still returned (idempotent path, no new row)
  select count(*) into n from public.invite_to_duel(pg_temp.id('target1'), g_id);
  if n <> 1 then raise exception 'T4: the existing invite must still be returned'; end if;
  perform pg_temp.pass('T4 rate limit: 30 invites per 24 h, 31st → rate_limited');
end $$;

-- ---------------------------------------------------------------------------
-- T5  Grants: anon denied everywhere; authenticated cannot write the table
--     directly; the three RPCs are granted to authenticated only.
-- ---------------------------------------------------------------------------
do $$
declare denied int := 0; ok boolean := false; bad text; n int;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  begin
    insert into public.duel_invites (from_user, to_user, group_id, day) values (pg_temp.id('anna'), pg_temp.id('dora'), pg_temp.id('duel'), current_date);
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: direct insert must be denied'; end if;
  ok := false;
  begin
    update public.duel_invites set status = 'accepted' where from_user = pg_temp.id('anna');
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: direct update must be denied'; end if;
  ok := false;
  begin
    delete from public.duel_invites where from_user = pg_temp.id('anna');
  exception when insufficient_privilege then ok := true;
  end;
  if not ok then raise exception 'T5: direct delete must be denied'; end if;
  select count(*) into n from public.duel_invites where from_user = pg_temp.id('anna');
  if n <> 3 then raise exception 'T5: anna reads her own 3 sent invites, got %', n; end if;

  perform pg_temp.login(null, 'anon');
  begin perform count(*) from public.duel_invites; exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.my_duel_invites(); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.invite_to_duel(pg_temp.id('dora'), pg_temp.id('duel')); exception when insufficient_privilege then denied := denied + 1; end;
  begin perform public.respond_duel_invite(gen_random_uuid(), true); exception when insufficient_privilege then denied := denied + 1; end;
  if denied <> 4 then raise exception 'T5: anon should be denied 4 times, got %', denied; end if;

  reset role;
  select string_agg(sig, ', ') into bad from unnest(array[
      'public.invite_to_duel(uuid, uuid)', 'public.respond_duel_invite(uuid, boolean)', 'public.my_duel_invites()']) sig
  where not has_function_privilege('authenticated', to_regprocedure(sig), 'execute')
     or has_function_privilege('anon', to_regprocedure(sig), 'execute');
  if bad is not null then raise exception 'T5: grants wrong on: %', bad; end if;
  if has_table_privilege('anon', 'public.duel_invites', 'select') then raise exception 'T5: anon must not select duel_invites'; end if;
  if has_table_privilege('authenticated', 'public.duel_invites', 'insert') then raise exception 'T5: authenticated must not insert duel_invites'; end if;
  perform pg_temp.pass('T5 grants: anon denied, table read-only for clients, RPCs authenticated only');
end $$;

-- ---------------------------------------------------------------------------
-- T6  Blocks: a new block (recipient → sender and sender → recipient)
--     declines the pending invite of that pair only, unblocking does not
--     revive it; accepting a pending invite while a block exists (legacy row /
--     race, seeded as postgres) → rider_not_found in both directions, no
--     membership; without the block the same invite joins.
-- ---------------------------------------------------------------------------
do $$
declare r record; n int; ok boolean; g_id uuid; dora_inv uuid; chris_inv uuid; late_inv uuid;
begin
  perform pg_temp.login(pg_temp.id('anna'));
  select id into g_id from public.create_duel('Block', null, 'Europe/Vienna', null);
  select id into dora_inv from public.invite_to_duel(pg_temp.id('dora'), g_id);
  select id into chris_inv from public.invite_to_duel(pg_temp.id('chris'), g_id);

  -- recipient blocks sender → declined; the anna→chris invite is untouched
  perform pg_temp.login(pg_temp.id('dora'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('dora'), pg_temp.id('anna'));
  reset role;
  select status into r from public.duel_invites where id = dora_inv;
  if r.status <> 'declined' then raise exception 'T6: a block by the recipient must decline the invite, got %', r.status; end if;
  select status into r from public.duel_invites where id = chris_inv;
  if r.status <> 'pending' then raise exception 'T6: an unrelated invite must stay pending, got %', r.status; end if;
  perform pg_temp.login(pg_temp.id('dora'));
  ok := false;
  begin
    perform public.respond_duel_invite(dora_inv, true);
  exception when sqlstate 'P0002' then
    if sqlerrm <> 'invite_not_found' then raise exception 'T6: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T6: a declined invite cannot be accepted'; end if;
  delete from public.blocks where user_id = pg_temp.id('dora');
  select count(*) into n from public.my_duel_invites();
  if n <> 0 then raise exception 'T6: unblocking must not revive the invite, got %', n; end if;

  -- sender blocks recipient → declined as well
  perform pg_temp.login(pg_temp.id('anna'));
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('anna'), pg_temp.id('chris'));
  reset role;
  select status into r from public.duel_invites where id = chris_inv;
  if r.status <> 'declined' then raise exception 'T6: a block by the sender must decline the invite, got %', r.status; end if;
  perform pg_temp.login(pg_temp.id('anna'));
  delete from public.blocks where user_id = pg_temp.id('anna');

  -- a pending invite that coexists with a block (predates the trigger or
  -- races it): accept → rider_not_found, whichever side blocked
  reset role;
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('dora'), pg_temp.id('anna'));
  insert into public.duel_invites (from_user, to_user, group_id, day)
    select pg_temp.id('anna'), pg_temp.id('dora'), g.id, g.day from public.groups g where g.id = g_id
    returning id into late_inv;
  perform pg_temp.login(pg_temp.id('dora'));
  ok := false;
  begin
    perform public.respond_duel_invite(late_inv, true);
  exception when sqlstate 'P0002' then
    if sqlerrm <> 'rider_not_found' then raise exception 'T6: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T6: accepting the invite of a rider you blocked must raise rider_not_found'; end if;
  reset role;
  delete from public.blocks where user_id = pg_temp.id('dora') and blocked_id = pg_temp.id('anna');
  insert into public.blocks (user_id, blocked_id) values (pg_temp.id('anna'), pg_temp.id('dora'));
  -- the trigger just declined late_inv → seed the coexisting row once more
  select status into r from public.duel_invites where id = late_inv;
  if r.status <> 'declined' then raise exception 'T6: the sender''s block must decline the pending invite, got %', r.status; end if;
  insert into public.duel_invites (from_user, to_user, group_id, day)
    select pg_temp.id('anna'), pg_temp.id('dora'), g.id, g.day from public.groups g where g.id = g_id
    returning id into late_inv;
  perform pg_temp.login(pg_temp.id('dora'));
  ok := false;
  begin
    perform public.respond_duel_invite(late_inv, true);
  exception when sqlstate 'P0002' then
    if sqlerrm <> 'rider_not_found' then raise exception 'T6: wrong message %', sqlerrm; end if;
    ok := true;
  end;
  if not ok then raise exception 'T6: accepting the invite of a rider who blocked you must raise rider_not_found'; end if;
  reset role;
  select count(*) into n from public.group_members m where m.group_id = g_id and m.user_id = pg_temp.id('dora');
  if n <> 0 then raise exception 'T6: a blocked accept must not join'; end if;
  select status into r from public.duel_invites where id = late_inv;
  if r.status <> 'pending' then raise exception 'T6: a rejected accept leaves the row alone, got %', r.status; end if;

  -- block gone → the same invite joins
  delete from public.blocks where user_id = pg_temp.id('anna') and blocked_id = pg_temp.id('dora');
  perform pg_temp.login(pg_temp.id('dora'));
  select * into r from public.respond_duel_invite(late_inv, true);
  if r.id <> g_id then raise exception 'T6: accept without a block must join, got %', r; end if;
  perform pg_temp.pass('T6 blocks: new block declines the pair''s pending invites (both directions, not revived); accept across a block → rider_not_found');
end $$;

reset role;
select n, test from t_results order by n;

rollback;
