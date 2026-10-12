/**
 * Read-only beads context for the todo widget: the claimed bead, its epic, and
 * the state of the epic's children. Only `bd list/show/ready --json` run here;
 * the extension never writes to beads. Also the agent guidance injected into
 * sessions started in a beads workspace.
 *
 * The snapshot is repository state, not session state, so it lives outside the
 * replayed per-session todo store and is never persisted in tool results.
 */

import fs from "node:fs";
import path from "node:path";

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
}

/** The subset of `pi.exec` used, so tests can substitute a fake `bd`. */
export type Exec = (
	command: string,
	args: string[],
	options: { cwd: string; timeout: number },
) => Promise<{ code: number; stdout: string }>;

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

async function bdJson(exec: Exec, cwd: string, args: string[]): Promise<RawIssue[] | undefined> {
	const result = await exec("bd", [...args, "--json"], { cwd, timeout: 5000 });
	if (result.code !== 0) return undefined;
	return JSON.parse(result.stdout) as RawIssue[];
}

/** Undefined when nothing is claimed or `bd` fails. */
export async function fetchBeads(exec: Exec, cwd: string): Promise<BeadsSnapshot | undefined> {
	const active = await bdJson(exec, cwd, ["list", "--status", "in_progress", "--brief", "-n", "0"]);
	const claimed = active && pickClaimed(active);
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
export const BEADS_GUIDANCE = `# Beads

This repository tracks durable work in beads (\`bd\`), a dependency-aware issue tracker. Add \`--json\` when parsing its output.

- Take work from \`bd ready --exclude-type epic --exclude-label human\` with \`bd update <id> --claim\`; the claimed bead is the unit of work, and the todo tool tracks the steps inside it. Keep the two separate: beads never become todos, todos never become beads.
- File work discovered outside the claimed bead's scope as \`needs-triage\` (see Triage roles) and leave it for the user.
- Durable facts go to the memory tool; bd's \`remember\` and \`prime\` duplicate it and stay unused.
- Sync (\`bd dolt push\`/\`pull\`) and beads configuration change only when the user asks.

## Issue tracker for engineering skills

This section is the repository's issue-tracker and triage-label configuration for skills such as to-spec, to-tickets, triage, implement-spec, wayfinder, and code-review. It replaces \`docs/agents/issue-tracker.md\` and \`docs/agents/triage-labels.md\`, which are intentionally absent: treat the tracker as configured and skip \`/setup-matt-pocock-skills\`.

- Publish: \`bd create "Title" -t task|feature|bug|epic --stdin\` with the body on stdin. A spec is an epic; its tickets take \`--parent <spec-id>\`. Children inherit the parent's labels unless created with \`--no-inherit-labels\`.
- Fetch: \`bd show <id> --json --include-comments\`. List: \`bd list --json [-l <label>] [-s <status>]\`.
- Comment: \`bd comments add <id> "..."\`. Labels: \`bd update <id> --add-label X --remove-label Y\`.
- Blocking: \`--deps <blocker-id>\` on create, or \`bd dep add\`. A bead is ready once every blocker is closed.
- Close: \`bd close <id> -r "<reason>"\`. Work lands on the branch without PRs, and PRs are not a request surface.

Triage roles map to beads as follows:

| Role | Beads |
| --- | --- |
| \`ready-for-agent\` | status \`open\`, no role label |
| \`ready-for-human\` | status \`open\`, label \`human\` |
| \`needs-triage\` | status \`blocked\`, label \`needs-triage\` (\`bd create ... -s blocked -l needs-triage\`) |
| \`needs-info\` | status \`blocked\`, label \`needs-info\` |
| \`wontfix\` | closed with label \`wontfix\` |

Leaving triage: swap the role label and set \`-s open\` (or close it for \`wontfix\`).

Wayfinding operations:

- Map: an epic labelled \`wayfinder:map\`; find it with \`bd list -t epic -l wayfinder:map\`. Its notes hold Decisions-so-far.
- Child ticket: \`bd create ... --parent <map> --no-inherit-labels -l wayfinder:<type>\` (\`research\`, \`prototype\`, \`grilling\`, or \`task\`).
- Blocking: \`--deps <blocker-id>\`. Frontier: \`bd ready --parent <map>\`, first listed wins.
- Claim: \`bd update <id> --claim\` before any work.
- Resolve: \`bd comments add <id> "<answer>"\`, \`bd close <id> -r resolved\`, then \`bd update <map> --append-notes "<gist> (<id>)"\`.`;

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

export function beadsSnapshot(): BeadsSnapshot | undefined {
	return current;
}

export function setBeadsSnapshot(snapshot: BeadsSnapshot | undefined): void {
	current = snapshot;
}
