import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
	createBashToolDefinition,
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	type ExtensionAPI,
	type ExtensionContext,
	type ExtensionToolContext,
} from "@earendil-works/pi-coding-agent";
import backgroundBash from "../background-bash.ts";

type Tool = ReturnType<typeof createBashToolDefinition>;

async function harness(t: test.TestContext) {
	const cwd = await mkdtemp(join(tmpdir(), "pi-background-test-"));
	const tools = new Map<string, Tool>();
	const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => unknown>();
	let notify!: (message: { content: string }) => void;
	const completion = new Promise<{ content: string }>((resolve) => { notify = resolve; });
	const pi = {
		registerTool: (tool: Tool) => tools.set(tool.name, tool),
		registerCommand: () => {},
		on: (name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => handlers.set(name, handler),
		sendMessage: notify,
	} as unknown as ExtensionAPI;
	const ctx = {
		cwd,
		mode: "headless",
		hasUI: false,
		isProjectTrusted: () => false,
		isIdle: () => true,
		sessionManager: { getSessionId: () => cwd, getSessionFile: () => undefined },
		ui: { setWidget: () => {} },
	} as unknown as ExtensionToolContext;
	backgroundBash(pi);
	handlers.get("session_start")?.({}, ctx);
	const files = new Set<string>();
	const track = (text: string) => {
		for (const match of text.matchAll(/Full output: ([^\]\n]+)/g)) files.add(match[1]);
		return text;
	};
	t.after(async () => {
		handlers.get("session_shutdown")?.({ reason: "exit" }, ctx);
		await rm(cwd, { recursive: true, force: true });
		for (const file of files) {
			if (file.startsWith(join(tmpdir(), "pi-background-bash-"))) await rm(join(file, ".."), { recursive: true, force: true });
			else await rm(file, { force: true });
		}
	});
	const execute = (name: string, args: object) => tools.get(name)!.execute("test", args as never, undefined, undefined, ctx);
	return {
		ctx, execute,
		completion: completion.then((message) => track(message.content)),
		inspect: async () => track((await execute("background_jobs", { action: "inspect", id: 1 })).content.map((part) => part.type === "text" ? part.text : "").join("\n")),
		wait: async () => track((await execute("background_jobs", { action: "wait", id: 1, timeout: 2 })).content.map((part) => part.type === "text" ? part.text : "").join("\n")),
		track,
	};
}

function occurrences(text: string, needle: string) {
	return text.split(needle).length - 1;
}

function assertBounded(text: string) {
	// Like built-in bash, the truncation notice is additional to the bounded body.
	const body = text.replace(/\n\n\[Showing last[^\n]+\]$/, "");
	assert.ok(Buffer.byteLength(body) <= DEFAULT_MAX_BYTES);
	assert.ok(body.split("\n").length <= DEFAULT_MAX_LINES);
}

test("timeout reports contain command output exactly once", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: "printf 'timeout-marker\\n'; sleep 2", timeout: 0.05, background: true });
	for (const text of [await h.completion, await h.inspect()]) {
		// One occurrence in the command header, one in its output.
		assert.equal(occurrences(text, "timeout-marker"), 2);
		assert.equal(occurrences(text, "Command timed out after"), 1);
		assert.doesNotMatch(text, /\nError:/);
	}
});

test("stopped jobs do not duplicate their streaming output", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: "printf 'abort-marker\\n'; sleep 2", background: true });
	// Inspect until the streaming snapshot arrives, then abort the live process.
	let text = "";
	for (let i = 0; i < 100 && !text.includes("\nabort-marker\n"); i++) {
		await new Promise((resolve) => setTimeout(resolve, 10));
		text = await h.inspect();
	}
	assert.match(text, /\nabort-marker\n/);
	await h.execute("background_jobs", { action: "stop", id: 1 });
	for (const report of [await h.completion, await h.inspect()]) {
		assert.equal(occurrences(report, "abort-marker"), 2);
		assert.equal(occurrences(report, "Command aborted"), 1);
		assert.doesNotMatch(report, /\nError:/);
	}
});

test("notifications and inspections bound assembled reports and retain spill files", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: "seq 1 4000", background: true });
	for (const text of [await h.completion, await h.inspect()]) {
		assertBounded(text);
		assert.match(text, /\n4000\n/);
		const path = [...text.matchAll(/Full output: ([^\]\n]+)/g)].at(-1)![1];
		const report = h.track(await readFile(path, "utf8"));
		assert.match(report, /Job #1 — completed/);
		const rawPath = /Full output: ([^\]\n]+)/.exec(report)![1];
		assert.equal(await readFile(rawPath, "utf8"), Array.from({ length: 4000 }, (_, i) => `${i + 1}\n`).join(""));
	}
});

test("wait reports apply the same line limit", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: "seq 1 4000; sleep 0.1", background: true });
	const text = await h.wait();
	assertBounded(text);
	assert.match(text, /\n4000\n/);
	const path = [...text.matchAll(/Full output: ([^\]\n]+)/g)].at(-1)![1];
	h.track(await readFile(path, "utf8"));
});

test("nonzero exits keep native error output without duplication", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: "printf 'exit-marker\\n'; exit 7", background: true });
	const text = await h.completion;
	assert.match(text, /Job #1 — failed/);
	assert.equal(occurrences(text, "\nexit-marker\n"), 1);
	assert.equal(occurrences(text, "Command exited with code 7"), 1);
});

test("oversized commands and UTF-8 output obey the byte limit", async (t) => {
	const h = await harness(t);
	await h.execute("bash", { command: `awk 'BEGIN { for (i=0;i<30000;i++) printf "終" }' # ${"x".repeat(DEFAULT_MAX_BYTES * 2)}`, background: true });
	for (const text of [await h.completion, await h.inspect()]) {
		assertBounded(text);
		assert.doesNotMatch(text, /�/);
		assert.match(text, /Full output:/);
	}
});

test("foreground execution preserves native content and structured output limits", async (t) => {
	const h = await harness(t);
	const command = "seq 1 20000";
	const native = await createBashToolDefinition(h.ctx.cwd).execute("native", { command }, undefined, undefined, h.ctx);
	const wrapped = await h.execute("bash", { command });
	const normalize = (result: typeof native) => h.track(result.content[0].type === "text" ? result.content[0].text : "").replace(/Full output: [^\]]+/g, "Full output: <path>");
	assert.equal(normalize(wrapped), normalize(native));
	const { wall_time_seconds: _wrappedTime, ...wrappedOutput } = wrapped.structuredContent as Record<string, unknown>;
	const { wall_time_seconds: _nativeTime, ...nativeOutput } = native.structuredContent as Record<string, unknown>;
	assert.deepEqual(wrappedOutput, nativeOutput);
	assert.ok(Buffer.byteLength((wrapped.structuredContent as { output: string }).output) > DEFAULT_MAX_BYTES);
});
