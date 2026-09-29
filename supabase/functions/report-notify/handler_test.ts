// deno test supabase/functions/report-notify/
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildMail, DEFAULT_MAIL_TO, handleReportNotify, RESEND_URL } from "./handler.ts";

const payload = {
  type: "report",
  id: "2c635efd-25f7-4ee7-9f66-0d8e5c98e35c",
  reporter: "a0000000-0000-4000-8000-000000000014",
  reporter_name: "Anna",
  target_user_id: "f0000000-0000-4000-8000-000000001403",
  target_name: "Target 3",
  reason: "cheating: 9.000 hm in 10 Minuten",
  created_at: "2026-09-29T08:13:39.035944+00:00",
  target_reports_7d: 2,
};

function env(vars: Record<string, string>) {
  return { get: (name: string) => vars[name] };
}

function request(body: unknown, secret = "s3cret", method = "POST"): Request {
  return new Request("https://example.invalid/functions/v1/report-notify", {
    method,
    headers: { "Content-Type": "application/json", "x-report-secret": secret },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

/** Records the outgoing mail request and answers with `status`. */
function fakeFetch(status = 200) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fn = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return Promise.resolve(new Response(status === 200 ? '{"id":"m1"}' : "nope", { status }));
  }) as typeof fetch;
  return { fn, calls };
}

Deno.test("payload → one Resend request to the founder with all fields", async () => {
  const { fn, calls } = fakeFetch();
  const res = await handleReportNotify(request(payload), env({ REPORT_NOTIFY_SECRET: "s3cret", RESEND_API_KEY: "re_test" }), fn);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: true, id: payload.id });
  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, RESEND_URL);
  assertEquals((calls[0].init.headers as Record<string, string>)["Authorization"], "Bearer re_test");
  const mail = JSON.parse(String(calls[0].init.body));
  assertEquals(mail.to, [DEFAULT_MAIL_TO]);
  assertStringIncludes(mail.subject, "cheating");
  assertStringIncludes(mail.subject, "Target 3");
  assertStringIncludes(mail.subject, "2 in 7 Tagen");
  assertStringIncludes(mail.text, "Anna (a0000000-0000-4000-8000-000000000014)");
  assertStringIncludes(mail.text, "cheating: 9.000 hm in 10 Minuten");
  assertStringIncludes(mail.text, `handled_at = now() where id = '${payload.id}'`);
});

Deno.test("missing REPORT_NOTIFY_SECRET → 500, nothing sent", async () => {
  const { fn, calls } = fakeFetch();
  const res = await handleReportNotify(request(payload), env({ RESEND_API_KEY: "re_test" }), fn);
  assertEquals(res.status, 500);
  assertEquals(calls.length, 0);
});

Deno.test("missing RESEND_API_KEY → 500, nothing sent", async () => {
  const { fn, calls } = fakeFetch();
  const res = await handleReportNotify(request(payload), env({ REPORT_NOTIFY_SECRET: "s3cret" }), fn);
  assertEquals(res.status, 500);
  assertEquals(calls.length, 0);
});

Deno.test("wrong or missing secret header → 403", async () => {
  const { fn, calls } = fakeFetch();
  const e = env({ REPORT_NOTIFY_SECRET: "s3cret", RESEND_API_KEY: "re_test" });
  assertEquals((await handleReportNotify(request(payload, "other"), e, fn)).status, 403);
  assertEquals((await handleReportNotify(request(payload, ""), e, fn)).status, 403);
  assertEquals(calls.length, 0);
});

Deno.test("bad json / bad payload → 400; GET → 405", async () => {
  const { fn, calls } = fakeFetch();
  const e = env({ REPORT_NOTIFY_SECRET: "s3cret", RESEND_API_KEY: "re_test" });
  const broken = new Request("https://example.invalid/", { method: "POST", headers: { "x-report-secret": "s3cret" }, body: "{" });
  assertEquals((await handleReportNotify(broken, e, fn)).status, 400);
  assertEquals((await handleReportNotify(request({ hello: 1 }), e, fn)).status, 400);
  assertEquals((await handleReportNotify(request(null, "s3cret", "GET"), e, fn)).status, 405);
  assertEquals(calls.length, 0);
});

Deno.test("Database-Webhook shape { record } is accepted", async () => {
  const { fn, calls } = fakeFetch();
  const e = env({ REPORT_NOTIFY_SECRET: "s3cret", RESEND_API_KEY: "re_test", REPORT_MAIL_TO: "x@example.invalid" });
  const res = await handleReportNotify(request({ type: "INSERT", table: "reports", record: payload }), e, fn);
  assertEquals(res.status, 200);
  assertEquals(JSON.parse(String(calls[0].init.body)).to, ["x@example.invalid"]);
});

Deno.test("mail provider error → 502", async () => {
  const { fn } = fakeFetch(422);
  const res = await handleReportNotify(request(payload), env({ REPORT_NOTIFY_SECRET: "s3cret", RESEND_API_KEY: "re_test" }), fn);
  assertEquals(res.status, 502);
  assertStringIncludes(await res.text(), "422");
});

Deno.test("buildMail without names falls back to ids", () => {
  const mail = buildMail({ ...payload, reporter_name: null, target_name: null, target_reports_7d: 1 }, env({}));
  assertStringIncludes(mail.subject, payload.target_user_id);
  assertEquals(mail.subject.includes("in 7 Tagen"), false);
  assertStringIncludes(mail.text, `Von:        ${payload.reporter}`);
});
