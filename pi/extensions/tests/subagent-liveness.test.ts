import assert from "node:assert/strict";
import test from "node:test";
import { EventEmitter } from "node:events";
import spinner from "../titlebar-spinner.ts";
import jjUndo from "../jj-undo.ts";
import { HUMAN_INPUT_EVENT } from "../lib/human-input.ts";
import { createLivenessHost, installSubagentLivenessHost, restoreBlockReason, titleAnimation } from "../lib/subagent-liveness.ts";

const key = Symbol.for("@agegr/pi-web/session-liveness/v1");
const globals = globalThis as Record<symbol, any>;

function harness(mode = "tui") {
	const events = new EventEmitter();
	const handlers = new Map<string, Function>();
	const titles: string[] = [];
	const notices: string[] = [];
	const commands = new Map<string, any>();
	const calls: string[][] = [];
	let idle = true;
	const ctx = {
		mode, hasUI: mode === "tui", cwd: "/tmp", isIdle: () => idle,
		ui: { setTitle: (title: string) => titles.push(title), notify: (text: string) => notices.push(text) },
		sessionManager: {
			getSessionId: () => "parent", getLeafId: () => "leaf", getEntry: () => ({}),
			getBranch: () => [{ type: "custom", customType: "jj-undo", id: "checkpoint", data: {
				version: 1, kind: "checkpoint", checkpointId: "cp", operationId: "old-op", leafId: "leaf",
			} }],
		},
		waitForIdle: async () => {}, navigateTree: async () => ({ cancelled: false }),
	};
	const pi = {
		events: {
			on(name: string, handler: (...args: any[]) => void) {
				events.on(name, handler);
				return () => events.off(name, handler);
			},
			emit: (name: string, payload: any) => events.emit(name, payload),
		},
		on: (name: string, handler: Function) => handlers.set(name, handler),
		getSessionName: () => "test", appendEntry() {},
		registerCommand: (name: string, command: any) => commands.set(name, command),
		exec: async (_program: string, args: string[]) => {
			calls.push(args);
			return { code: 0, stderr: "", stdout: args.includes("log") ? "current-op" : "" };
		},
	};
	return { pi: pi as any, ctx: ctx as any, events, titles, notices, commands, calls,
		setIdle: (value: boolean) => { idle = value; },
		fire: (name: string) => {
			if (name === "agent_start") idle = false;
			if (name === "agent_settled") idle = true;
			return handlers.get(name)?.({}, ctx);
		} };
}

test("host scopes provider ownership, handles errors, and preserves replacement across stale release", () => {
	const host = createLivenessHost();
	assert.equal(host.dotfilesSubagentState("parent"), "unknown");
	const release = host.register({ name: "pi-subagents", sessionId: "parent", isActive: () => true });
	host.register({ name: "pi-subagents", sessionId: "other", isActive: () => true });
	assert.equal(host.dotfilesSubagentState("parent"), "active");
	const replacement = host.register({ name: "pi-subagents", sessionId: "parent", isActive: () => false });
	release();
	assert.equal(host.dotfilesSubagentState("parent"), "idle");
	replacement();
	assert.equal(host.dotfilesSubagentState("parent"), "unknown");
	host.register({ name: "pi-subagents", sessionId: "parent", isActive() { throw Error("unavailable"); } });
	assert.equal(host.dotfilesSubagentState("parent"), "unknown");
});

test("never overwrites a foreign host and fails closed when its state cannot be read", () => {
	const foreign = { version: 1, register() {} };
	globals[key] = foreign;
	assert.equal(installSubagentLivenessHost()("parent"), "unknown");
	assert.equal(globals[key], foreign);
	delete globals[key];
});

test("waiting wins; unknown is not a sticky spinner but blocks restore", () => {
	assert.equal(titleAnimation(true, true, "active"), "waiting");
	assert.equal(titleAnimation(false, false, "active"), "working");
	assert.equal(titleAnimation(false, false, "unknown"), "idle");
	assert.match(restoreBlockReason("unknown")!, /unknown/);
	assert.match(restoreBlockReason("active")!, /stop running/);
	assert.equal(restoreBlockReason("idle"), undefined);
});

