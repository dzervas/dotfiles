/**
 * Read-only beads context for the todo widget: the claimed bead, its epic, and
 * the state of the epic's children. Only `bd list/show/ready --json` run here;
 * the extension never writes to beads. Also the agent guidance injected into
 * sessions started in a beads workspace.
 *
 * The foreground snapshot is filtered to the parent team's BEADS_ACTOR;
 * it lives outside the replayed todo store and is never persisted in tool results.
 */

import fs from "node:fs";
import path from "node:path";
import { getPrompt } from "../lib/prompts.ts";

export type BeadState = "closed" | "in_progress" | "ready" | "blocked";

export interface Bead {
	id: string;
	title: string;
	state: BeadState;
}

export interface BeadsSnapshot {
	claimed: Bead;
	/** Absent for a claimed bead without a parent; equal to `claimed` for a claimed epic. */
	epic?: { id: string; title: string };
	/** The epic's children ordered by hierarchical id; empty without an epic. */
	children: Bead[];
}

/** The subset of `bd … --json --brief` issue rows this module reads. */
export interface RawIssue {
	id: string;
	title: string;
	status: string;
	issue_type: string;
	parent?: string;
	assignee?: string;
}

/** The subset of `pi.exec` used, so tests can substitute a fake `bd`. */
export type Exec = (
	command: string,
	args: string[],
	options: { cwd: string; timeout: number },
) => Promise<{ code: number; stdout: string; stderr?: string }>;

/** One actor per parent; print-mode SDK and detached children keep its environment. */
export function setParentBeadsActor(
	sessionId: string,
	mode: string,
	parentSession?: string,
	env: NodeJS.ProcessEnv = process.env,
): string | undefined {
	const interactiveParent = mode === "tui" || mode === "rpc";
	// Native SDK children run in print mode without PI_SUBAGENT_CHILD. Their
	// header normally names the parent; an inherited pi: actor also covers
	// children of an unpersisted parent. Detached runners set the child marker.
	const child = env.PI_SUBAGENT_CHILD === "1" ||
		(!interactiveParent && (Boolean(parentSession) || env.BEADS_ACTOR?.startsWith("pi:")));
	if (!child) env.BEADS_ACTOR = `pi:${sessionId}`;
	return env.BEADS_ACTOR;
}

/** pi.exec has no env option; env sets envelope mode without changing Pi's process. */
export function execBd(exec: Exec, cwd: string, args: string[]) {
	return exec("env", ["BD_JSON_ENVELOPE=1", "bd", ...args], { cwd, timeout: 5000 });
}

/**
 * Whether `cwd` is inside a beads workspace. `~/.beads` holds bd's global state
 * (metrics), so a bare `.beads` directory is not enough: require the
 * workspace's `metadata.json`. `$BEADS_DIR` points bd at a workspace directly.
 */
export function hasBeadsWorkspace(cwd: string, env: NodeJS.ProcessEnv = process.env): boolean {
	if (env.BEADS_DIR) return true;
	for (let dir = path.resolve(cwd); ; dir = path.dirname(dir)) {
		if (fs.existsSync(path.join(dir, ".beads", "metadata.json"))) return true;
		if (path.dirname(dir) === dir) return false;
	}
}

/** Prefer a claimed leaf over a claimed epic; either way its epic is shown. */
export function pickClaimed(active: readonly RawIssue[]): RawIssue | undefined {
	return active.find((issue) => issue.issue_type !== "epic") ?? active[0];
}

const childNumber = (id: string) => Number(id.slice(id.lastIndexOf(".") + 1)) || 0;

/**
 * Open children that `bd ready` does not list are waiting on a blocker (or are
 * explicitly blocked/deferred), so they all render as blocked.
 */
