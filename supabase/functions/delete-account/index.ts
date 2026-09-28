// Deletes the calling user's account completely. Called by the app from
// AccountSheet → Konto löschen (auth_service.dart `deleteAccount`).
//
// Order matters: storage objects do not cascade from auth.users, so every
// object under tracks/<uid> and avatars/<uid> is removed FIRST (paged, until
// the folder is empty); any list/remove error returns 500 and keeps the auth
// user, so the client can retry. Only then is the auth user deleted — rows in
// profiles, days, group_members, challenge_progress, reports, blocks and
// day_write_counters cascade, groups.created_by becomes null (0006).
import { createClient } from "npm:@supabase/supabase-js@2";

/** Buckets that hold per-user folders `<bucket>/<uid>/…`. */
export const USER_BUCKETS = ["tracks", "avatars"] as const;

/** Page size of storage.list; Supabase caps it at 1000. */
export const PAGE_SIZE = 1000;

/** Safety cap so a storage API that keeps returning the same page cannot loop forever. */
export const MAX_PAGES = 500;

export interface StorageEntry {
  name: string;
  /** null for (virtual) folders, set for real objects. */
  id: string | null;
}

/** The slice of the Storage API this function uses — a fake implements it in tests. */
export interface StorageBucketLike {
  list(prefix: string, options?: { limit?: number; offset?: number }): Promise<{ data: StorageEntry[] | null; error: { message: string } | null }>;
  remove(paths: string[]): Promise<{ data: unknown; error: { message: string } | null }>;
}

export interface Deps {
  /** Resolves the JWT to a user id, null when the token is missing/invalid/expired. */
  userIdFromJwt(jwt: string): Promise<string | null>;
  storage(bucket: string): StorageBucketLike;
  deleteUser(userId: string): Promise<{ error: { message: string } | null }>;
}

export type RemoveResult = { removed: number; error?: string };

/**
 * Removes every object under `prefix` in `bucket`, sub-folders included.
 * Lists from offset 0 again after each removal until the folder is empty, so
 * folders with more than PAGE_SIZE objects are drained completely.
 */
export async function removePrefix(storage: Deps["storage"], bucket: string, prefix: string): Promise<RemoveResult> {
  let removed = 0;
  let lastPage = "";
  for (let page = 0; page < MAX_PAGES; page++) {
    const { data, error } = await storage(bucket).list(prefix, { limit: PAGE_SIZE, offset: 0 });
    if (error) return { removed, error: `list ${bucket}/${prefix}: ${error.message}` };
    if (!data || data.length === 0) return { removed };

    // A page identical to the previous one means remove() did not take effect.
    const signature = data.map((e) => e.name).join("\n");
    if (signature === lastPage) return { removed, error: `remove ${bucket}/${prefix}: no progress` };
    lastPage = signature;

    for (const folder of data.filter((e) => e.id === null)) {
      const sub = await removePrefix(storage, bucket, `${prefix}/${folder.name}`);
      removed += sub.removed;
      if (sub.error) return { removed, error: sub.error };
    }
    const paths = data.filter((e) => e.id !== null).map((e) => `${prefix}/${e.name}`);
    if (paths.length > 0) {
      const { error: rmErr } = await storage(bucket).remove(paths);
      if (rmErr) return { removed, error: `remove ${bucket}/${prefix}: ${rmErr.message}` };
      removed += paths.length;
    }
  }
  return { removed, error: `remove ${bucket}/${prefix}: exceeded ${MAX_PAGES} pages` };
}

export async function handleDeleteAccount(req: Request, deps: Deps): Promise<Response> {
  const auth = req.headers.get("Authorization") ?? "";
  const jwt = auth.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return new Response("missing token", { status: 401 });

  const userId = await deps.userIdFromJwt(jwt);
  if (!userId) return new Response("invalid token", { status: 401 });

  const removed: Record<string, number> = {};
  for (const bucket of USER_BUCKETS) {
    const result = await removePrefix(deps.storage, bucket, userId);
    removed[bucket] = result.removed;
    if (result.error) {
      // Keep the auth user: the client retries (or falls back to row deletion).
      return new Response(`storage cleanup failed: ${result.error}`, { status: 500 });
    }
  }

  const { error } = await deps.deleteUser(userId);
  if (error) return new Response(error.message, { status: 500 });

  return new Response(JSON.stringify({ deleted: userId, removed }), {
    headers: { "Content-Type": "application/json" },
  });
}

/** Production wiring: service-role client for storage + auth admin, JWT checked via the auth server. */
export function supabaseDeps(): Deps {
  const url = Deno.env.get("SUPABASE_URL")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  return {
    async userIdFromJwt(jwt) {
      const { data: { user }, error } = await admin.auth.getUser(jwt);
      return error || !user ? null : user.id;
    },
    storage: (bucket) => admin.storage.from(bucket),
    deleteUser: (id) => admin.auth.admin.deleteUser(id),
  };
}

if (Deno.env.get("DELETE_ACCOUNT_NO_SERVE") !== "1") {
  Deno.serve((req) => handleDeleteAccount(req, supabaseDeps()));
}
