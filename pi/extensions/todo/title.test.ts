import assert from "node:assert/strict";
import test from "node:test";
import { getBaseTitle } from "../titlebar-spinner.ts";
import { evictSession, setRenderSession, setTasks } from "./state.ts";

test("title suffix follows the foreground plan and ignores child plans", () => {
	const pi = { getSessionName: () => undefined };
	setRenderSession("parent");
	setTasks("parent", [
		{ subject: "First", status: "completed" },
		{ subject: "Second", status: "in_progress" },
		{ subject: "Third", status: "pending" },
	]);
	setTasks("child", [{ subject: "Child", status: "in_progress" }]);
	assert.ok(getBaseTitle(pi).endsWith(" 2/3"));
	setTasks("parent", []);
	assert.ok(!/ \d+\/\d+$/.test(getBaseTitle(pi)));
	evictSession("parent");
	evictSession("child");
	setRenderSession("");
});
