import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import test from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import notify from "../notify.ts";
import { withHumanInput } from "./human-input.ts";

function harness(mode = "tui") {
	const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => unknown>();
	const events = new EventEmitter();
	const pi = {
		on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => handlers.set(name, handler),
		events: {
			on: (name: string, handler: (event: unknown) => void) => events.on(name, handler),
			emit: (name: string, value: unknown) => events.emit(name, value),
		},
	} as unknown as ExtensionAPI;
	const ctx = { mode } as ExtensionContext;
	notify(pi);
	const fire = (name: string) => handlers.get(name)?.({}, ctx);
	fire("session_start");
	return { pi, fire };
}

async function capture(run: () => Promise<void>, kitty = false): Promise<string[]> {
	const writes: string[] = [];
	const originalWrite = process.stdout.write;
	const wt = process.env.WT_SESSION;
	const kittyId = process.env.KITTY_WINDOW_ID;
	delete process.env.WT_SESSION;
	if (kitty) process.env.KITTY_WINDOW_ID = "1";
	else delete process.env.KITTY_WINDOW_ID;
	process.stdout.write = ((data: string) => { writes.push(data); return true; }) as typeof process.stdout.write;
	try {
		await run();
	} finally {
		process.stdout.write = originalWrite;
		if (wt === undefined) delete process.env.WT_SESSION;
		else process.env.WT_SESSION = wt;
		if (kittyId === undefined) delete process.env.KITTY_WINDOW_ID;
		else process.env.KITTY_WINDOW_ID = kittyId;
	}
	return writes;
}

const notification = (body: string) => ["\x07", `\x1b]777;notify;Pi;${body}\x07`];

test("human-input dialogs notify and ring once on opening, not closing", async () => {
	const writes = await capture(async () => {
		const ui = harness();
		await withHumanInput(ui.pi, async () => {});
	});
	assert.deepEqual(writes, notification("Input required"));
});

test("each overlapping dialog notifies, including one that fails", async () => {
	const writes = await capture(async () => {
		const ui = harness();
		await withHumanInput(ui.pi, async () => {
			await assert.rejects(withHumanInput(ui.pi, async () => { throw new Error("cancelled"); }), /cancelled/);
		});
	});
	assert.deepEqual(writes, [...notification("Input required"), ...notification("Input required")]);
});

test("completion notifies and rings only when the agent settles", async () => {
	const writes = await capture(async () => {
		const ui = harness();
		await ui.fire("turn_end");
		await ui.fire("agent_end");
		await ui.fire("agent_settled");
	});
	assert.deepEqual(writes, notification("Ready for input"));
});

test("headless modes and shutdown do not emit terminal notifications", async () => {
	const writes = await capture(async () => {
		for (const mode of ["headless", "rpc", "json", "print"]) {
			const ui = harness(mode);
			await withHumanInput(ui.pi, async () => {});
			await ui.fire("agent_settled");
		}
		const ui = harness();
		await ui.fire("session_shutdown");
		await withHumanInput(ui.pi, async () => {});
	});
	assert.deepEqual(writes, []);
});

test("Kitty notifications retain OSC 99 and also ring the bell", async () => {
	const writes = await capture(async () => {
		await harness().fire("agent_settled");
	}, true);
	assert.deepEqual(writes, [
		"\x07",
		"\x1b]99;i=1:d=0;Pi\x1b\\",
		"\x1b]99;i=1:p=body;Ready for input\x1b\\",
	]);
});
