// deno test --allow-env supabase/functions/delete-account/
//
// handleDeleteAccount / removePrefix against an in-memory Storage fake: paging
// beyond the 1000-object list cap, sub-folders, other riders untouched, and
// every failure (list, remove, no progress, auth delete) → 500 with the auth
// user kept so the app can retry.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { Deps, StorageBucketLike, StorageEntry } from "./index.ts";

// index.ts serves on import unless told otherwise; set the flag first, then
// import dynamically (static imports would run before this line).
Deno.env.set("DELETE_ACCOUNT_NO_SERVE", "1");
const { handleDeleteAccount, removePrefix, PAGE_SIZE } = await import("./index.ts");

const UID = "a0000000-0000-4000-8000-0000000000de";
const OTHER = "b0000000-0000-4000-8000-0000000000de";

/**
 * Storage API fake: objects are full paths per bucket; `list` returns the
 * direct children of a prefix (objects with an id, folders with id null),
 * sorted by name and capped at 1000 like Supabase.
 */
class FakeStorage {
  readonly buckets = new Map<string, Set<string>>();
  readonly listCalls: { bucket: string; prefix: string; limit?: number; offset?: number }[] = [];
  readonly removeCalls: { bucket: string; paths: string[] }[] = [];
  listError: string | null = null;
  removeError: string | null = null;
  /** remove() reports success but deletes nothing. */
  removeIsNoop = false;

  put(bucket: string, ...paths: string[]) {
    const set = this.buckets.get(bucket) ?? new Set<string>();
    for (const p of paths) set.add(p);
    this.buckets.set(bucket, set);
  }

  objects(bucket: string, prefix = ""): string[] {
    return [...(this.buckets.get(bucket) ?? [])].filter((p) => p.startsWith(prefix)).sort();
  }

  bucket = (bucket: string): StorageBucketLike => ({
    list: (prefix, options) => {
      this.listCalls.push({ bucket, prefix, limit: options?.limit, offset: options?.offset });
      if (this.listError) return Promise.resolve({ data: null, error: { message: this.listError } });
      const children = new Map<string, StorageEntry>();
      for (const path of this.objects(bucket, `${prefix}/`)) {
        const rest = path.slice(prefix.length + 1);
        const slash = rest.indexOf("/");
        const name = slash < 0 ? rest : rest.slice(0, slash);
        children.set(name, { name, id: slash < 0 ? `id-${path}` : null });
      }
      const offset = options?.offset ?? 0;
      const limit = Math.min(options?.limit ?? 100, 1000);
      const page = [...children.values()].sort((a, b) => a.name.localeCompare(b.name)).slice(offset, offset + limit);
      return Promise.resolve({ data: page, error: null });
    },
    remove: (paths) => {
      this.removeCalls.push({ bucket, paths });
      if (this.removeError) return Promise.resolve({ data: null, error: { message: this.removeError } });
      if (paths.length > 1000) return Promise.resolve({ data: null, error: { message: "too many paths" } });
      if (!this.removeIsNoop) for (const p of paths) this.buckets.get(bucket)?.delete(p);
      return Promise.resolve({ data: paths.map((name) => ({ name })), error: null });
    },
  });
}

function deps(storage: FakeStorage, opts: { deleteError?: string; validJwt?: string } = {}) {
  const deleted: string[] = [];
  const d: Deps = {
    userIdFromJwt: (jwt) => Promise.resolve(jwt === (opts.validJwt ?? "good-jwt") ? UID : null),
    storage: storage.bucket,
    deleteUser: (id) => {
      if (opts.deleteError) return Promise.resolve({ error: { message: opts.deleteError } });
      deleted.push(id);
      return Promise.resolve({ error: null });
    },
  };
  return { deps: d, deleted };
}

function request(jwt?: string): Request {
  const headers: Record<string, string> = {};
  if (jwt !== undefined) headers.Authorization = `Bearer ${jwt}`;
  return new Request("https://example.invalid/functions/v1/delete-account", { method: "POST", headers });
}

function seed(storage: FakeStorage, tracks: number) {
  storage.put("tracks", ...Array.from({ length: tracks }, (_, i) => `${UID}/day-${String(i).padStart(5, "0")}.json.gz`));
  storage.put("tracks", `${UID}/2025/a.json.gz`, `${UID}/2025/b.json.gz`, `${UID}/2025/deep/c.json.gz`);
  storage.put("avatars", `${UID}/avatar.jpg`);
  storage.put("tracks", `${OTHER}/day-1.json.gz`);
  storage.put("avatars", `${OTHER}/avatar.jpg`);
}

