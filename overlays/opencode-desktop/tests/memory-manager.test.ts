// Model a multi-session backend with disposable in-memory notes/KV. Frozen
// context, forks, passive diffs and project isolation must survive plugin reload.
import assert from "node:assert/strict";
import test from "node:test";
import { createMemoryManager, snapshotKey } from "../memory/manager.ts";
import { indexLimitError, planChange, sortNotes, type Note, type Scope } from "../../../pi/extensions/memory/store.ts";
import type { Backend, MemoryData } from "../memory/backend.ts";

function fixture() {
  const notes = new Map<string, Note[]>([["pi/global", [{ date: "2026-01-01", text: "Prefer concise answers" }]]]);
  const storage = new Map<string, any>();
  const infos = new Map<string, any>();
  const notices: any[] = [];
  const attempts: string[] = [];
  let failedNotice: string | undefined;
  let reads = 0;
  let failRead = false;
  let delayRead: Promise<void> | undefined;
  const namespace = (directory: string, scope: Scope) => scope === "global" ? "pi/global" : `pi/${directory.slice(1)}`;
  const backend = (directory: string): Backend => ({
    namespace: async (scope) => namespace(directory, scope),
    read: async (selected) => {
      reads++;
      if (delayRead) await delayRead;
      if (failRead) throw new Error("fixture offline");
      const data: MemoryData = {};
      for (const scope of selected) {
        const ns = namespace(directory, scope);
        data[scope] = { namespace: ns, notes: structuredClone(notes.get(ns) ?? []) };
      }
      return { data };
    },
    mutate: async (scope, action, text, previous) => {
      const ns = namespace(directory, scope);
      const before = notes.get(ns) ?? [];
      const change = planChange(before, action, text, previous, "2026-01-02");
      const after = sortNotes([
        ...before.filter((note) => note.text !== change.remove), ...(change.add ? [change.add] : []),
      ]);
      notes.set(ns, after);
      return { data: { [scope]: { namespace: ns, notes: after } }, changed: Boolean(change.add || change.remove), indexError: indexLimitError(after) };
    },
  });
  const ctx: any = {
    storage: {
      get: async (key: string) => structuredClone(storage.get(key)),
      set: async (key: string, value: unknown) => { storage.set(key, structuredClone(value)); },
    },
    session: {
      get: async ({ sessionID }: any) => {
        if (!infos.has(sessionID)) throw new Error("Unknown fixture session");
        return structuredClone(infos.get(sessionID));
      },
      synthetic: async (input: any) => {
        attempts.push(input.sessionID);
        if (!infos.has(input.sessionID)) throw Object.assign(new Error("Deleted fixture session"), { _tag: "Session.NotFoundError" });
        if (input.sessionID === failedNotice) throw new Error("Fixture notification unavailable");
        notices.push(input);
      },
    },
  };
  const session = (id: string, directory = "/project", extra = {}) => {
    infos.set(id, { id, location: { directory }, ...extra });
    return id as any;
  };
  const manager = () => createMemoryManager(ctx, backend);
  return {
    notes, storage, infos, notices, attempts, session, manager,
    failNotice: (id?: string) => { failedNotice = id; },
    reads: () => reads,
    failRead: (value: boolean) => { failRead = value; },
    delayRead: (value: Promise<void>) => { delayRead = value; },
  };
}

test("first context captures once, persists before injection, and stays frozen after writes", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root");
  const before = await m.context(id);
  assert.match(before, /Prefer concise answers/);
  assert.equal(f.storage.size, 1);
  await m.memory({ action: "remember", text: "Prefer targeted tests" }, id);
  assert.equal(await m.context(id), before);
  assert.equal(f.notices.length, 0, "A tool result already acknowledges its own write");
  assert.match(await m.context(f.session("new")), /Prefer targeted tests/);
});

test("resume/compaction/reload reuse persisted snapshots instead of rereading startup notes", async (t) => {
  const f = fixture();
  const id = f.session("root");
  const first = f.manager();
  const before = await first.context(id);
  first.close();
  f.notes.set("pi/global", [{ date: "2026-01-02", text: "Changed elsewhere" }]);
  const reads = f.reads();
  const resumed = f.manager(); t.after(() => resumed.close());
  assert.equal(await resumed.context(id), before);
  assert.equal(f.reads(), reads);
  await resumed.poll();
  assert.equal(f.notices.length, 1);
  assert.equal(f.notices[0].resume, false);
  assert.match(f.notices[0].text, /Changed elsewhere/);
  assert.equal(await resumed.context(id), before);
});

test("concurrent first requests share one capture and one persistent record", async (t) => {
  const f = fixture();
  const gate = Promise.withResolvers<void>();
  f.delayRead(gate.promise);
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root");
  const requests = [m.context(id), m.context(id), m.context(id)];
  gate.resolve();
  const results = await Promise.all(requests);
  assert.equal(new Set(results).size, 1);
  assert.equal(f.reads(), 1);
  assert.equal(f.storage.size, 1);
});

test("external changes notify roots passively once, never rewrite the system prefix", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const a = f.session("a"); const b = f.session("b");
  const initial = await m.context(a); await m.context(b);
  await m.memory({ action: "remember", scope: "global", text: "A durable preference" }, a);
  assert.equal(f.notices.length, 1);
  assert.equal(f.notices[0].sessionID, b);
  assert.equal(f.notices[0].resume, false);
  assert.equal(await m.context(a), initial);
  await m.poll();
  assert.equal(f.notices.length, 1);
  m.close();
  const restored = f.manager(); t.after(() => restored.close());
  await restored.context(b); await restored.poll();
  assert.equal(f.notices.length, 1, "Persisted observation prevents repeated notices after reload");
});

