// Deletes the calling user's account completely: rows cascade from auth.users
// (profiles, days, group_members, challenge_progress) and the track backups in
// the private bucket are removed. Called by the app from AccountSheet → Konto löschen.
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.replace(/^Bearer\s+/i, "");
  if (!jwt) return new Response("missing token", { status: 401 });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const asUser = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${jwt}` } } });
  const { data: { user }, error } = await asUser.auth.getUser();
  if (error || !user) return new Response("invalid token", { status: 401 });

  const admin = createClient(url, service);
  // storage objects do not cascade
  const { data: files } = await admin.storage.from("tracks").list(user.id, { limit: 1000 });
  if (files?.length) {
    await admin.storage.from("tracks").remove(files.map((f) => `${user.id}/${f.name}`));
  }
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return new Response(delErr.message, { status: 500 });
  return new Response(JSON.stringify({ deleted: user.id }), { headers: { "Content-Type": "application/json" } });
});
