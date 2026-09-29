// Edge Function report-notify (migration 0014): e-mails every new
// public.reports row to the founder. Logic in handler.ts (tested with
// handler_test.ts); this file only serves it.
//
// Secrets (supabase secrets set …): REPORT_NOTIFY_SECRET (= Vault
// report_notify_secret), RESEND_API_KEY; optional REPORT_MAIL_TO,
// REPORT_MAIL_FROM. Deploy with verify_jwt = false (pg_net sends no user JWT).
import { handleReportNotify } from "./handler.ts";

Deno.serve((req) => handleReportNotify(req, Deno.env));
