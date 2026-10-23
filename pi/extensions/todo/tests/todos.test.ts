import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";
import { setImmediate } from "node:timers/promises";
import test from "node:test";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Run with node --experimental-transform-types --test and NODE_PATH pointing
// at Pi's node_modules if jiti is not installed locally. Use the real host
// packages and Pi's TS loader, which also resolves index.ts's .js imports.
const require = createRequire(import.meta.url);
const { createJiti } = require("jiti");
const modules = path.dirname(path.dirname(path.dirname(require.resolve("jiti"))));
const jiti = createJiti(import.meta.url, {
	alias: {
		"@earendil-works/pi-ai": path.join(modules, "@earendil-works/pi-ai/dist/index.js"),
		"@earendil-works/pi-tui": path.join(modules, "@earendil-works/pi-tui/dist/index.js"),
		typebox: path.join(modules, "typebox/build/index.mjs"),
	},
});
const todoExtension = await jiti.import("../index.ts", { default: true });
const { beadsSnapshot } = await jiti.import("../beads.ts");

type Command = Parameters<ExtensionAPI["registerCommand"]>[1];
type Tool = Parameters<ExtensionAPI["registerTool"]>[0];
type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
type Result = { code: number; stdout: string; stderr?: string };
type Call = { command: string; args: string[]; options: { cwd: string; timeout: number } };
const envelope = (data: unknown[]): Result => ({ code: 0, stdout: JSON.stringify({ schema_version: 1, data }) });
const claimed = (title: string, assignee: string) => ({ id: "test-1", title, status: "in_progress", issue_type: "task", assignee });

function deferred<T>() {
	let resolve!: (value: T) => void;
	const promise = new Promise<T>((done) => { resolve = done; });
	return { promise, resolve };
}

function harness(t: test.TestContext, workspace = true) {
	const root = fs.mkdtempSync(path.join(os.tmpdir(), "todo-command-"));
	const cwd = path.join(root, "nested");
	fs.mkdirSync(cwd);
	if (workspace) {
		fs.mkdirSync(path.join(root, ".beads"));
		fs.writeFileSync(path.join(root, ".beads/metadata.json"), "{}");
	}
	// Isolate both trackers from the user's home, workspace overrides and keys.
	const environment = process.env;
	const home = environment.HOME;
	environment.HOME = root;
	process.env = {};
	const actor = `pi:${root}`;
	const commands = new Map<string, Command>();
	const tools = new Map<string, Tool>();
	const handlers = new Map<string, Handler[]>();
	const notices: { text: string; level: string }[] = [];
	const calls: Call[] = [];
	let human = "  ○ test-2  Raw human list\n    nested detail\n";
	let humanFailure: Result | Error | undefined;
	let active = claimed("Initial claim", actor);
	let query = async (): Promise<Result> => envelope([active]);
	const ctx = {
		cwd,
		mode: "tui",
		sessionManager: { getSessionId: () => root, getBranch: () => [] },
		ui: {
			notify: (text: string, level: string) => notices.push({ text, level }),
			setWidget: () => {},
		},
	} as unknown as ExtensionCommandContext;
	const pi = {
		registerCommand: (name: string, command: Command) => commands.set(name, command),
		registerTool: (tool: Tool) => tools.set(tool.name, tool),
		on: (name: string, handler: Handler) => {
			const list = handlers.get(name) ?? [];
			list.push(handler);
			handlers.set(name, list);
		},
		appendEntry: () => {},
		events: { emit: () => {} },
		exec: async (command: string, args: string[], options: Call["options"]) => {
			calls.push({ command, args, options });
			if (command === "git") return { code: 128, stdout: "" };
			if (command === "op") {
				assert.deepEqual(args, ["read", "op://Private/AnyType Local Key/api"]);
				return { code: 0, stdout: "dummy-key" };
			}
			assert.equal(command, "env");
			assert.deepEqual(args.slice(0, 2), ["BD_JSON_ENVELOPE=1", "bd"]);
			assert.deepEqual(options, { cwd, timeout: 5000 });
			if (args.includes("--json")) return query();
			assert.deepEqual(args, ["BD_JSON_ENVELOPE=1", "bd", "list", "--assignee", actor]);
			if (humanFailure instanceof Error) throw humanFailure;
			return humanFailure ?? { code: 0, stdout: human };
		},
	} as unknown as ExtensionAPI;
	todoExtension(pi);
	const emit = async (name: string) => {
		for (const handler of handlers.get(name) ?? []) await handler({}, ctx);
	};
	t.after(async () => {
		await emit("session_shutdown");
		fs.rmSync(root, { recursive: true, force: true });
		process.env = environment;
		if (home === undefined) delete process.env.HOME;
		else process.env.HOME = home;
	});
	return {
		calls, notices, cwd, actor,
		configureAnytype() {
			fs.mkdirSync(path.join(root, ".pi", "agent"), { recursive: true });
			fs.writeFileSync(path.join(root, ".pi", "agent", "anytype.json"), JSON.stringify({
				space: "space.full", type: "issue", properties: {
					kind: "kind", state: "status", tags: "tag", parent: "parent", blockers: "blockers", assignee: "worker",
				},
			}));
		},
		get human() { return human; },
		set human(value: string) { human = value; },
		set humanFailure(value: Result | Error) { humanFailure = value; },
		set query(value: () => Promise<Result>) { query = value; },
		async start() { await emit("session_start"); await setImmediate(); },
		async todos() { await commands.get("todos")!.handler("", ctx); },
		async write(tasks: { subject: string; status: "pending" | "completed" }[]) {
			await tools.get("todo")!.execute("write", { tasks }, undefined, undefined, ctx);
		},
	};
}

