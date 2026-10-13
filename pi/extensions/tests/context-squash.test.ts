import assert from "node:assert/strict";
import test from "node:test";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import {
	compactionBudget,
	formatToolLog,
	NUDGE_TYPE,
	planSquash,
	readState,
	STATE_TYPE,
	stripToolLog,
	stubFor,
} from "../lib/context-squash.ts";

const base = (id: string) => ({ id, parentId: null, timestamp: "2026-10-14T00:00:00.000Z" });
const estimate = (message: unknown) =>
	Math.ceil(JSON.stringify((message as { content: unknown }).content).length / 4);

function call(id: string, name: string, args: unknown): SessionEntry {
	return {
		...base(`a-${id}`),
		type: "message",
		message: { role: "assistant", content: [{ type: "toolCall", id, name, arguments: args }] },
	} as unknown as SessionEntry;
}

function result(id: string, text: string, extra: Record<string, unknown> = {}): SessionEntry {
	return {
		...base(`r-${id}`),
		type: "message",
		message: {
			role: "toolResult",
			toolCallId: id,
			toolName: "read",
			content: [{ type: "text", text }],
			isError: false,
			timestamp: 0,
			...extra,
		},
	} as unknown as SessionEntry;
}

const big = "line\n".repeat(400);

test("squashes outputs but keeps short errors, unseen and already edited results", () => {
	const branch = [
		call("1", "read", { path: "a.ts" }),
		result("1", big),
		call("2", "bash", { command: "false" }),
		result("2", "boom", { isError: true }),
		call("3", "bash", { command: "make" }),
		result("3", "E".repeat(3000), { isError: true }),
		call("4", "read", { path: "b.ts" }),
		result("4", big),
		{ ...base("e"), type: "context_edit", targetId: "r-4", replacement: null } as unknown as SessionEntry,
		call("5", "read", { path: "c.ts" }),
		result("5", big),
		call("6", "read", { path: "tiny" }),
		result("6", "x"),
	];
	const plan = planSquash(branch, new Set(["r-5"]), estimate);
	assert.deepEqual(
		plan.edits.map((edit) => (edit as { targetId: string }).targetId),
		["r-1", "r-3"],
	);
	assert.ok(plan.savedTokens > 0);
	const stub = (plan.edits[0] as { replacement: { content: { text: string }[] } }).replacement.content[0].text;
	assert.equal(stub, "[read output squashed: ok, 400 lines; re-run the tool if you need it]");
});

test("only squashes entries still in context after the latest compaction", () => {
	const branch = [
		call("1", "read", { path: "old.ts" }),
		result("1", big),
		call("2", "read", { path: "kept.ts" }),
		result("2", big),
		{ ...base("c"), type: "compaction", summary: "s", firstKeptEntryId: "a-2", tokensBefore: 1 } as unknown as SessionEntry,
	];
	const plan = planSquash(branch, new Set(), estimate);
	assert.deepEqual(
		plan.edits.map((edit) => (edit as { targetId: string }).targetId),
		["r-2"],
	);
});

test("stubs list nested and legacy codemode calls with truncated args", () => {
	const nested = result("1", "done", {
		toolName: "codemode",
		nestedCalls: { complete: true, calls: [{ id: "x", name: "read", arguments: { path: "p".repeat(100) }, status: "ok" }] },
	});
	const stub = stubFor((nested as unknown as { message: never }).message);
	assert.match(stub, /^\[codemode output squashed: ok, 1 lines/);
	assert.match(stub, /\n {2}- read\(\{"path":"p+…\) → ok$/);
	assert.equal(stub.split("\n")[1].length, "  - read(".length + 81 + ") → ok".length);

	const legacy = result("2", "done", { toolName: "codemode", details: { calls: [{ name: "bash", args: "{}", status: "error" }] } });
	assert.match(stubFor((legacy as unknown as { message: never }).message), /\n {2}- bash\(\{\}\) → error$/);
});

test("state: declined sticks, nudge resets after squash or compaction", () => {
	const nudge = { ...base("n"), type: "custom_message", customType: NUDGE_TYPE, content: "", display: false } as unknown as SessionEntry;
	const squashed = { ...base("s"), type: "custom", customType: STATE_TYPE, data: { squashed: 3 } } as unknown as SessionEntry;
	const declined = { ...base("d"), type: "custom", customType: STATE_TYPE, data: { declined: true } } as unknown as SessionEntry;
	const compaction = { ...base("c"), type: "compaction", summary: "", firstKeptEntryId: "n", tokensBefore: 0 } as unknown as SessionEntry;
	assert.deepEqual(readState([]), { declined: false, nudged: false });
	assert.deepEqual(readState([nudge]), { declined: false, nudged: true });
	assert.deepEqual(readState([nudge, squashed]), { declined: false, nudged: false });
	assert.deepEqual(readState([declined, nudge, compaction]), { declined: true, nudged: false });
});

test("budget is max(min(0.8 × reserve × 2, maxTokens), window / 10)", () => {
	assert.equal(compactionBudget(16384, 128000, 200_000), 26214);
	assert.equal(compactionBudget(16384, 128000, 272_000), 27200);
	assert.equal(compactionBudget(16384, 128000, 1_000_000), 100_000);
	assert.equal(compactionBudget(16384, 8000, 32_000), 8000);
});

test("tool log covers calls before the kept boundary and drops the oldest first", () => {
	const branch = [
		call("1", "read", { path: "first.ts" }),
		result("1", "a\nb\n"),
		call("2", "bash", { command: "x".repeat(200) }),
		result("2", "no", { isError: true }),
		call("3", "read", { path: "kept.ts" }),
		result("3", "kept"),
	];
	const full = formatToolLog(branch, "a-3", 10_000);
	assert.match(full, /^<tool-call-log>\n/);
	assert.match(full, /- read\(\{"path":"first.ts"\}\) → ok, 2 lines/);
	assert.match(full, /- bash\(\{"command":"x+…\) → error, 1 lines/);
	assert.doesNotMatch(full, /kept\.ts/);

	const tight = formatToolLog(branch, "a-3", 70);
	assert.match(tight, /… 1 earlier calls omitted/);
	assert.doesNotMatch(tight, /first\.ts/);
	assert.match(tight, /bash/);

	assert.equal(formatToolLog(branch, "a-3", 10), "");
});

test("stripToolLog removes the previous log before re-summarizing", () => {
	const log = formatToolLog([call("1", "read", { path: "a" }), result("1", "a")], "missing", 10_000);
	assert.equal(stripToolLog(`Summary text\n\n${log}`), "Summary text");
	assert.equal(stripToolLog("no log"), "no log");
});
