import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import test, { type TestContext } from "node:test";
import { DatabaseSync } from "node:sqlite";
import { agentProfile, applyChange, DEFAULT_FREQUENCY_MS, gate, memoryNamespace, parseFrequencyMs, readNotes, shouldSync, sync, syncIfDue, type Runner } from "./atuin.ts";
import { noteKey, planChange } from "./store.ts";

async function fixture(t: TestContext) {
	const directory = await mkdtemp(join(process.cwd(), ".memory-test-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	return directory;
}

/** In-memory stand-in for the atuin kv cache, driven through the same argv the tool uses. */
function fakeRunner(entries: Map<string, string>, remote?: string, syncOk = false) {
	const calls: string[][] = [];
	const runner: Runner = async (command, args) => {
		calls.push([command, ...args]);
		if (command === "git") return remote ? { stdout: remote, code: 0 } : { stdout: "", code: 1, stderr: "no remote" };
		const [group, ...rest] = args;
		if (group === "sync") return syncOk ? { stdout: "", code: 0 } : { stdout: "", code: 1, stderr: "not logged in" };
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

test("no env means the agent profile, pinned so the CLI resolves to the same store", () => {
	const before = { config: process.env.ATUIN_CONFIG_DIR, data: process.env.ATUIN_DATA_DIR };
	delete process.env.ATUIN_CONFIG_DIR;
	delete process.env.ATUIN_DATA_DIR;
	const profile = agentProfile(process.env, "/home/u");
	assert.deepEqual(profile, { config: "/home/u/.config/atuin-agent", data: "/home/u/.local/share/atuin-agent" });
	assert.equal(process.env.ATUIN_CONFIG_DIR, profile.config); // pi.exec inherits process.env, so the CLI needs the pin
	if (before.config === undefined) delete process.env.ATUIN_CONFIG_DIR; else process.env.ATUIN_CONFIG_DIR = before.config;
	if (before.data === undefined) delete process.env.ATUIN_DATA_DIR; else process.env.ATUIN_DATA_DIR = before.data;
	assert.deepEqual(agentProfile({ ATUIN_CONFIG_DIR: "/c", ATUIN_DATA_DIR: "/d" }, "/home/u"), { config: "/c", data: "/d" });
});

test("the sync gate mirrors atuin's own: auto_sync, logged in, and frequency elapsed", () => {
	const gate = { autoSync: true, logged: true, lastSyncMs: 1000, frequencyMs: 300000 };
	assert.equal(shouldSync(gate, 1000 + 300000), true);
	assert.equal(shouldSync(gate, 1000 + 299999), false);
	assert.equal(shouldSync({ ...gate, lastSyncMs: undefined }, 0), true); // never synced
	assert.equal(shouldSync({ ...gate, logged: false }, 10 ** 12), false);
	assert.equal(shouldSync({ ...gate, autoSync: false }, 10 ** 12), false);
	assert.equal(shouldSync({ ...gate, frequencyMs: 0 }, 1000), true); // sync_frequency = 0
	assert.equal(parseFrequencyMs("5m"), 300000);
	assert.equal(parseFrequencyMs("30s"), 30000);
	assert.equal(parseFrequencyMs("0"), 0);
	assert.equal(parseFrequencyMs("garbage"), DEFAULT_FREQUENCY_MS);
});

test("syncIfDue reads the gate from the profile, not the network", async (t) => {
	const directory = await fixture(t);
	const data = join(directory, "data");
	await mkdir(data, { recursive: true });
	await writeFile(join(directory, "config.toml"), 'sync_frequency = "5m"\nauto_sync = true\n');

	const open = new DatabaseSync(join(data, "meta.db"));
	open.exec("create table meta (key text primary key, value text not null)");
	open.prepare("insert into meta (key, value) values (?, ?)").run("session", "abc");
	open.prepare("insert into meta (key, value) values (?, ?)").run("last_sync_time", new Date(Date.now() - 60_000).toISOString());

	const env = { ATUIN_CONFIG_DIR: directory, ATUIN_DATA_DIR: data };
	const { runner, calls } = fakeRunner(new Map(), undefined, true);
	assert.equal(await syncIfDue(runner, env), undefined); // 1m of 5m, so not due
	assert.deepEqual(calls, []);

	open.prepare("update meta set value = ? where key = 'last_sync_time'").run(new Date(Date.now() - 400_000).toISOString());
	const now = Date.now();
	await syncIfDue(runner, env, undefined, now); // due: one sync, recorded for the next access
	assert.deepEqual(calls, [["atuin", "sync"]]);
	assert.equal(gate(env).lastSyncMs, now);
	assert.equal(await syncIfDue(runner, env, undefined, now + 1000), undefined);
	assert.deepEqual(calls, [["atuin", "sync"]]);

	open.prepare("delete from meta where key = 'session'").run(); // logged_out: never sync
	open.close();
	await syncIfDue(runner, env);
	assert.deepEqual(calls, [["atuin", "sync"]]);
});
