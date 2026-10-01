import assert from "node:assert/strict";
import test from "node:test";
import { activeTaskSuffix, applyWrite, evictSession, getTasks, replay, setTasks, validate } from "./state.ts";

test("replays the latest todo result and drops retired task fields", () => {
	const old = { id: "old", subject: "Old task", status: "pending" };
	const current = { id: "new", subject: "Finished task", status: "completed", activeForm: "finishing", confidence: 25, flagged: true, history: [20, 25] };
	const ctx = { sessionManager: { getBranch: () => [
		{ message: { role: "toolResult", toolName: "todo", details: { tasks: [old] } } },
		{ message: { role: "toolResult", toolName: "other", details: { tasks: [] } } },
		{ message: { role: "toolResult", toolName: "todo", details: { tasks: [current] } } },
	] } };
	assert.deepEqual(replay(ctx), [{ subject: "Finished task", status: "completed" }]);
});

test("parent and child lists remain isolated across updates and shutdown", () => {
	setTasks("parent", [{ subject: "Parent", status: "in_progress" }]);
	setTasks("child", [{ subject: "Child", status: "completed" }]);
	evictSession("child");
	assert.equal(getTasks("parent")[0]?.subject, "Parent");
	assert.deepEqual(getTasks("child"), []);
	evictSession("parent");
});


test("title progress is the active position rather than completed count", () => {
	assert.equal(activeTaskSuffix([
		{ subject: "First", status: "completed" },
		{ subject: "Second", status: "pending" },
		{ subject: "Third", status: "in_progress" },
		{ subject: "Fourth", status: "pending" },
		{ subject: "Fifth", status: "pending" },
	]), "3/5");
	assert.equal(activeTaskSuffix([]), "");
	assert.equal(activeTaskSuffix([{ subject: "Finished", status: "completed" }]), "");
});

test("a replacement snapshot sets explicit statuses and permits repeated text", () => {
	const tasks = [
		{ subject: "Check", status: "completed" as const },
		{ subject: "Check", status: "in_progress" as const },
	];
	assert.equal(validate(tasks), undefined);
	assert.deepEqual(applyWrite(tasks), tasks);
	assert.deepEqual(applyWrite([]), []);
	assert.equal(validate([
		{ subject: "A", status: "in_progress" },
		{ subject: "B", status: "in_progress" },
	]), "at most one task can be in progress");
});
