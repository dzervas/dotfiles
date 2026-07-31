import assert from "node:assert/strict";
import test from "node:test";
import type { WorkflowRuntime } from "./runtime";
import { WorkflowManager } from "./workflow";

test("wait blocks until the workflow is completely done", async () => {
	let finish!: (value: unknown) => void;
	const runtime: WorkflowRuntime = {
		execute: async () => new Promise((resolve) => {
			finish = resolve;
		}),
	};
	const manager = new WorkflowManager(runtime, {
		invoke: async () => undefined,
	});
	const run = manager.start(
		{ meta: { name: "wait", description: "wait test" }, body: "" },
		{ cwd: "/workflow" },
	);
	const waiting = manager.wait(run.id);
	assert.ok(waiting);

	let settled = false;
	void waiting.then(() => {
		settled = true;
	});
	await new Promise((resolve) => setImmediate(resolve));
	assert.equal(settled, false);

	finish({ ok: true });
	const record = await waiting;
	assert.equal(record.status, "completed");
	assert.deepEqual(record.result, { ok: true });
});

test("wait returns undefined for an unknown workflow", () => {
	const manager = new WorkflowManager(
		{ execute: async () => undefined },
		{ invoke: async () => undefined },
	);
	assert.equal(manager.wait("missing"), undefined);
});
