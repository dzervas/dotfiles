import assert from "node:assert/strict";
import test from "node:test";
import { WorkflowTerminalProgress } from "./terminal-progress";

const activeSequence = "\x1b]9;4;3\x07";
const clearSequence = "\x1b]9;4;0;\x07";

test("signals terminal progress for the workflow lifetime", () => {
	const writes: string[] = [];
	const progress = new WorkflowTerminalProgress((data) => writes.push(data));

	progress.setActive(true);
	progress.setActive(true);
	progress.setActive(false);

	assert.deepEqual(writes, [activeSequence, clearSequence]);
});

test("does not clear progress while Pi is still active", () => {
	const writes: string[] = [];
	const progress = new WorkflowTerminalProgress((data) => writes.push(data));

	progress.setActive(true);
	progress.setActive(false, false);

	assert.deepEqual(writes, [activeSequence]);
});

test("refresh restores the active signal after Pi settles", () => {
	const writes: string[] = [];
	const progress = new WorkflowTerminalProgress((data) => writes.push(data));

	progress.setActive(true);
	progress.refresh();
	progress.setActive(false);

	assert.deepEqual(writes, [activeSequence, activeSequence, clearSequence]);
});