Deno.test("missing or invalid token → 401, nothing touched", async () => {
  const storage = new FakeStorage();
  seed(storage, 3);
  const { deps: d, deleted } = deps(storage);

  assertEquals((await handleDeleteAccount(request(), d)).status, 401);
  assertEquals((await handleDeleteAccount(request(""), d)).status, 401);
  assertEquals((await handleDeleteAccount(request("expired"), d)).status, 401);
  assertEquals(storage.listCalls.length, 0);
  assertEquals(deleted, []);
});

Deno.test("more than 1000 objects are drained page by page, sub-folders included, then the user is deleted", async () => {
  const storage = new FakeStorage();
  seed(storage, 2500);
  const { deps: d, deleted } = deps(storage);

  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body, { deleted: UID, removed: { tracks: 2503, avatars: 1 } });
  assertEquals(deleted, [UID]);

  assertEquals(storage.objects("tracks", `${UID}/`), []);
  assertEquals(storage.objects("avatars", `${UID}/`), []);
  // the other rider keeps everything
  assertEquals(storage.objects("tracks"), [`${OTHER}/day-1.json.gz`]);
  assertEquals(storage.objects("avatars"), [`${OTHER}/avatar.jpg`]);

  // every list asks for a full page from the start; no remove exceeds the cap
  assert(storage.listCalls.every((c) => c.limit === PAGE_SIZE && c.offset === 0));
  const topLevel = storage.listCalls.filter((c) => c.bucket === "tracks" && c.prefix === UID);
  assert(topLevel.length >= 4, `expected ≥ 4 top-level pages for 2501 entries, got ${topLevel.length}`);
  assert(storage.removeCalls.every((c) => c.paths.length <= PAGE_SIZE));
  assert(storage.removeCalls.some((c) => c.paths.includes(`${UID}/2025/deep/c.json.gz`)));
});

Deno.test("an empty account (no objects) is deleted right away", async () => {
  const storage = new FakeStorage();
  const { deps: d, deleted } = deps(storage);
  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 200);
  assertEquals((await res.json()).removed, { tracks: 0, avatars: 0 });
  assertEquals(deleted, [UID]);
});

Deno.test("remove error → 500, auth user kept", async () => {
  const storage = new FakeStorage();
  seed(storage, 1200);
  storage.removeError = "storage unavailable";
  const { deps: d, deleted } = deps(storage);

  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 500);
  assertStringIncludes(await res.text(), "storage unavailable");
  assertEquals(deleted, [], "the auth user must survive a failed cleanup");
  assertEquals(storage.objects("avatars", `${UID}/`).length, 1, "avatars are not reached after the tracks failure");
});

Deno.test("list error → 500, auth user kept", async () => {
  const storage = new FakeStorage();
  seed(storage, 5);
  storage.listError = "list failed";
  const { deps: d, deleted } = deps(storage);

  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 500);
  assertStringIncludes(await res.text(), "list tracks/");
  assertEquals(deleted, []);
});

Deno.test("a remove that silently deletes nothing stops with 'no progress' instead of looping", async () => {
  const storage = new FakeStorage();
  seed(storage, 10);
  storage.removeIsNoop = true;
  const { deps: d, deleted } = deps(storage);

  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 500);
  assertStringIncludes(await res.text(), "no progress");
  assertEquals(deleted, []);
  assert(storage.listCalls.length < 10, `bounded retries, got ${storage.listCalls.length} list calls`);
});

Deno.test("auth delete error → 500 after the storage cleanup", async () => {
  const storage = new FakeStorage();
  seed(storage, 2);
  const { deps: d } = deps(storage, { deleteError: "user not found" });

  const res = await handleDeleteAccount(request("good-jwt"), d);
  assertEquals(res.status, 500);
  assertEquals(await res.text(), "user not found");
  assertEquals(storage.objects("tracks", `${UID}/`), []);
});

Deno.test("removePrefix counts objects of nested folders", async () => {
  const storage = new FakeStorage();
  storage.put("tracks", `${UID}/x/1`, `${UID}/x/y/2`, `${UID}/x/y/z/3`, `${UID}/4`);
  const result = await removePrefix(storage.bucket, "tracks", UID);
  assertEquals(result, { removed: 4 });
  assertEquals(storage.objects("tracks"), []);
});
