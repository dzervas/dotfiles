import assert from "node:assert/strict";
import { register } from "node:module";
import test from "node:test";
import { NUDGE_TYPE, planSquash, STATE_TYPE, suggestionThreshold } from "../lib/context-squash.ts";

// Stub Pi's runtime exports and schema construction only. The extension, prompts,
// pressure calculation, squash planner and persisted-state reader run unchanged.
register(`data:text/javascript,${encodeURIComponent(`
export async function resolve(specifier, context, next) {
  const source = specifier === "typebox"
    ? "export const Type = { Object: x => x, Optional: x => x, String: () => ({}) };"
    : specifier === "@earendil-works/pi-coding-agent"
      ? "export const estimateTokens = message => Math.ceil(JSON.stringify(message.content).length / 4); export const compact = () => { throw Error('unexpected summarization'); };"
      : undefined;
  if (source) return { url: "data:text/javascript," + encodeURIComponent(source), shortCircuit: true };
  return next(specifier, context);
}
`)}`, import.meta.url);
const { default: contextSquash } = await import("../context-squash.ts");

function harness(contextWindow = 128_000) {
	const handlers = new Map<string, any>();
	const tools = new Map<string, any>();
	const dialogs: string[] = [];
	const messages: any[] = [];
	const compactions: any[] = [];
	const controller = new AbortController();
	const branch: any[] = ["old", "latest"].map((id) => ({
		id,
		parentId: id === "old" ? null : "old",
		type: "message",
		message: {
			role: "toolResult", toolCallId: id, toolName: "read", isError: false,
			content: [{ type: "text", text: "x".repeat(contextWindow * 3) }],
		},
	}));
	let tokens = suggestionThreshold(contextWindow);
	let pending = false;
	let activeTools = ["read", "codemode"];
	let select: () => Promise<string | undefined> = async () => "Yes";
	const ctx = {
		hasUI: true,
		signal: controller.signal,
		getContextUsage: () => ({ tokens, contextWindow }),
		hasPendingMessages: () => pending,
		sessionManager: { getBranch: () => branch, getLeafId: () => branch.at(-1)?.id },
		ui: {
			select: async (title: string) => { dialogs.push(title); return select(); },
			notify: () => {},
		},
		compact: (options: any) => compactions.push(options),
	};
	contextSquash({
		on: (event: string, handler: any) => handlers.set(event, handler),
		registerTool: (tool: any) => tools.set(tool.name, tool),
		getActiveTools: () => [...activeTools],
		setActiveTools: (names: string[]) => { activeTools = [...names]; },
		sendMessage: (...args: any[]) => messages.push(args),
	} as any);
	const emit = async (type: string, overrides: Record<string, unknown> = {}) => {
		assert.ok(handlers.has(type), `missing ${type} handler`);
		return handlers.get(type)({
			type, entries: [], continue: false, outcome: "completed",
			context: { pendingMessages: [], canContinue: true },
			toolResultEntryIds: ["latest"],
			message: { role: "assistant", content: [], stopReason: "stop" },
			...overrides,
		}, ctx);
	};
	const commit = (result: any) => {
		for (const entry of result?.entries ?? []) {
			branch.push({ ...entry, id: `committed-${branch.length}`, parentId: branch.at(-1)?.id });
		}
	};
	return {
		ctx, branch, dialogs, messages, compactions, controller, tools, emit, commit,
		getActiveTools: () => [...activeTools],
		setActiveTools: (names: string[]) => { activeTools = [...names]; },
		setTokens: (value: number) => { tokens = value; },
		setPending: (value: boolean) => { pending = value; },
		setSelect: (value: () => Promise<string | undefined>) => { select = value; },
	};
}

const edits = (result: any) => (result?.entries ?? []).filter((entry: any) => entry.type === "context_edit");

test("restored sessions and old tree branches drop only compact's direct declaration", async () => {
	const h = harness();
	for (const event of ["session_start", "session_tree"]) {
		h.setActiveTools(["read", "compact", "codemode"]);
		await h.emit(event);
		assert.deepEqual(h.getActiveTools(), ["read", "codemode"]);
		assert.equal(h.tools.get("compact").exposure, "codemode");
	}
});

test("tool turns only nudge; squash waits for final settlement and never requests another provider run", async () => {
	const h = harness();
	const turn = await h.emit("turn_end", { continue: true });
	assert.equal(h.dialogs.length, 0);
	assert.equal(edits(turn).length, 0);
	assert.equal(turn?.continue, undefined);
	assert.equal(turn?.entries?.[0]?.customType, NUDGE_TYPE);
	h.commit(turn);
	assert.equal(await h.emit("turn_end", { continue: true }), undefined);
	assert.equal(h.dialogs.length, 0);

	const settled = await h.emit("agent_before_settle");
	assert.equal(h.dialogs.length, 1);
	assert.deepEqual(edits(settled).map((entry: any) => entry.targetId), ["old"]);
	assert.ok(settled.entries.some((entry: any) => entry.customType === STATE_TYPE && entry.data.squashed === 1));
	assert.notEqual(settled.continue, true);
	h.commit(settled);
	await h.emit("agent_settled");
	assert.deepEqual(h.messages, []);
	assert.deepEqual(h.compactions, []);
});

