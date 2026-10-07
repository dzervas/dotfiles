import { homedir } from "node:os";

import { decodeNote, encodeNote, namespace, noteKey, projectRoot, sortNotes, type Change, type Note, type Scope } from "./store.ts";

export type ExecResult = { stdout: string; code: number; stderr?: string };
export type Runner = (command: string, args: string[]) => Promise<ExecResult>;

/** The memory-only agent profile; this is the only atuin store a sandboxed session may reach. */
export function agentProfile(env: NodeJS.ProcessEnv = process.env, home = homedir()): { config: string; data: string } {
	const config = env.ATUIN_CONFIG_DIR, data = env.ATUIN_DATA_DIR;
	if (!config || !data)
		throw new Error("The agent atuin profile is not set; run through pis, which pins ATUIN_CONFIG_DIR and ATUIN_DATA_DIR to it.");
	return { config, data };
}

export async function memoryNamespace(runner: Runner, scope: Scope, cwd: string, home = homedir()): Promise<string> {
	const root = projectRoot(cwd, home);
	if (scope === "global") return namespace(scope, root);
	const remote = await remoteUrl(runner, root);
	return namespace(scope, root, remote);
}

/** Value reads have no bulk output, so each key costs one `kv get`; at note scale that is cheap. */
export async function readNotes(runner: Runner, ns: string): Promise<Note[]> {
	const listing = await runner("atuin", ["kv", "list", "-n", ns]);
	if (listing.code !== 0) throw new Error(`atuin kv list failed: ${listing.stderr ?? `exit ${listing.code}`}`);
	const notes: Note[] = [];
	for (const key of listing.stdout.split("\n").filter(Boolean)) {
		const value = await runner("atuin", ["kv", "get", "-n", ns, key]);
		if (value.code !== 0) throw new Error(`atuin kv get failed for ${key}: ${value.stderr ?? `exit ${value.code}`}`);
		if (!value.stdout.trim()) continue; // tombstoned between list and get
		notes.push(decodeNote(value.stdout.trim()));
	}
	return sortNotes(notes);
}

export async function applyChange(runner: Runner, ns: string, change: Change): Promise<void> {
	if (change.remove) {
		const result = await runner("atuin", ["kv", "delete", "-n", ns, noteKey(change.remove)]);
		if (result.code !== 0) throw new Error(`atuin kv delete failed: ${result.stderr ?? `exit ${result.code}`}`);
	}
	if (change.add) {
		const result = await runner("atuin", ["kv", "set", "-n", ns, "-k", noteKey(change.add.text), encodeNote(change.add)]);
		if (result.code !== 0) throw new Error(`atuin kv set failed: ${result.stderr ?? `exit ${result.code}`}`);
	}
}

/** Best effort: writes stay local records until something syncs them, so a failure is a warning, not a failed write. */
export async function sync(runner: Runner): Promise<string | undefined> {
	const result = await runner("atuin", ["sync"]);
	return result.code === 0 ? undefined : result.stderr?.trim() || `sync failed (exit ${result.code})`;
}

async function remoteUrl(runner: Runner, root: string): Promise<string | undefined> {
	const result = await runner("git", ["-C", root, "remote", "get-url", "origin"]);
	return result.code === 0 ? result.stdout.trim() : undefined;
}
