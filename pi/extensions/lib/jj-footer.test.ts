import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test, { type TestContext } from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import jjFooter from "./jj-footer.ts";

const STALE = "This extension ctx is stale after session replacement or reload.";
const flush = () => new Promise<void>((resolve) => setImmediate(resolve));

function harness(t: TestContext) {
	const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "jj-footer-test-"));
	fs.mkdirSync(path.join(cwd, ".jj"));
	t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
	const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void>>();
	const requests: { resolve: (value: { code: number; stdout: string }) => void; reject: (error: Error) => void; signal?: AbortSignal }[] = [];
	const writes: (string | undefined)[] = [];
	let stale = false;
	let staleReads = 0;
	const ctx = {
		hasUI: true,
		cwd,
		signal: undefined,
		get ui() {
			if (stale) {
				staleReads++;
				throw new Error(STALE);
			}
			return { setStatus: (_key: string, text: string | undefined) => writes.push(text), theme: { fg: (_color: string, text: string) => text } };
		},
	} as unknown as ExtensionContext;
	jjFooter({
		on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => Promise<void>) => handlers.set(name, handler),
		exec: (_command: string, _args: string[], options: { signal?: AbortSignal }) => new Promise((resolve, reject) => requests.push({ resolve, reject, signal: options.signal })),
	} as unknown as ExtensionAPI);
	return {
		requests, writes,
		invalidate: () => { stale = true; },
		staleReads: () => staleReads,
		emit: (name: string) => handlers.get(name)!({}, ctx),
	};
}

test("shutdown accepts an already invalidated context", async (t) => {
	const h = harness(t);
	h.invalidate();
	await assert.doesNotReject(h.emit("session_shutdown"));
});

for (const fail of [false, true]) {
	test(`shutdown discards a pending ${fail ? "failed" : "successful"} refresh`, async (t) => {
		const h = harness(t);
		await h.emit("session_start");
		assert.equal(h.requests.length, 2);
		await h.emit("session_shutdown");
		h.invalidate();
		const reads = h.staleReads();
		for (const request of h.requests) {
			if (fail) request.reject(new Error("jj failed"));
			else request.resolve({ code: 0, stdout: "old" });
		}
		await flush();
		assert.equal(h.staleReads(), reads);
		assert.deepEqual(h.writes, [undefined]);
		assert.ok(h.requests.every((request) => request.signal?.aborted));
	});
}

test("a stale refresh without a shutdown event does not reject again in its error handler", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	h.invalidate();
	for (const request of h.requests) request.resolve({ code: 0, stdout: "old" });
	await flush();
	assert.deepEqual(h.writes, []);
});

test("old completion cannot clear a replacement session's in-flight refresh", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	await h.emit("session_shutdown");
	await h.emit("session_start");
	assert.equal(h.requests.length, 4);
	for (const request of h.requests.slice(0, 2)) request.resolve({ code: 0, stdout: "old" });
	await flush();
	await h.emit("tool_execution_end");
	assert.equal(h.requests.length, 4);
	for (const request of h.requests.slice(2)) request.resolve({ code: 0, stdout: "new" });
	await flush();
	assert.equal(h.writes.length, 2);
	assert.ok(h.writes[1]?.includes("new new"));
	assert.ok(!h.writes.some((text) => text?.includes("old")));
});

test("a live subprocess failure still clears the footer", async (t) => {
	const h = harness(t);
	await h.emit("session_start");
	for (const request of h.requests) request.reject(new Error("jj failed"));
	await flush();
	assert.deepEqual(h.writes, [undefined]);
});
