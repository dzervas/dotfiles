import assert from "node:assert/strict";
import test from "node:test";
import { createMemoryMonitor, type MemoryData } from "../memory/monitor.ts";
import { diffNotes, type Note, type Scope } from "../memory/store.ts";

const note = (text: string, date = "2026-10-18"): Note => ({ date, text });
const data = (notes: Note[], scope: Scope = "project"): MemoryData => new Map([[scope, { namespace: `pi/${scope}`, notes }]]);
const flush = async () => { for (let i = 0; i < 5; i++) await Promise.resolve(); };
function deferred<T>() {
	let resolve!: (value: T) => void;
	const promise = new Promise<T>((done) => { resolve = done; });
	return { promise, resolve };
}
function harness(read: (ctx: any, signal: AbortSignal) => Promise<MemoryData> = async () => data([])) {
	const messages: { message: any; options: any }[] = [];
	const warnings: string[] = [];
	let idle = true;
	const ctx = (id = "parent", mode = "tui") => ({
		mode, sessionManager: { getSessionId: () => id }, isIdle: () => idle,
		ui: { notify: (text: string) => warnings.push(text) },
	}) as any;
	const monitor = createMemoryMonitor({ sendMessage: (message, options) => { messages.push({ message, options }); } }, read);
	return { monitor, messages, warnings, ctx, busy: () => { idle = false; } };
}

test("note diff is stable, duplicate-free, and includes date-only edits", () => {
	const old = note("old");
	assert.equal(diffNotes([old, old, note("same")], [note("new"), note("same"), note("new")]),
		"- 2026-10-18: old\n+ 2026-10-18: new");
	assert.equal(diffNotes([note("same")], [note("same", "2026-10-19")]),
		"- 2026-10-18: same\n+ 2026-10-19: same");
	assert.equal(diffNotes([note("z"), note("a")], [note("a"), note("z")]), "");
});

test("polls at exactly 30 seconds, observes additions once, idle does not trigger a turn", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	let calls = 0;
	const h = harness(async () => { calls++; return data([note("added")]); });
	t.after(() => h.monitor.stop());
	h.monitor.start(h.ctx(), data([]));
	assert.equal(h.messages.length, 0);
	t.mock.timers.tick(29_999);
	await flush();
	assert.equal(calls, 0);
	t.mock.timers.tick(1);
	await flush();
	assert.equal(calls, 1);
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /\+ 2026-10-18: added/);
	assert.equal(h.messages[0].message.customType, "memory-changed");
	assert.equal(h.messages[0].message.display, true);
	assert.deepEqual(h.messages[0].options, { triggerTurn: false });
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(calls, 2);
	assert.equal(h.messages.length, 1);
});

test("failed startup and failed poll seed first successful read without added spam", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	let calls = 0;
	const h = harness(async () => { if (++calls === 1) throw Error("private detail"); return data([note("existing")]); });
	t.after(() => h.monitor.stop());
	h.monitor.start(h.ctx());
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(h.warnings.length, 1);
	assert.doesNotMatch(h.warnings[0], /private detail/);
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(h.messages.length, 0);
	h.monitor.observe("parent", data([note("existing"), note("new")]));
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /\+ 2026-10-18: new/);
});

test("immediate add/edit/forget and scope subsets never start another parent turn, even while busy", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const initial = new Map([...data([note("global")], "global"), ...data([])]);
	const h = harness(async () => initial);
	t.after(() => h.monitor.stop());
	h.monitor.start(h.ctx(), initial);
	h.busy();
	h.monitor.observe("parent", data([note("old")]));
	h.monitor.observe("parent", data([note("new")]));
	h.monitor.observe("parent", data([]));
	assert.equal(h.messages.length, 3);
	assert.match(h.messages[0].message.content, /\+ 2026-10-18: old/);
	assert.match(h.messages[1].message.content, /- 2026-10-18: old/);
	assert.match(h.messages[1].message.content, /\+ 2026-10-18: new/);
	assert.match(h.messages[2].message.content, /- 2026-10-18: new/);
	assert.deepEqual(h.messages[0].options, { triggerTurn: false });
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(h.messages.length, 3, "untouched global baseline and final project state remain current");
});

test("headless children never poll or notify and foreign observations are ignored", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	let calls = 0;
	const h = harness(async () => { calls++; return data([note("new")]); });
	t.after(() => h.monitor.stop());
	for (const mode of ["print", "json", "rpc"]) {
		h.monitor.start(h.ctx("child", mode), data([]));
		h.monitor.observe("child", data([note("new")]));
		t.mock.timers.tick(30_000);
		await flush();
	}
	assert.equal(calls, 0);
	assert.equal(h.messages.length, 0);
	h.monitor.start(h.ctx(), data([]));
	h.monitor.observe("child", data([note("foreign")]));
	assert.equal(h.messages.length, 0);
});

test("slow polls do not overlap; an immediate write supersedes stale pending read", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const pending = deferred<MemoryData>();
	let calls = 0;
	const h = harness(async () => { calls++; return calls === 1 ? pending.promise : data([note("written")]); });
	t.after(() => h.monitor.stop());
	h.monitor.start(h.ctx(), data([]));
	t.mock.timers.tick(90_000);
	assert.equal(calls, 1);
	h.monitor.observe("parent", data([note("written")]));
	pending.resolve(data([]));
	await flush();
	assert.equal(h.messages.length, 1);
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(calls, 2);
	assert.equal(h.messages.length, 1);
});

test("stop/restart aborts reads, removes timers, and suppresses old-context results", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const old = deferred<MemoryData>();
	const signals: AbortSignal[] = [];
	const h = harness(async (_ctx, signal) => { signals.push(signal); return signals.length === 1 ? old.promise : data([note("fresh")]); });
	t.after(() => h.monitor.stop());
	h.monitor.start(h.ctx(), data([]));
	t.mock.timers.tick(30_000);
	h.monitor.start(h.ctx("replacement"), data([]));
	assert.equal(signals[0].aborted, true);
	h.monitor.observe("parent", data([note("wrong owner")]));
	old.resolve(data([note("stale")]));
	await flush();
	assert.equal(h.messages.length, 0);
	t.mock.timers.tick(30_000);
	await flush();
	assert.equal(h.messages.length, 1);
	assert.match(h.messages[0].message.content, /\+ 2026-10-18: fresh/);
	h.monitor.stop();
	h.monitor.stop();
	t.mock.timers.tick(90_000);
	await flush();
	assert.equal(signals.length, 2);
	h.monitor.observe("replacement", data([]));
	assert.equal(h.messages.length, 1);
});

test("stopping an unresolved read aborts and discards its late result", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const pending = deferred<MemoryData>();
	let signal!: AbortSignal;
	const h = harness(async (_ctx, current) => { signal = current; return pending.promise; });
	h.monitor.start(h.ctx(), data([]));
	t.mock.timers.tick(30_000);
	h.monitor.stop();
	assert.equal(signal.aborted, true);
	pending.resolve(data([note("late")]));
	await flush();
	assert.equal(h.messages.length, 0);
});