export function buildSnapshot(
	claimed: RawIssue,
	epic: RawIssue | undefined,
	children: readonly RawIssue[],
	ready: readonly RawIssue[],
): BeadsSnapshot {
	const readyIds = new Set(ready.map((issue) => issue.id));
	const state = (issue: RawIssue): BeadState => {
		if (issue.status === "closed") return "closed";
		if (issue.status === "in_progress") return "in_progress";
		return readyIds.has(issue.id) ? "ready" : "blocked";
	};
	return {
		claimed: { id: claimed.id, title: claimed.title, state: "in_progress" },
		epic: epic && { id: epic.id, title: epic.title },
		children: children
			.map((issue) => ({ id: issue.id, title: issue.title, state: state(issue) }))
			.sort((a, b) => childNumber(a.id) - childNumber(b.id)),
	};
}

/** Unassigned, non-closed top-level beads, including blocked/deferred work. */
export async function fetchUnclaimedParents(exec: Exec, cwd: string): Promise<Pick<Bead, "id" | "title">[]> {
	const parents = await bdJson(exec, cwd, ["list", "--no-assignee", "--no-parent", "--brief", "-n", "0"]);
	return (parents ?? []).map(({ id, title }) => ({ id, title }));
}

async function bdJson(exec: Exec, cwd: string, args: string[]): Promise<RawIssue[] | undefined> {
	const result = await execBd(exec, cwd, [...args, "--json"]);
	if (result.code !== 0) return undefined;
	const envelope = JSON.parse(result.stdout) as { schema_version: number; data: RawIssue[] };
	if (!Array.isArray(envelope.data)) throw new Error("bd JSON envelope must contain an issue array in data");
	return envelope.data;
}

/** Undefined when nothing is claimed or `bd` fails. */
export async function fetchBeads(exec: Exec, cwd: string, actor: string): Promise<BeadsSnapshot | undefined> {
	if (!actor) return undefined;
	const active = await bdJson(exec, cwd, ["list", "--status", "in_progress", "--assignee", actor, "--brief", "-n", "0"]);
	const claimed = active && pickClaimed(active.filter((issue) => issue.assignee === actor));
	if (!claimed) return undefined;
	const epicId = claimed.issue_type === "epic" ? claimed.id : claimed.parent;
	if (!epicId) return buildSnapshot(claimed, undefined, [], []);

	const [epic, children, ready] = await Promise.all([
		claimed.issue_type === "epic" ? [claimed] : bdJson(exec, cwd, ["show", epicId]),
		bdJson(exec, cwd, ["list", "--parent", epicId, "--all", "--brief", "-n", "0"]),
		bdJson(exec, cwd, ["ready", "--parent", epicId, "--brief", "-n", "0"]),
	]);
	return buildSnapshot(claimed, epic?.[0], children ?? [], ready ?? []);
}

/**
 * System-prompt section for sessions started in a beads workspace. It replaces
 * the instruction files `bd init` would write, which assume other agents and
 * conflict with the todo and memory tools.
 */
export const BEADS_GUIDANCE = getPrompt("todo", "beads-guidance");

/** Session entry recording the beads section frozen into the system prompt ("" for none). */
export const GUIDANCE_ENTRY = "todo-beads-guidance";

/** The beads section recorded on this session branch, if any. */
export function recordedGuidance(branch: Iterable<unknown>): string | undefined {
	let text: string | undefined;
	for (const entry of branch) {
		const { type, customType, data } = entry as { type?: string; customType?: string; data?: { text?: unknown } };
		if (type === "custom" && customType === GUIDANCE_ENTRY && typeof data?.text === "string") text = data.text;
	}
	return text;
}

// The foreground snapshot read by the ctx-less widget renderer.
let current: BeadsSnapshot | undefined;
let parents: Pick<Bead, "id" | "title">[] = [];

export function unclaimedParents(): readonly Pick<Bead, "id" | "title">[] {
	return parents;
}

export function setUnclaimedParents(value: Pick<Bead, "id" | "title">[]): void {
	parents = value;
}

export function beadsSnapshot(): BeadsSnapshot | undefined {
	return current;
}

export function setBeadsSnapshot(snapshot: BeadsSnapshot | undefined): void {
	current = snapshot;
}
