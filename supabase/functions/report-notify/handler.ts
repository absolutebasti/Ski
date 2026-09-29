// report-notify: turns a `public.reports` row (posted by the 0014 trigger via
// pg_net) into an e-mail to the founder. Pure request → response; index.ts
// wires it to Deno.serve, handler_test.ts drives it with a fake fetch.
//
// Auth: the trigger sends the Vault secret `report_notify_secret` in the
// `x-report-secret` header; it must equal REPORT_NOTIFY_SECRET. Deploy with
// verify_jwt = false — the database has no user JWT to send.
//
// Mail: Resend (https://resend.com/docs/api-reference/emails/send-email),
// RESEND_API_KEY required; REPORT_MAIL_TO / REPORT_MAIL_FROM optional.

export const DEFAULT_MAIL_TO = "hello@torchtechnology.de";
export const DEFAULT_MAIL_FROM = "SlopeTrack Meldungen <reports@torchtechnology.de>";
export const RESEND_URL = "https://api.resend.com/emails";

/** The payload built by private.reports_notify() (migration 0014). */
export interface ReportPayload {
  type?: string;
  id: string;
  reporter: string;
  reporter_name?: string | null;
  target_user_id: string;
  target_name?: string | null;
  reason: string;
  created_at?: string;
  target_reports_7d?: number;
}

export interface Env {
  get(name: string): string | undefined;
}

export interface MailRequest {
  from: string;
  to: string[];
  subject: string;
  text: string;
}

function isPayload(x: unknown): x is ReportPayload {
  if (typeof x !== "object" || x === null) return false;
  const p = x as Record<string, unknown>;
  return typeof p.id === "string" && typeof p.reporter === "string" &&
    typeof p.target_user_id === "string" && typeof p.reason === "string";
}

/** Subject + plain-text body the founder reads on the phone. */
export function buildMail(p: ReportPayload, env: Env): MailRequest {
  const target = p.target_name ? `${p.target_name} (${p.target_user_id})` : p.target_user_id;
  const reporter = p.reporter_name ? `${p.reporter_name} (${p.reporter})` : p.reporter;
  const kind = p.reason.split(":")[0].trim() || "other";
  const recent = p.target_reports_7d ?? 1;
  const subject = `[SlopeTrack] Meldung: ${kind} – ${p.target_name ?? p.target_user_id}` +
    (recent > 1 ? ` (${recent} in 7 Tagen)` : "");
  const text = [
    `Neue Meldung in SlopeTrack.`,
    ``,
    `Gemeldet:   ${target}`,
    `Von:        ${reporter}`,
    `Grund:      ${p.reason}`,
    `Zeit:       ${p.created_at ?? "–"}`,
    `Meldungen gegen diesen Rider in 7 Tagen: ${recent}`,
    ``,
    `Offene Meldungen:  select * from private.open_reports;`,
    `Erledigt markieren: update public.reports set handled_at = now() where id = '${p.id}';`,
    `Profil ansehen:    select * from public.profiles where id = '${p.target_user_id}';`,
  ].join("\n");
  return {
    from: env.get("REPORT_MAIL_FROM") ?? DEFAULT_MAIL_FROM,
    to: [env.get("REPORT_MAIL_TO") ?? DEFAULT_MAIL_TO],
    subject,
    text,
  };
}

export async function handleReportNotify(
  req: Request,
  env: Env,
  fetchFn: typeof fetch = fetch,
): Promise<Response> {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const secret = env.get("REPORT_NOTIFY_SECRET");
  if (!secret) return new Response("REPORT_NOTIFY_SECRET not configured", { status: 500 });
  const apiKey = env.get("RESEND_API_KEY");
  if (!apiKey) return new Response("RESEND_API_KEY not configured", { status: 500 });

  const given = req.headers.get("x-report-secret") ?? "";
  if (given.length === 0 || given !== secret) return new Response("forbidden", { status: 403 });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response("invalid json", { status: 400 });
  }
  // pg_net posts the row; a Database Webhook would wrap it as { record: … }.
  const payload = isPayload(body) ? body : (body as { record?: unknown })?.record;
  if (!isPayload(payload)) return new Response("invalid payload", { status: 400 });

  const mail = buildMail(payload, env);
  const res = await fetchFn(RESEND_URL, {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(mail),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    return new Response(`mail provider ${res.status}: ${detail.slice(0, 300)}`, { status: 502 });
  }
  return new Response(JSON.stringify({ sent: true, id: payload.id }), {
    headers: { "Content-Type": "application/json" },
  });
}
