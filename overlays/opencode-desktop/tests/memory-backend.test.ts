// Exercise the shared Atuin protocol with synthetic KV data only; tests must
// never open the real agent account, its encryption key, or shell history.
import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { createAtuinBackend } from "../memory/backend.ts";
import { encodeNote, noteKey } from "../../../pi/extensions/memory/store.ts";

async function fixture(t: any, projectNamespace?: string) {
  const cwd = await mkdtemp(join(tmpdir(), "opencode-memory-backend-"));
  await mkdir(join(cwd, ".git"));
  t.after(() => rm(cwd, { recursive: true, force: true }));
  const values = new Map<string, Map<string, string>>();
  const commands: string[] = [];
  let syncs = 0;
  let gitCalls = 0;
  let failDelete = false;
  let failRefresh = false;
  const store = (namespace: string) => {
    if (!values.has(namespace)) values.set(namespace, new Map());
    return values.get(namespace)!;
  };
  const backend = createAtuinBackend(cwd, {
    sync: async () => { syncs++; return undefined; },
    runner: () => async (command, args) => {
      if (command === "git") { gitCalls++; return { code: 0, stdout: "git@github.com:team/project.git\n" }; }
      assert.equal(command, "atuin");
      const operation = args[1];
      commands.push(operation);
      const namespace = args[args.indexOf("-n") + 1];
      const entries = store(namespace);
      const key = args[args.indexOf("-k") + 1];
      if (operation === "list") {
        if (failRefresh && commands.includes("set")) return { code: 1, stdout: "", stderr: "fixture read error" };
        return { code: 0, stdout: [...entries.keys()].join("\n") };
      }
      if (operation === "get") return { code: 0, stdout: entries.get(args.at(-1)!) ?? "" };
      if (operation === "set") { entries.set(key, args.at(-1)!); return { code: 0, stdout: "" }; }
      if (operation === "delete") {
        if (failDelete) return { code: 1, stdout: "", stderr: "fixture deletion error" };
        entries.delete(args.at(-1)!);
        return { code: 0, stdout: "" };
      }
      throw new Error(`Unexpected operation ${operation}`);
    },
  }, projectNamespace);
  return { backend, store, commands, gitCalls: () => gitCalls, syncs: () => syncs, failDelete: () => { failDelete = true; }, failRefresh: () => { failRefresh = true; } };
}

test("uses the same global/project namespaces and note encoding as Pi", async (t) => {
  const f = await fixture(t);
  assert.equal(await f.backend.namespace("global"), "pi/global");
  assert.equal(await f.backend.namespace("project"), "pi/team/project");
  const result = await f.backend.mutate("project", "remember", "Prefer focused changes");
  assert.equal(result.changed, true);
  assert.match(f.store("pi/team/project").get(noteKey("Prefer focused changes"))!, /^\d{4}-\d{2}-\d{2}\tPrefer focused changes$/);
  assert.equal((await f.backend.read(["project"])).data.project!.notes[0].text, "Prefer focused changes");
});

test("the trusted sandbox namespace survives hidden Git metadata without changing global scope", async (t) => {
  const f = await fixture(t, "pi/trusted/repository");
  assert.equal(await f.backend.namespace("project"), "pi/trusted/repository");
  assert.equal(await f.backend.namespace("global"), "pi/global");
  assert.equal(f.gitCalls(), 0);
  await f.backend.mutate("project", "remember", "Project-only fixture");
  assert.equal(f.store("pi/trusted/repository").size, 1);
});

test("remember is idempotent; replace and forget require exact existing text", async (t) => {
  const f = await fixture(t);
  await f.backend.mutate("global", "remember", "Old preference");
  assert.equal((await f.backend.mutate("global", "remember", "Old preference")).changed, false);
  assert.equal(f.commands.filter((x) => x === "set").length, 1);
  await assert.rejects(f.backend.mutate("global", "replace", "New preference", "not present"), /exact note/);
  await f.backend.mutate("global", "replace", "New preference", "Old preference");
  assert.equal(f.store("pi/global").has(noteKey("Old preference")), false);
  await f.backend.mutate("global", "forget", "New preference");
  assert.equal(f.store("pi/global").size, 0);
});

test("over-limit writes remain durable and return an explicit index error", async (t) => {
  const f = await fixture(t);
  for (let i = 0; i < 200; i++) {
    const note = { date: "2026-01-01", text: `Preference ${i}` };
    f.store("pi/global").set(noteKey(note.text), encodeNote(note));
  }
  const result = await f.backend.mutate("global", "remember", "One more preference");
  assert.equal(result.changed, true);
  assert.match(result.indexError!, /201\/200/);
  assert.equal(f.store("pi/global").size, 201);
});

test("a failed replacement reports partial persistence without losing either note", async (t) => {
  const f = await fixture(t);
  await f.backend.mutate("project", "remember", "Old preference");
  f.failDelete();
  const result = await f.backend.mutate("project", "replace", "New preference", "Old preference");
  assert.match(result.error!, /partially succeeded.*List current notes/);
  assert.equal(result.data.project!.notes.length, 2);
  assert.equal(f.store("pi/team/project").size, 2);
});

test("refresh failure does not misreport a successful write as unsaved", async (t) => {
  const f = await fixture(t);
  f.failRefresh();
  const result = await f.backend.mutate("project", "remember", "Durable preference");
  assert.equal(result.error, undefined);
  assert.match(result.warning!, /Memory saved/);
  assert.equal(result.data.project!.notes[0].text, "Durable preference");
  assert.equal(f.store("pi/team/project").size, 1);
});
