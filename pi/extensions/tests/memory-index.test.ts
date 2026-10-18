import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { register } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setImmediate } from "node:timers/promises";
import test, { type TestContext } from "node:test";
import { encodeNote, MAX_BYTES, noteKey, SNAPSHOT_ENTRY } from "../memory/store.ts";

// Pi supplies these schema packages at runtime. Stub only schema construction;
// the actual extension, persistence argv and startup hooks run unchanged.
register(`data:text/javascript,${encodeURIComponent(`
export async function resolve(specifier, context, next) {
  if (specifier.endsWith("/panel.ts") || specifier === "./panel.ts") return {
    url: "data:text/javascript," + encodeURIComponent('export let store; export async function showMemoryPanel(_pi, _ctx, value) { store = value; }'),
    shortCircuit: true
  };
  const schema = specifier === "typebox"
    ? "export const Type = { Object: x => x, Optional: x => x, String: () => ({}) };"
    : specifier === "@earendil-works/pi-ai" ? "export const StringEnum = x => x;" : undefined;
  if (schema) return { url: "data:text/javascript," + encodeURIComponent(schema), shortCircuit: true };
  return next(specifier, context);
}
`)}`, import.meta.url);
const { default: memoryExtension } = await import("../memory/index.ts");

async function fixture(t: TestContext, mode = "headless") {
	const directory = await mkdtemp(join(tmpdir(), "pi-memory-index-"));
	const previous = { config: process.env.ATUIN_CONFIG_DIR, data: process.env.ATUIN_DATA_DIR };
	process.env.ATUIN_CONFIG_DIR = directory;
	process.env.ATUIN_DATA_DIR = directory;
	t.after(async () => {
		handlers.get("session_shutdown")?.({}, ctx);
		if (previous.config === undefined) delete process.env.ATUIN_CONFIG_DIR;
		else process.env.ATUIN_CONFIG_DIR = previous.config;
		if (previous.data === undefined) delete process.env.ATUIN_DATA_DIR;
		else process.env.ATUIN_DATA_DIR = previous.data;
		await rm(directory, { recursive: true, force: true });
	});
	const records = new Map<string, string>();
	const tools = new Map<string, any>();
	const handlers = new Map<string, any>();
	const snapshots: string[] = [];
	const commands = new Map<string, any>();
	const messages: { message: any; options: any }[] = [];
	const calls: string[][] = [];
	let idle = true;
	let branch: any[] = [];
	let failRefresh = false;
	let wrote = false;
	let failDelete = false;
	const ns = "pi/global";
	memoryExtension({
		registerTool: (tool: any) => tools.set(tool.name, tool),
		registerCommand: (name: string, command: any) => commands.set(name, command),
		sendMessage: (message: any, options: any) => messages.push({ message, options }),
		on: (event: string, handler: any) => handlers.set(event, handler),
		appendEntry: (_type: string, data: { text: string }) => snapshots.push(data.text),
		async exec(command: string, args: string[]) {
			calls.push([command, ...args]);
			if (command === "git") return { code: 1, stdout: "" };
			assert.equal(command, "atuin");
			assert.equal(args[0], "kv");
			const [, action, , namespace] = args;
			const prefix = namespace + "\0";
			if (action === "list" && failRefresh && wrote) return { code: 1, stdout: "", stderr: "read unavailable" };
			if (action === "list") return { code: 0, stdout: [...records.keys()].filter(k => k.startsWith(prefix)).map(k => k.slice(prefix.length)).join("\n") };
			if (action === "get") return { code: 0, stdout: records.get(prefix + args[4]) ?? "" };
			if (action === "delete" && failDelete) return { code: 1, stdout: "", stderr: "delete unavailable" };
			if (action === "set") { records.set(prefix + args[5], args[6]); wrote = true; }
			else if (action === "delete") { records.delete(prefix + args[4]); wrote = true; }
			else throw Error(action);
			return { code: 0, stdout: "" };
		},
	} as any);
	const ctx = {
		cwd: directory, mode, isIdle: () => idle,
		sessionManager: { getSessionId: () => "fixture", getBranch: () => branch },
		ui: { notify() {} },
	};
	const invoke = (action: string, text?: string, prior?: string) => tools.get("memory").execute("fixture", { action, text, previous: prior, scope: "global" }, undefined, undefined, ctx);
	return { records, tools, handlers, snapshots, commands, messages, calls, ns, ctx, invoke,
		setIdle: (value: boolean) => { idle = value; },
		setBranch: (value: any[]) => { branch = value; },
		failRefreshAfterWrite: () => { failRefresh = true; wrote = false; },
		failDelete: () => { failDelete = true; },
	};
}

test("overflow writes persist before error, remain searchable, and recover after shortening", async (t) => {
	const { records, tools, handlers, snapshots, ns, ctx, invoke } = await fixture(t);
	for (let i = 0; i < 200; i++) records.set(ns + "\0" + noteKey("note-" + i), encodeNote({ date: "2026-10-18", text: "note-" + i }));
	let reply = await invoke("remember", "overflow");
	assert.equal(reply.isError, true);
	assert.match(reply.content[0].text, /Write succeeded.*Shorten or merge/s);
	assert.ok(records.has(ns + "\0" + noteKey("overflow")));
	assert.equal((await invoke("remember", "overflow")).isError, true);
	assert.equal(records.size, 201);
	assert.match((await invoke("list")).content[0].text, /overflow/);
	const search = await tools.get("memory_search").execute("fixture", { query: "overflow", scope: "global" }, undefined, undefined, ctx);
	assert.match(search.content[0].text, /overflow/);

	await handlers.get("session_start")({}, ctx);
	assert.equal(snapshots.length, 1);
	assert.ok((snapshots[0].match(/^- /gm) ?? []).length <= 200);
	assert.match(snapshots[0], /bounded prefix/);
	const before = handlers.get("before_agent_start")({ systemPrompt: "base" }, ctx).systemPrompt;
	reply = await invoke("forget", "overflow");
	assert.notEqual(reply.isError, true);
	assert.equal(handlers.get("before_agent_start")({ systemPrompt: "base" }, ctx).systemPrompt, before);

	records.clear();
	const giant = "π".repeat(MAX_BYTES);
	reply = await invoke("remember", giant);
	assert.equal(reply.isError, true);
	assert.ok(records.has(ns + "\0" + noteKey(giant)));
	reply = await invoke("replace", "shortened note", giant);
	assert.notEqual(reply.isError, true);
	assert.ok(records.has(ns + "\0" + noteKey("shortened note")));
	assert.ok(!records.has(ns + "\0" + noteKey(giant)));
	const count = records.size;
	assert.equal((await invoke("remember", "bad\ninput")).isError, true);
	assert.equal(records.size, count);
});