for (const window of [128_000, 256_000, 870_000, 1_000_000, 1_050_000]) {
	test(`both nudge and dialog honor the exact ${window}-token window threshold`, async () => {
		const h = harness(window);
		h.setTokens(suggestionThreshold(window) - 1);
		assert.equal(await h.emit("turn_end"), undefined);
		assert.equal(await h.emit("agent_before_settle"), undefined);
		assert.equal(h.dialogs.length, 0);
		h.setTokens(suggestionThreshold(window));
		const turn = await h.emit("turn_end");
		assert.equal(turn?.entries?.[0]?.customType, NUDGE_TYPE);
		assert.equal(h.dialogs.length, 0);
		const settled = await h.emit("agent_before_settle");
		assert.equal(h.dialogs.length, 1);
		assert.equal(edits(settled).length, 1);
		assert.notEqual(settled.continue, true);
	});
}

test("No persists a decline; Not yet and dismissal leave no state", async () => {
	const h = harness();
	h.setSelect(async () => "No");
	const declined = await h.emit("agent_before_settle");
	assert.deepEqual(declined?.entries, [{ type: "custom", customType: STATE_TYPE, data: { declined: true } }]);
	assert.notEqual(declined.continue, true);
	h.commit(declined);
	assert.equal(await h.emit("agent_before_settle"), undefined);
	assert.equal(h.dialogs.length, 1);
	for (const choice of ["Not yet", undefined]) {
		const deferred = harness();
		deferred.setSelect(async () => choice);
		assert.equal(await deferred.emit("agent_before_settle"), undefined);
		assert.equal(await deferred.emit("agent_before_settle"), undefined);
		assert.equal(deferred.dialogs.length, 2);
	}
});

test("final dialog requires a completed, unqueued run with UI", async () => {
	for (const outcome of ["aborted", "error"]) {
		const h = harness();
		assert.equal(await h.emit("agent_before_settle", { outcome }), undefined);
		assert.equal(h.dialogs.length, 0);
	}
	for (const guard of ["continue", "pending", "aborted", "headless"]) {
		const h = harness();
		if (guard === "pending") h.setPending(true);
		if (guard === "aborted") h.controller.abort();
		if (guard === "headless") h.ctx.hasUI = false;
		assert.equal(await h.emit("agent_before_settle", { continue: guard === "continue" }), undefined);
		assert.equal(h.dialogs.length, 0);
	}
});

test("a dialog answer is discarded if aborted, queued or moved to a different branch while awaiting it", async () => {
	for (const change of ["abort", "pending", "branch"]) {
		const h = harness();
		let answer!: (choice: string) => void;
		h.setSelect(() => new Promise(resolve => { answer = resolve; }));
		const settling = h.emit("agent_before_settle");
		assert.equal(h.dialogs.length, 1);
		if (change === "abort") h.controller.abort();
		if (change === "pending") h.setPending(true);
		if (change === "branch") h.branch.push({ id: "other-leaf", type: "custom" });
		answer("Yes");
		assert.equal(await settling, undefined);
		assert.deepEqual(h.messages, []);
	}
});

test("squashing is not offered unless projected context is strictly below 50%", async () => {
	const h = harness();
	h.branch[0].message.content = [{ type: "text", text: "x".repeat(128_000 * 1.6) }];
	const estimate = (message: any) => Math.ceil(JSON.stringify(message.content).length / 4);
	const plan = planSquash(h.branch, new Set(["latest"]), estimate);
	assert.equal(plan.edits.length, 1);
	h.setTokens(64_000 + plan.savedTokens);
	await h.emit("turn_end");
	assert.equal(await h.emit("agent_before_settle"), undefined);
	assert.equal(h.dialogs.length, 0);
	h.setTokens(64_000 + plan.savedTokens - 1);
	assert.equal(edits(await h.emit("agent_before_settle")).length, 1);
	assert.equal(h.dialogs.length, 1);
});

test("session lifecycle resets scheduled compaction and unseen-result exclusions", async () => {
	for (const event of ["session_start", "session_shutdown"]) {
		const h = harness();
		await h.emit("turn_end");
		await h.tools.get("compact").execute("call", {}, h.ctx.signal, undefined, h.ctx);
		await h.emit(event);
		await h.emit("agent_settled");
		assert.equal(h.compactions.length, 0);
		assert.deepEqual(edits(await h.emit("agent_before_settle")).map((entry: any) => entry.targetId), ["old", "latest"]);
	}
});

test("codemode compact suppresses the final dialog and still compacts and resumes on agent_settled", async () => {
	const h = harness();
	const tool = h.tools.get("compact");
	assert.equal(tool.exposure, "codemode");
	const result = await tool.execute("call", { note: "  keep decisions  " }, h.ctx.signal, undefined, h.ctx);
	assert.equal(result.terminate, true);
	await h.emit("turn_end");
	assert.equal(await h.emit("agent_before_settle"), undefined);
	assert.equal(h.dialogs.length, 0);
	assert.equal(h.compactions.length, 0);
	await h.emit("agent_settled");
	assert.equal(h.compactions.length, 1);
	assert.equal(h.compactions[0].customInstructions, "keep decisions");
	h.compactions[0].onComplete();
	assert.equal(h.messages.length, 1);
	assert.equal(h.messages[0][1].triggerTurn, true);
	await h.emit("agent_settled");
	assert.equal(h.compactions.length, 1);
});
