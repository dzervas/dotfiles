// Check the public v2 plugin seam and native permission assertions without
// touching a real account; integration tests cover the released host loader.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";
import test from "node:test";

const source = stripTypeScriptTypes(await readFile(new URL("../memory/index.ts", import.meta.url), "utf8"));

async function fixture(denyEdits = false) {
  const tools = new Map<string, any>();
  const hooks = new Map<string, any>();
  const permissions: any[] = [];
  let writes = 0;
  let searches = 0;
  let closed = 0;
  let cleared = 0;
  const schema = { annotate() { return this; } };
  const dependencies: Record<string, any> = {
    "@opencode/plugin": { Plugin: { define: (value: unknown) => value } },
    "effect": { Schema: { Literals: () => schema, Struct: () => schema, optional: () => schema, String: schema } },
    "../../../pi/extensions/lib/prompts.ts": { getPrompt: (_extension: string, marker: string) => marker },
    "./backend.ts": { createAtuinBackend() {} },
    "./manager.ts": { createMemoryManager: () => ({
      memory: async () => { writes++; return "Memory saved"; },
      search: async () => { searches++; return "Found memory"; },
      context: async () => "Frozen learned memory",
      poll: async () => {},
      close: () => closed++,
    }) },
  };
  const context = createContext({
    setInterval: () => ({ unref() {} }),
    clearInterval: () => { cleared++; },
  });
  const module = new SourceTextModule(source, { context });
  await module.link((name: string) => {
    const values = dependencies[name];
    assert.ok(values, `Unexpected import ${name}`);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate();
  const cleanup = await module.namespace.default.setup({
    location: { directory: "/fixture" },
    tool: { transform: async (callback: any) => callback({ add: (value: any) => tools.set(value.name, value) }) },
    session: { hook: async (name: string, callback: any) => hooks.set(name, callback) },
    permission: { assert: async (input: any) => {
      permissions.push(input);
      if (denyEdits && input.action === "edit") throw new Error("Fixture read-only policy");
    } },
  });
  return { tools, hooks, permissions, cleanup, writes: () => writes, searches: () => searches, closed: () => closed, cleared: () => cleared };
}
const call = { sessionID: "session", agent: "plan", messageID: "message", id: "call", signal: new AbortController().signal };

test("registers both Code Mode tools and a native context hook", async () => {
  const f = await fixture();
  try {
    assert.deepEqual([...f.tools.keys()], ["memory", "memory_search"]);
    assert.equal(f.tools.get("memory").options.codemode, true);
    assert.equal(f.tools.get("memory").options.pinned, true);
    const event = { sessionID: "session", system: [] as unknown[] };
    await f.hooks.get("context")(event);
    assert.equal((event.system[0] as any).text, "Frozen learned memory");
  } finally { f.cleanup(); }
  assert.equal(f.closed(), 1);
  assert.equal(f.cleared(), 1);
});

test("memory mutations honor native read-only/Plan edit policy before the backend runs", async () => {
  const f = await fixture(true);
  try {
    await assert.rejects(f.tools.get("memory").execute({ action: "remember", text: "Preference" }, call), /read-only policy/);
    assert.equal(f.writes(), 0);
    assert.equal(f.permissions[0].action, "edit");
    assert.equal(f.permissions[0].resources.join(","), "memory:project");
    assert.equal(f.permissions[0].source.messageID, "message");
    await f.tools.get("memory_search").execute({ query: "preference" }, call);
    assert.equal(f.permissions[1].action, "read");
    assert.equal(f.searches(), 1);
  } finally { f.cleanup(); }
});

test("listing memory is a read; global writes retain their explicit scope", async () => {
  const f = await fixture();
  try {
    await f.tools.get("memory").execute({ action: "list", scope: "global" }, call);
    await f.tools.get("memory").execute({ action: "forget", scope: "global", text: "Preference" }, call);
    assert.equal(f.permissions[0].action, "read");
    assert.equal(f.permissions[1].action, "edit");
    assert.equal(f.permissions[1].resources.join(","), "memory:global");
  } finally { f.cleanup(); }
});
