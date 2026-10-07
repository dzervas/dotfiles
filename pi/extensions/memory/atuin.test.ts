import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import test, { type TestContext } from "node:test";
import { agentProfile, applyChange, memoryNamespace, readNotes, sync, type Runner } from "./atuin.ts";
import { noteKey, planChange } from "./store.ts";

async function fixture(t: TestContext) {
	const directory = await mkdtemp(join(process.cwd(), ".memory-test-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	return directory;
}

/** In-memory stand-in for the atuin kv cache, driven through the same argv the tool uses. */
function fakeRunner(entries: Map<string, string>, remote?: string) {
	const calls: string[][] = [];
	const runner: Runner = async (command, args) => {
		calls.push([command, ...args]);
		if (command === "git") return remote ? { stdout: remote, code: 0 } : { stdout: "", code: 1, stderr: "no remote" };
		const [group, ...rest] = args;
		if (group === "sync") return { stdout: "", code: 1, stderr: "not logged in" };
		const [action, , ns, ...positional] = rest; // kv <action> -n <namespace> [-k] <key> [value]
		const keyFlag = positional.indexOf("-k");
		const key = keyFlag >= 0 ? positional[keyFlag + 1] : positional[0];
		const value = keyFlag >= 0 ? positional[keyFlag + 1] : positional[1];
		const id = `${ns}\0${key}`;
		if (action === "list") return { stdout: [...entries.keys()].filter((entry) => entry.startsWith(`${ns}\0`)).map((entry) => entry.slice(ns.length + 1)).join("\n"), code: 0 };
		if (action === "get") return entries.has(id) ? { stdout: `${entries.get(id)}\n`, code: 0 } : { stdout: "", code: 0 };
		if (action === "set") entries.set(id, value!);
		if (action === "delete") entries.delete(id);
		return { stdout: "", code: 0 };
	};
	return { runner, calls, entries };
}

test("the project namespace is the remote slug, so machines agree on it", async (t) => {
	const root = await fixture(t);
	await writeFile(join(root, ".git"), "gitdir: elsewhere");
	assert.equal(await memoryNamespace(fakeRunner(new Map()).runner, "global", root), "pi/global");
	assert.equal(await memoryNamespace(fakeRunner(new Map(), "git@host:dzervas/dotfiles").runner, "project", root), "pi/dzervas/dotfiles");
	assert.equal(await memoryNamespace(fakeRunner(new Map()).runner, "project", root), `pi/${basename(root)}`); // no remote -> repository directory
});

test("reads decode values and a change issues exactly the kv ops it implies", async () => {
	const ns = "pi/global";
	const { runner, calls, entries } = fakeRunner(new Map());
	entries.set(`${ns}\0${noteKey("Use Fish")}`, "2026-10-01\tUse Fish");
	entries.set(`${ns}\0${noteKey("Prefer Fish")}`, "2026-10-02\tPrefer Fish");

	const notes = await readNotes(runner, ns);
	assert.deepEqual(notes, [{ date: "2026-10-01", text: "Use Fish" }, { date: "2026-10-02", text: "Prefer Fish" }]);

	await applyChange(runner, ns, planChange(notes, "replace", "Prefer Fish scripts", "Prefer Fish", "2026-10-03"));
	assert.deepEqual(calls.slice(3), [
		["atuin", "kv", "delete", "-n", ns, noteKey("Prefer Fish")],
		["atuin", "kv", "set", "-n", ns, "-k", noteKey("Prefer Fish scripts"), "2026-10-03\tPrefer Fish scripts"],
	]);
	assert.ok(!entries.has(`${ns}\0${noteKey("Prefer Fish")}`));
});

test("sync failure is a warning, not a lost write", async () => {
	const { runner, entries } = fakeRunner(new Map());
	await applyChange(runner, "pi/global", planChange([], "remember", "Prefer Fish", undefined, "2026-10-02"));
	assert.match((await sync(runner)) ?? "", /not logged in/);
	assert.equal(entries.size, 1); // the record is still queued locally
});

test("a session without the agent profile cannot reach another atuin store", () => {
	assert.throws(() => agentProfile({}), /agent atuin profile is not set/);
	assert.deepEqual(agentProfile({ ATUIN_CONFIG_DIR: "/c", ATUIN_DATA_DIR: "/d" }), { config: "/c", data: "/d" });
});
