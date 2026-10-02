import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import test from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import titlebar from "../titlebar-spinner.ts";
import { withHumanInput } from "./human-input.ts";
import { evictSession, setRenderSession, setTasks, TODO_CHANGED_EVENT } from "../todo/state.ts";

function harness(mode = "tui") {
	const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => unknown>();
	const events = new EventEmitter();
	const titles: string[] = [];
	const pi = {
		getSessionName: () => undefined,
		on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => handlers.set(name, handler),
		events: {
			on: (name: string, handler: (event: unknown) => void) => {
				events.on(name, handler);
				return () => events.off(name, handler);
			},
			emit: (name: string, value: unknown) => events.emit(name, value),
		},
	} as unknown as ExtensionAPI;
	const ctx = { mode, ui: { setTitle: (title: string) => titles.push(title) } } as unknown as ExtensionContext;
	titlebar(pi);
	const fire = (name: string) => handlers.get(name)?.({}, ctx);
	fire("session_start");
	return { pi, titles, fire, last: () => titles.at(-1)! };
}

function pending() {
	let resolve!: () => void;
	const promise = new Promise<void>((done) => { resolve = done; });
	return { promise, resolve };
}

test("human input alternates every second, preserves progress, then restores working animation", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const ui = harness();
	setRenderSession("title-test");
	setTasks("title-test", [
		{ subject: "First", status: "completed" },
		{ subject: "Second", status: "pending" },
		{ subject: "Third", status: "in_progress" },
	]);
	ui.fire("agent_start");
	const dialog = pending();
	const waiting = withHumanInput(ui.pi, () => dialog.promise);
	assert.ok(ui.last().startsWith(" π - "));
	assert.ok(ui.last().endsWith(" 3/3"));
	t.mock.timers.tick(999);
	assert.ok(ui.last().startsWith(" "));
	ui.pi.events.emit(TODO_CHANGED_EVENT, undefined);
	t.mock.timers.tick(1);
	assert.ok(ui.last().startsWith(" "));
	t.mock.timers.tick(1000);
	assert.ok(ui.last().startsWith(" "));
	dialog.resolve();
	await waiting;
	assert.ok(ui.last().startsWith("⠋ "));
	ui.fire("agent_settled");
	assert.ok(ui.last().startsWith("π - "));
	ui.fire("session_shutdown");
	evictSession("title-test");
	setRenderSession("");
});

test("overlapping dialogs keep flashing even if the agent settles", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const ui = harness();
	const first = pending();
	const second = pending();
	const a = withHumanInput(ui.pi, () => first.promise);
	const b = withHumanInput(ui.pi, () => second.promise);
	ui.fire("agent_settled");
	first.resolve();
	await a;
	t.mock.timers.tick(1000);
	assert.ok(ui.last().startsWith(" "));
	second.resolve();
	await b;
	assert.ok(ui.last().startsWith("π - "));
	ui.fire("session_shutdown");
});

test("failure and shutdown clear waiting without restarting an old title timer", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const ui = harness();
	await assert.rejects(withHumanInput(ui.pi, async () => { throw new Error("cancelled"); }), /cancelled/);
	assert.ok(ui.last().startsWith("π - "));
	const dialog = pending();
	const waiting = withHumanInput(ui.pi, () => dialog.promise);
	ui.fire("session_shutdown");
	const rendered = ui.titles.length;
	dialog.resolve();
	await waiting;
	t.mock.timers.tick(5000);
	assert.equal(ui.titles.length, rendered);
});

test("headless sessions do not change terminal titles", async (t) => {
	t.mock.timers.enable({ apis: ["setInterval"] });
	const ui = harness("headless");
	ui.fire("agent_start");
	await withHumanInput(ui.pi, async () => {});
	t.mock.timers.tick(5000);
	assert.deepEqual(ui.titles, []);
});