const humanCalls = (calls: Call[]) => calls.filter(({ command, args }) => command === "env" && !args.includes("--json"));

test("/todos awaits a forced fresh refresh before running human bd list", async (t) => {
	const h = harness(t);
	await h.start();
	assert.equal(process.env.BEADS_ACTOR, h.actor);
	assert.equal(beadsSnapshot()?.claimed.title, "Initial claim");
	const initialQueries = h.calls.length;
	const refresh = deferred<Result>();
	h.query = () => refresh.promise;
	let settled = false;
	const command = h.todos().then(() => { settled = true; });
	// Give a non-refreshing implementation a chance to complete, rather than
	// hanging the test forever while waiting for a query it never starts.
	await setImmediate();
	try {
		assert.equal(h.calls.length, initialQueries + 1, "the command must force a new JSON query");
		assert.equal(settled, false);
		assert.equal(humanCalls(h.calls).length, 0, "human list must wait for refresh");
		assert.deepEqual(h.notices, []);
	} finally {
		refresh.resolve(envelope([claimed("Fresh claim", h.actor)]));
		await command;
	}
	assert.equal(beadsSnapshot()?.claimed.title, "Fresh claim", "refresh must parse the envelope data");
	assert.equal(humanCalls(h.calls).length, 1);
	assert.ok(h.notices.at(-1)?.text.includes(h.human.trimEnd()));
	assert.ok(h.notices.at(-1)?.text.includes(`Beads owned by ${h.actor}`));
});

test("/todos shows raw human stdout alongside populated session todos", async (t) => {
	const h = harness(t);
	await h.start();
	await h.write([
		{ subject: "Completed session step", status: "completed" },
		{ subject: "Pending session step", status: "pending" },
	]);
	await h.todos();
	assert.equal(humanCalls(h.calls).length, 1);
	const notice = h.notices.at(-1)!;
	assert.equal(notice.level, "info");
	assert.ok(notice.text.includes(h.human.trimEnd()), "keep human indentation and detail, not a snapshot projection");
	assert.match(notice.text, /1\/2 completed/);
	assert.match(notice.text, /Completed session step/);
	assert.match(notice.text, /Pending session step/);
});

test("/todos still lists beads with zero todos and fetches human output on every invocation", async (t) => {
	const h = harness(t);
	await h.start();
	await h.todos();
	assert.ok(h.notices.at(-1)?.text.includes(h.human.trimEnd()));
	assert.match(h.notices.at(-1)!.text, /No todos yet\./);
	h.human = "  ⊘ test-3  Newly blocked work\n    waits on test-4\n";
	await h.todos();
	assert.equal(humanCalls(h.calls).length, 2);
	assert.ok(h.notices.at(-1)?.text.includes(h.human.trimEnd()));
	assert.doesNotMatch(h.notices.at(-1)!.text, /Raw human list/);
});