test("forks inherit frozen context; new subagents take fresh snapshots and aren't polled", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const parent = f.session("parent");
  const before = await m.context(parent);
  await m.memory({ action: "remember", scope: "global", text: "New preference" }, parent);
  const fork = f.session("fork", "/project", { fork: { sessionID: parent } });
  assert.equal(await m.context(fork), before);
  const child = f.session("child", "/project", { parentID: parent });
  assert.match(await m.context(child), /New preference/);
  await m.poll();
  assert.equal(f.notices.filter((notice) => notice.sessionID === fork).length, 1);
  assert.equal(f.notices.filter((notice) => notice.sessionID === child).length, 0);
  assert.equal(f.storage.get(snapshotKey("pi/project", parent)).text, f.storage.get(snapshotKey("pi/project", fork)).text);
});

test("global observations cross projects; project notes never do", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const a = f.session("a", "/alpha"); const b = f.session("b", "/beta");
  await m.context(a); await m.context(b);
  await m.memory({ action: "remember", text: "Alpha-only lesson" }, a);
  assert.equal(f.notices.length, 0);
  assert.match(await m.memory({ action: "list" }, a), /Alpha-only lesson/);
  assert.doesNotMatch(await m.memory({ action: "list" }, b), /Alpha-only lesson/);
  await m.memory({ action: "remember", scope: "global", text: "Global preference" }, a);
  assert.equal(f.notices.length, 1);
  assert.equal(f.notices[0].sessionID, b);
});

test("deleted sessions are evicted without blocking live notices or misreporting a saved write", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const deleted = f.session("deleted"); const origin = f.session("origin"); const live = f.session("live");
  await m.context(deleted); await m.context(origin); await m.context(live);
  f.infos.delete(deleted);
  assert.match(await m.memory({ action: "remember", scope: "global", text: "Saved preference" }, origin), /saved/);
  assert.equal(f.notes.get("pi/global")!.length, 2);
  assert.equal(f.notices[0].sessionID, live);
  f.notes.get("pi/global")!.push({ date: "2026-01-03", text: "Another external preference" });
  await m.poll();
  assert.equal(f.attempts.filter((id) => id === deleted).length, 1);
  assert.ok(f.notices.some((notice) => notice.sessionID === live && notice.text.includes("Another external preference")));
});

test("notification failures are retried independently and never turn completed writes into failures", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const unavailable = f.session("unavailable"); const origin = f.session("origin"); const live = f.session("live");
  await m.context(unavailable); await m.context(origin); await m.context(live);
  f.failNotice(unavailable);
  assert.match(await m.memory({ action: "remember", scope: "global", text: "Saved preference" }, origin), /saved/);
  assert.equal(f.notices[0].sessionID, live);
  f.failNotice();
  await m.poll();
  assert.equal(f.notices.length, 2);
  assert.equal(f.notices[1].sessionID, unavailable);
});

test("a write's tool result delivers unseen external differences to its origin before advancing the baseline", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root"); const before = await m.context(id);
  f.notes.set("pi/global", [{ date: "2026-01-02", text: "Prefer detailed explanations" }]);
  const result = await m.memory({ action: "remember", scope: "global", text: "Use focused tests" }, id);
  assert.match(result, /Prefer detailed explanations/);
  assert.match(result, /- 2026-01-01: Prefer concise answers/);
  assert.match(result, /Use focused tests/);
  await m.poll();
  assert.equal(f.notices.length, 0, "The tool result, not a new synthetic input, delivered the differences");
  assert.equal(await m.context(id), before);
});

test("search is case-insensitive AND matching and can select a scope", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root");
  await m.memory({ action: "remember", text: "Use focused integration tests" }, id);
  assert.match(await m.search("FOCUSED tests", undefined, id), /focused integration tests/);
  assert.equal(await m.search("focused unrelated", undefined, id), "No matching notes.");
  assert.equal(await m.search("focused", "global", id), "No matching notes.");
  await assert.rejects(m.search("  ", undefined, id), /at least one search term/);
});

test("over-limit saves are acknowledged as durable and startup loading remains bounded", async (t) => {
  const f = fixture();
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root");
  f.notes.set("pi/global", Array.from({ length: 200 }, (_, i) => ({ date: "2026-01-01", text: `Preference ${i}` })));
  await assert.rejects(m.memory({ action: "remember", scope: "global", text: "LAST_UNIQUE_NOTE" }, id), /Write succeeded.*201\/200/);
  assert.equal(f.notes.get("pi/global")!.length, 201);
  const text = await m.context(f.session("new"));
  assert.match(text, /Only a bounded prefix/);
  assert.match(await m.search("LAST_UNIQUE_NOTE", undefined, id), /LAST_UNIQUE_NOTE/);
});

test("startup failure doesn't block coding or replace its frozen prefix after recovery", async (t) => {
  const f = fixture(); f.failRead(true);
  const m = f.manager(); t.after(() => m.close());
  const id = f.session("root");
  const before = await m.context(id);
  assert.match(before, /unavailable at this session's first request/);
  f.failRead(false);
  assert.equal(await m.context(id), before);
  await m.poll();
  assert.equal(f.notices.length, 1);
  assert.match(f.notices[0].text, /Prefer concise answers/);
  assert.equal(f.notices[0].resume, false);
});

test("cleanup aborts further work without reading the account again", async () => {
  const f = fixture();
  const m = f.manager();
  const id = f.session("root"); await m.context(id);
  m.close();
  const reads = f.reads();
  await assert.rejects(m.context(id), /abort/i);
  await m.poll();
  assert.equal(f.reads(), reads);
});
