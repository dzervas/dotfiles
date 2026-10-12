import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import badSession from "../bad.ts";

type Command = Parameters<ExtensionAPI["registerCommand"]>[1];
type Handler = (event: unknown, ctx: ExtensionContext) => void;

function harness(mode = "tui") {
	const entries: SessionEntry[] = [];
	const commands = new Map<string, Command>();
	const handlers = new Map<string, Handler>();
	const statuses: { key: string; text: string | undefined }[] = [];
	const notices: string[] = [];
	const ctx = {
		mode,
		sessionManager: { getEntries: () => entries },
		ui: {
			setStatus: (key: string, text: string | undefined) => statuses.push({ key, text }),
			theme: { fg: (color: string, text: string) => { assert.equal(color, "warning"); return text; } },
			notify: (text: string) => notices.push(text),
		},
	} as unknown as ExtensionCommandContext;
	const pi = {
		registerCommand: (name: string, command: Command) => commands.set(name, command),
		on: (name: string, handler: Handler) => handlers.set(name, handler),
		appendEntry: (customType: string, data: unknown) => entries.push({
			type: "custom", customType, data,
			id: String(entries.length), parentId: null, timestamp: new Date().toISOString(),
		}),
	} as unknown as ExtensionAPI;
	badSession(pi);
	return {
		entries, statuses, notices,
		command: (name: string, args = "") => commands.get(name)!.handler(args, ctx),
		emit: (name: string) => handlers.get(name)!({}, ctx),
		reload: () => badSession(pi),
	};
}

test("marks silently, persists the trimmed note, and shows only the footer icon", async () => {
	const h = harness();
	await h.command("bad", "  tried to read .env  ");
	assert.equal(h.entries.length, 1);
	assert.equal(h.entries[0].type, "custom");
	assert.deepEqual((h.entries[0] as { data: unknown }).data, { note: "tried to read .env" });
	assert.deepEqual(h.statuses, [{ key: "bad-session", text: "󰱶 " }]);
	assert.deepEqual(h.notices, []);
});

test("bad? shows the latest note without appending entries or altering status", async () => {
	const h = harness();
	await h.command("bad", "first problem");
	await h.command("bad", "second problem");
	await h.command("bad?");
	assert.deepEqual(h.notices, ["second problem"]);
	assert.equal(h.entries.length, 2);
	assert.equal(h.statuses.length, 2);
});

for (const args of ["", "   "]) {
	test(`bad ${JSON.stringify(args)} clears the marker and persists the clear`, async () => {
		const h = harness();
		await h.command("bad", "problem");
		await h.command("bad", args);
		assert.deepEqual((h.entries.at(-1) as { data: unknown }).data, { note: null });
		assert.equal(h.statuses.at(-1)?.text, undefined);
		assert.deepEqual(h.notices, ["Cleared bad-session marker: problem"]);
		h.reload();
		h.emit("session_start");
		await h.command("bad?");
		assert.equal(h.statuses.at(-1)?.text, undefined);
		assert.deepEqual(h.notices, ["Cleared bad-session marker: problem", "No bad-session marker."]);
	});
}

test("restores the marker after reload and keeps it across tree navigation", async () => {
	const h = harness();
	await h.command("bad", "problem");
	h.reload();
	h.emit("session_start");
	h.emit("session_tree");
	assert.deepEqual(h.statuses.map(status => status.text), ["󰱶 ", "󰱶 ", "󰱶 "]);
});

test("a different session clears the footer and unrelated entries are ignored", async () => {
	const h = harness();
	await h.command("bad", "problem");
	h.entries.splice(0);
	h.entries.push({ type: "custom", customType: "other-extension", data: { note: "not ours" }, id: "other", parentId: null, timestamp: new Date().toISOString() });
	h.emit("session_start");
	await h.command("bad?");
	assert.equal(h.statuses.at(-1)?.text, undefined);
	assert.deepEqual(h.notices, ["No bad-session marker."]);
});

test("unmarked bad? reports no note without writing an entry", async () => {
	const h = harness();
	await h.command("bad?");
	assert.deepEqual(h.notices, ["No bad-session marker."]);
	assert.deepEqual(h.entries, []);
});

test("headless sessions can persist the marker without terminal status", async () => {
	const h = harness("json");
	await h.command("bad", "problem");
	h.emit("session_start");
	assert.equal(h.entries.length, 1);
	assert.deepEqual(h.statuses, []);
});