test("/todos outside a beads workspace preserves empty and populated session lists without executing bd", async (t) => {
	const h = harness(t, false);
	await h.start();
	await h.todos();
	assert.deepEqual(h.notices, [{ text: "No todos yet.", level: "info" }]);
	await h.write([{ subject: "Local session step", status: "pending" }]);
	await h.todos();
	assert.match(h.notices.at(-1)!.text, /0\/1 completed/);
	assert.match(h.notices.at(-1)!.text, /Local session step/);
	assert.deepEqual(h.calls, []);
});

test("/todos includes current Anytype issues, their context and document links alongside todos and Beads", async (t) => {
	const h = harness(t);
	h.configureAnytype();
	await h.start();
	await h.write([{ subject: "Local step", status: "pending" }]);
	const requests: { path: string; body: any }[] = [];
	const object = (id: string, title: string, fields: Record<string, unknown> = {}) => ({
		id, type: "issue", etag: "r1", properties: {
			name: title, kind: ["task"], status: ["open"], worker: "", tag: [], parent: [], blockers: [], project: ["project-one"], ...fields,
		},
	});
	const current = object("active", "Current issue", { status: ["in_progress"], worker: h.actor, parent: ["epic"] });
	t.mock.method(globalThis, "fetch", async (url: string, init: RequestInit) => {
		assert.equal(new Headers(init.headers).get("Authorization"), "Bearer dummy-key");
		const path = new URL(String(url)).pathname;
		const body = init.body ? JSON.parse(String(init.body)) : undefined;
		requests.push({ path, body });
		const data = body?.type === "project" ? { data: [{ id: "project-one", name: "repo", properties: { description: h.cwd } }] }
			: path.endsWith("/objects/epic") ? object("epic", "Parent epic", { kind: ["epic"] })
			: { data: body.filters.some((filter: any) => filter.property === "worker") ? [current]
				: [current, object("sibling", "Related issue", { parent: ["epic"], status: ["closed"] })], has_more: false };
		return new Response(JSON.stringify(data));
	});
	await h.todos();
	const notice = h.notices.at(-1)!;
	assert.equal(notice.level, "info");
	assert.match(notice.text, /Local step/);
	assert.ok(notice.text.includes(h.human.trimEnd()));
	assert.match(notice.text, /Current issue \(claimed\)/);
	assert.match(notice.text, /Parent epic \(epic\)/);
	assert.match(notice.text, /Related issue \(sibling\)/);
	assert.match(notice.text, /anytype:\/\/object\?objectId=active&spaceId=space.full/);
	assert.equal(h.calls.filter((call) => call.command === "op").length, 1);
	assert.equal(requests.length, 4);
});

test("/todos reports Anytype failures without losing local todos", async (t) => {
	const h = harness(t, false);
	h.configureAnytype();
	await h.start();
	await h.write([{ subject: "Keep my steps", status: "pending" }]);
	t.mock.method(globalThis, "fetch", async () => { throw new Error("offline"); });
	await h.todos();
	assert.equal(h.notices[0].level, "error");
	assert.match(h.notices[0].text, /Anytype issues failed/);
	assert.match(h.notices.at(-1)!.text, /Keep my steps/);
});

for (const failure of [
	{ code: 1, stdout: "", stderr: "database unavailable" },
	new Error("database unavailable"),
]) {
	test(`/todos reports ${failure instanceof Error ? "thrown" : "nonzero-exit"} bd errors and still shows session todos`, async (t) => {
		const h = harness(t);
		await h.start();
		await h.write([{ subject: "Keep my session steps", status: "pending" }]);
		h.humanFailure = failure;
		await h.todos();
		assert.equal(humanCalls(h.calls).length, 1);
		assert.equal(h.notices.length, 2);
		assert.equal(h.notices[0].level, "error");
		assert.match(h.notices[0].text, /bd list failed:.*database unavailable/);
		assert.equal(h.notices[1].level, "info");
		assert.match(h.notices[1].text, /0\/1 completed/);
		assert.match(h.notices[1].text, /Keep my session steps/);
	});
}
