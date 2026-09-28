-- 0006b: sync of a full local history (up to 200 days) must not trip the
-- per-hour throttle; 200 upserts/hour per user still stops scripted abuse.
create or replace function public.days_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  max_days_per_date constant int := 3;
  max_writes_per_hour constant int := 200;
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
