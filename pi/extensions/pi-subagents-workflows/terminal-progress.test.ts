import assert from "node:assert/strict";
import test from "node:test";
import { TerminalActivity } from "./terminal-progress";

const activeSequence = "\x1b]9;4;3\x07";
const clearSequence = "\x1b]9;4;0;\x07";

test("signals terminal progress for the workflow lifetime", () => {
	const writes: string[] = [];
	const progress = new TerminalActivity((data) => writes.push(data));

	progress.setActive("workflow", true);
	progress.setActive("workflow", true);
	progress.setActive("workflow", false);

	assert.deepEqual(writes, [activeSequence, clearSequence]);
});

test("keeps progress active until every extension is idle", () => {
	const writes: string[] = [];
	const progress = new TerminalActivity((data) => writes.push(data));

	progress.setActive("workflow", true);
	progress.setActive("background-bash", true);
	progress.setActive("workflow", false);
	progress.setActive("background-bash", false);

	assert.deepEqual(writes, [activeSequence, clearSequence]);
});

test("does not clear progress while Pi is still active", () => {
	const writes: string[] = [];
	const progress = new TerminalActivity((data) => writes.push(data));

	progress.setActive("workflow", true);
	progress.setActive("workflow", false, false);

	assert.deepEqual(writes, [activeSequence]);
});

test("clears deferred progress once Pi becomes idle", () => {
	const writes: string[] = [];
	const progress = new TerminalActivity((data) => writes.push(data));

	progress.setActive("workflow", true);
	progress.setActive("workflow", false, false);
	progress.setActive("workflow", false, true);

	assert.deepEqual(writes, [activeSequence, clearSequence]);
});

test("refresh restores the active signal after Pi settles", () => {
	const writes: string[] = [];
	const progress = new TerminalActivity((data) => writes.push(data));

	progress.setActive("workflow", true);
	progress.refresh();
	progress.setActive("workflow", false);

	assert.deepEqual(writes, [activeSequence, activeSequence, clearSequence]);
});