test("/mem shares persistence, immediately notifies only the parent, and polling catches external edits", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const h = await fixture(t, "tui");
	h.records.set(h.ns + "\0" + noteKey("original"), encodeNote({ date: "2026-10-18", text: "original" }));
	await h.handlers.get("session_start")({}, h.ctx);
	const prompt = () => h.handlers.get("before_agent_start")({ systemPrompt: "base" }, h.ctx).systemPrompt;
	const originalPrompt = prompt();
	assert.equal(h.messages.length, 0);
	await h.commands.get("mem").handler("", h.ctx);
	const panelPath = "../memory/panel.ts";
	const panel = await import(panelPath);
	const store = panel.store;
	assert.equal((await store.read("global")).notes[0].text, "original");
	await store.mutate("global", "replace", "edited in panel", "original");
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /- 2026-10-18: original/);
	assert.match(h.messages[0].message.content, /\+ .*: edited in panel/);
	assert.equal(h.messages[0].options.triggerTurn, false);
	assert.equal(prompt(), originalPrompt, "live notices must not rewrite the startup system prompt");

	const beforePoll = h.calls.length;
	t.mock.timers.tick(29_999);
	await setImmediate();
	assert.equal(h.calls.length, beforePoll);
	t.mock.timers.tick(1);
	await setImmediate();
	assert.ok(h.calls.length > beforePoll);
	assert.equal(h.messages.length, 1, "polling must not duplicate the immediate panel notification");
	h.records.set(h.ns + "\0" + noteKey("external"), encodeNote({ date: "2026-10-19", text: "external" }));
	t.mock.timers.tick(30_000);
	await setImmediate();
	assert.equal(h.messages.length, 2);
	assert.match(h.messages[1].message.content, /\+ 2026-10-19: external/);

	h.setIdle(false);
	await h.invoke("forget", "external");
	assert.equal(h.messages.length, 3);
	assert.equal(h.messages[2].options.triggerTurn, false);
	assert.equal(prompt(), originalPrompt);
	await h.handlers.get("session_shutdown")({}, h.ctx);
	const afterStop = h.calls.length;
	t.mock.timers.tick(60_000);
	await setImmediate();
	assert.equal(h.calls.length, afterStop);
});

test("partial replacement failure retains both notes and immediately reports the actual persisted diff", async (t) => {
	const h = await fixture(t, "tui");
	h.records.set(h.ns + "\0" + noteKey("original"), encodeNote({ date: "2026-10-18", text: "original" }));
	await h.handlers.get("session_start")({}, h.ctx);
	await h.commands.get("mem").handler("", h.ctx);
	const panelPath = "../memory/panel.ts";
	const panel = await import(panelPath);
	h.failDelete();
	await assert.rejects(panel.store.mutate("global", "replace", "edited", "original"), /delete failed/);
	assert.ok(h.records.has(h.ns + "\0" + noteKey("original")));
	assert.ok(h.records.has(h.ns + "\0" + noteKey("edited")));
	assert.equal((await panel.store.read("global")).notes.length, 2);
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /\+ .*: edited/);
	assert.doesNotMatch(h.messages[0].message.content, /- 2026-10-18: original/);
});

test("a saved panel edit still notifies and reports success when post-write refresh fails", async (t) => {
	const h = await fixture(t, "tui");
	await h.handlers.get("session_start")({}, h.ctx);
	await h.commands.get("mem").handler("", h.ctx);
	const panelPath = "../memory/panel.ts";
	const panel = await import(panelPath);
	h.failRefreshAfterWrite();
	const saved = await panel.store.mutate("global", "remember", "saved on disk");
	assert.ok(h.records.has(h.ns + "\0" + noteKey("saved on disk")));
	assert.equal(saved.notes[0].text, "saved on disk");
	assert.match(saved.warning, /Memory saved, but refreshing/);
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /\+ .*: saved on disk/);
});

test("resumed parent starts monitoring without replacing its recorded snapshot; children do not poll", async (t) => {
	const timers = t.mock.timers;
	timers.enable({ apis: ["setInterval"] });
	for (const mode of ["tui", "print"]) {
		await t.test(mode, async (t) => {
			const h = await fixture(t, mode);
			h.setBranch([{ type: "custom", customType: SNAPSHOT_ENTRY, data: { text: "frozen memories" } }]);
			await h.handlers.get("session_start")({}, h.ctx);
			assert.equal(h.snapshots.length, 0);
			assert.match(h.handlers.get("before_agent_start")({ systemPrompt: "base" }, h.ctx).systemPrompt, /frozen memories/);
			const before = h.calls.length;
			timers.tick(30_000);
			await setImmediate();
			if (mode === "tui") assert.ok(h.calls.length > before);
			else assert.equal(h.calls.length, 0);
		});
	}
});