test("spinner follows parent-owned queued/nested/background work after settle; cleans reload listeners/timers", (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	delete globals[key];
	const h = harness();
	spinner(h.pi);
	let active = false;
	let release = globals[key].register({ name: "pi-subagents", sessionId: "parent", isActive: () => active });
	h.fire("session_start");
	h.fire("agent_start");
	assert.match(h.titles.at(-1)!, /^⠋ /);
	// Upstream callback includes quiet queued jobs and retained nested descendants.
	active = true;
	h.fire("agent_settled");
	assert.match(h.titles.at(-1)!, /^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] /);
	const id = Symbol();
	h.events.emit(HUMAN_INPUT_EVENT, { id, waiting: true });
	assert.match(h.titles.at(-1)!, /^ /);
	active = false;
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^ /);
	h.events.emit(HUMAN_INPUT_EVENT, { id, waiting: false });
	assert.match(h.titles.at(-1)!, /^π /);
	active = true;
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^⠋ /);
	h.fire("session_shutdown");
	release();
	const count = h.titles.length;
	t.mock.timers.tick(2000);
	h.events.emit(HUMAN_INPUT_EVENT, { id, waiting: true });
	assert.equal(h.titles.length, count);
	assert.equal(h.events.listenerCount(HUMAN_INPUT_EVENT), 0);
	// New extension runtime can reuse the host but not the retired provider.
	const next = harness();
	spinner(next.pi);
	release = globals[key].register({ name: "pi-subagents", sessionId: "parent", isActive: () => true });
	next.fire("session_start");
	assert.match(next.titles.at(-1)!, /^⠋ /);
	next.fire("session_shutdown");
	release();
	delete globals[key];
});

test("late registration and quiet provider changes are picked up without subagent events", (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	delete globals[key];
	const h = harness();
	spinner(h.pi);
	h.fire("session_start");
	const host = globals[key];
	const other = host.register({ name: "pi-subagents", sessionId: "other", isActive: () => true });
	let active = true;
	let release = () => {};
	t.after(() => { h.fire("session_shutdown"); release(); other(); delete globals[key]; });
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^π /, "another parent must not animate this title");
	// The package's session_start can run after the spinner's handler.
	release = host.register({ name: "pi-subagents", sessionId: "parent", isActive: () => active });
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^⠋ /);
	active = false;
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^π /);
	active = true;
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^⠋ /);
	release();
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^π /);
});

test("spinner recovers parent activity without relying on start/settled event pairs", (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	delete globals[key];
	const h = harness();
	spinner(h.pi);
	t.after(() => { h.fire("session_shutdown"); delete globals[key]; });
	// Reload/startup can attach while a request is already being prepared.
	h.setIdle(false);
	h.fire("session_start");
	assert.match(h.titles.at(-1)!, /^⠋ /);
	// A delayed/missed event must not leave the parent spinner stuck on or off.
	h.setIdle(true);
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^π /);
	h.setIdle(false);
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^⠋ /);
	h.fire("agent_start");
	h.setIdle(true);
	t.mock.timers.tick(250);
	assert.match(h.titles.at(-1)!, /^π /);
});

test("repeated session_start replaces subscriptions and timers rather than leaking them", (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	delete globals[key];
	const h = harness();
	spinner(h.pi);
	t.after(() => { h.fire("session_shutdown"); delete globals[key]; });
	h.fire("session_start");
	h.fire("session_start");
	assert.equal(h.events.listenerCount(HUMAN_INPUT_EVENT), 1);
	h.fire("session_shutdown");
	assert.equal(h.events.listenerCount(HUMAN_INPUT_EVENT), 0);
	h.fire("session_start");
	const before = h.titles.length;
	t.mock.timers.tick(250);
	assert.equal(h.titles.length, before + 1, "only one idle activity poll remains");
});

test("print/SDK children install no UI subscriptions, timers, or titles", (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const h = harness("print");
	spinner(h.pi);
	for (const name of ["session_start", "agent_start", "agent_settled", "session_shutdown"]) h.fire(name);
	h.events.emit(HUMAN_INPUT_EVENT, { id: Symbol(), waiting: true });
	t.mock.timers.tick(5000);
	assert.equal(h.events.listenerCount(HUMAN_INPUT_EVENT), 0);
	assert.deepEqual(h.titles, []);
});

test("jj undo refuses missing/error/active provider, allows idle, rechecks after snapshot", async () => {
	for (const state of ["missing", "error", "active", "idle", "starts-during-snapshot"]) {
		globals[key] = createLivenessHost();
		const h = harness();
		if (state !== "missing") globals[key].register({ name: "pi-subagents", sessionId: "parent", isActive() {
			if (state === "error") throw Error("unknown");
			return state === "active" || (state === "starts-during-snapshot" && h.calls.some((args) => args.includes("status")));
		} });
		jjUndo(h.pi);
		await h.commands.get("undo").handler("", h.ctx);
		const restored = h.calls.some((args) => args.includes("restore"));
		assert.equal(restored, state === "idle", state);
		if (state !== "idle") assert.match(h.notices.at(-1)!, /unknown|stop running/);
	}
	delete globals[key];
});
