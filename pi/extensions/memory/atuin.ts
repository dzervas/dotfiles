import { homedir } from "node:os";
import { join } from "node:path";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

import { decodeNote, encodeNote, namespace, noteKey, projectRoot, sortNotes, type Change, type Note, type Scope } from "./store.ts";

export type ExecResult = { stdout: string; code: number; stderr?: string };
export type Runner = (command: string, args: string[]) => Promise<ExecResult>;

export const DEFAULT_FREQUENCY_MS = 5 * 60_000;
const UNITS: Record<string, number> = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 };

/**
 * The memory-only agent profile. An env override wins; otherwise the profile home-manager builds.
 * `pi.exec` has no per-call env, so process.env is pinned to the resolved profile and the atuin CLI inherits it.
 */
export function agentProfile(env: NodeJS.ProcessEnv = process.env, home = homedir()): { config: string; data: string } {
	const profile = { config: env.ATUIN_CONFIG_DIR ?? join(home, ".config", "atuin-agent"), data: env.ATUIN_DATA_DIR ?? join(home, ".local", "share", "atuin-agent") };
	if (env === process.env) {
		env.ATUIN_CONFIG_DIR ??= profile.config;
		env.ATUIN_DATA_DIR ??= profile.data;
		// atuin sync migrates legacy history with current_context(), which requires
		// ATUIN_SESSION; harness processes have no hooked shell.
		env.ATUIN_SESSION ??= "agent-memory";
	}
	return profile;
}

/** `sync_frequency` as atuin parses it: a duration like `5m`, or `0` for every access. */
export function parseFrequencyMs(value: string | undefined, fallback = DEFAULT_FREQUENCY_MS): number {
	const match = /^(\d+)(s|m|h|d)?$/u.exec(value?.trim() ?? "");
	if (!match) return fallback;
	return Number(match[1]) * (UNITS[match[2] ?? "s"] ?? 1000);
}

/** Everything `Settings::should_sync()` reads, gathered without touching the network. */
export type Gate = { autoSync: boolean; logged: boolean; lastSyncMs: number | undefined; frequencyMs: number };

export function shouldSync(gate: Gate, now = Date.now()): boolean {
	if (!gate.autoSync || !gate.logged) return false;
	if (gate.lastSyncMs === undefined) return true;
	return now - gate.lastSyncMs >= gate.frequencyMs;
}

export function gate(env: NodeJS.ProcessEnv = process.env, home = homedir()): Gate {
	const profile = agentProfile(env, home);
	const config = readConfig(profile.config);
	const meta = metaValues(profile.data, ["last_sync_time", "session", "hub_session"]);
	return {
		autoSync: config.autoSync,
		logged: Boolean(meta.session || meta.hub_session),
		lastSyncMs: meta.last_sync_time ? Date.parse(meta.last_sync_time) : undefined,
		frequencyMs: parseFrequencyMs(config.syncFrequency),
	};
}

/** Sync only when atuin's own frequency gate says it is due, and record the sync so the next access is gated. */
export async function syncIfDue(runner: Runner, env: NodeJS.ProcessEnv = process.env, home = homedir(), now = Date.now()): Promise<string | undefined> {
	if (!shouldSync(gate(env, home), now)) return undefined;
	const warning = await sync(runner);
	if (!warning) markSynced(agentProfile(env, home).data, now);
	return warning;
}

/** atuin records last_sync_time only from its daemon and the `history end` hook, never from `atuin sync`, so we write it ourselves. Best effort: a schema change would only make us sync more often. */
export function markSynced(dataDir: string, now = Date.now()): void {
	try {
		const db = new DatabaseSync(join(dataDir, "meta.db"));
		db.prepare("insert or replace into meta (key, value) values (?1, ?2)").run("last_sync_time", new Date(now).toISOString());
		db.close();
	} catch { /* nothing to gate on next time */ }
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
	// Save the replacement first so a failed edit cannot delete the original.
	if (change.add) {
		const result = await runner("atuin", ["kv", "set", "-n", ns, "-k", noteKey(change.add.text), encodeNote(change.add)]);
		if (result.code !== 0) throw new Error(`atuin kv set failed: ${result.stderr ?? `exit ${result.code}`}`);
	}
	if (change.remove && change.remove !== change.add?.text) {
		const result = await runner("atuin", ["kv", "delete", "-n", ns, noteKey(change.remove)]);
		if (result.code !== 0) throw new Error(`atuin kv delete failed: ${result.stderr ?? `exit ${result.code}`}`);
	}
}

/** Best effort: a failure is a warning, not a lost write or a failed read. */
export async function sync(runner: Runner): Promise<string | undefined> {
	const result = await runner("atuin", ["sync"]);
	return result.code === 0 ? undefined : result.stderr?.trim() || `sync failed (exit ${result.code})`;
}

export async function memoryNamespace(runner: Runner, scope: Scope, cwd: string, home = homedir()): Promise<string> {
	const root = projectRoot(cwd, home);
	if (scope === "global") return namespace(scope, root);
	return remoteUrl(runner, root).then((remote) => namespace(scope, root, remote));
}

function readConfig(configDir: string): { autoSync: boolean; syncFrequency?: string } {
	let text = "";
	try { text = readFileSync(join(configDir, "config.toml"), "utf8"); } catch { return { autoSync: true }; }
	const value = (key: string) => new RegExp(`^${key}\\s*=\\s*(.+)$`, "m").exec(text)?.[1]?.trim();
	return { autoSync: value("auto_sync") !== "false", syncFrequency: value("sync_frequency")?.replace(/^"|"$/g, "") };
}

function metaValues(dataDir: string, keys: string[]): Record<string, string> {
	const found: Record<string, string> = {};
	try {
		const db = new DatabaseSync(join(dataDir, "meta.db"), { readOnly: true });
		try {
			const statement = db.prepare("select value from meta where key = ?1");
			for (const key of keys) {
				const row = statement.get(key) as { value: string } | undefined;
				if (row) found[key] = row.value;
			}
		} finally { db.close(); }
	} catch { return found; } // no meta.db yet, or locked: treated as not logged in / never synced
	return found;
}

async function remoteUrl(runner: Runner, root: string): Promise<string | undefined> {
	const result = await runner("git", ["-C", root, "remote", "get-url", "origin"]);
	return result.code === 0 ? result.stdout.trim() : undefined;
}
