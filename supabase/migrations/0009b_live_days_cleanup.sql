-- 0009b: live_days rows are transient (today's duel numbers); drop rows older
-- than two days every morning so the table stays tiny. Nothing else is deleted.
select cron.unschedule(jobid) from cron.job where jobname = 'live-days-cleanup';
select cron.schedule('live-days-cleanup', '0 5 * * *', $$delete from public.live_days where day < current_date - 2$$);
