-- 0016: public teaser for the signed-out Rangliste (docs/BACKLOG-2.md SOC-TEASER)
--
--  public_board_teaser(p_resort_id, p_season_key) — the top 10 opted-in
--  riders by points for one resort (null = every resort) and one season /
--  month / week key. The only RPC in `public` that `anon` may execute: the
--  app shows it as a preview before a Konto exists. It returns rank,
--  display_name, avatar_url and value (points) — never user_id, never the
--  country, never last_day/day_count — so nothing on the row can be turned
--  into a profile lookup without signing in.
--
--  Source of truth stays private.board (0014): opted-in profiles only
--  (share_leaderboards), plausible days (deleted_at is null, not suspicious),
--  the season window via private.season_match. auth.uid() is null for anon,
--  so the block test in private.board matches nothing — a public preview has
--  no viewer to hide riders from.
--
--  Cost ceiling / rate limit. Verified on the live project: a
--  `set statement_timeout` on the function itself does NOT cap the call —
--  Postgres arms the statement timer when the top-level statement starts,
--  a SET inside the function comes too late (a 100 ms function-level setting
--  let a 400 ms pg_sleep through). What does cap it is the role setting that
--  PostgREST applies per request: `anon` runs with statement_timeout = 3 s,
--  `authenticated` with 8 s (Supabase defaults, `select rolconfig from
--  pg_roles`). The call itself is bounded (limit 10 over the ranked set of
--  one resort/season); the client caches the result per query and refetches
--  at most on pull-to-refresh / tab re-entry after 5 min. A per-IP counter
--  is not needed for a read that costs one aggregate; revisit if the
--  Postgres logs show anon hammering it.
--
-- Idempotent; drops no table, deletes no row. Definer pattern per
-- docs/BACKEND.md: the function revokes and grants itself.

drop function if exists public.public_board_teaser(text, text);
create or replace function public.public_board_teaser(p_resort_id text, p_season_key text)
returns table (rank bigint, display_name text, avatar_url text, value double precision)
language plpgsql security definer stable set search_path = public as $$
begin
  if p_season_key is null or btrim(p_season_key) = '' then
    raise exception 'bad_season_key' using errcode = '22023';
  end if;
  return query
  select b.rank, b.display_name, b.avatar_url, b.value
  from private.board(nullif(btrim(p_resort_id), ''), p_season_key, 'points', null) b
  order by b.rank, b.display_name, b.user_id
  limit 10;
end;
$$;
revoke all on function public.public_board_teaser(text, text) from public, anon, authenticated;
grant execute on function public.public_board_teaser(text, text) to anon, authenticated;
comment on function public.public_board_teaser(text, text) is
  'Signed-out preview: top 10 opted-in riders by points for a resort (null = all) and season/month/week key. No user_id. Callable by anon — the one exception to "anon gets nothing" (0014); cost capped by the anon role statement_timeout (3 s).';

-- PostgREST picks up the new function.
notify pgrst, 'reload schema';
