import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { type Exec, fetchBeads, fetchUnclaimedParents, GUIDANCE_ENTRY, hasBeadsWorkspace, type RawIssue, recordedGuidance } from "./beads.ts";

const issue = (id: string, status: string, extra: Partial<RawIssue> = {}): RawIssue => ({
	id,
	title: `Title ${id}`,
	status,
	issue_type: "task",
	...extra,
});

/** A fake `bd` answering by subcommand and `--parent`, recording every call. */
function fakeBd(rows: { active: RawIssue[]; epic?: RawIssue; children?: RawIssue[]; ready?: RawIssue[] }) {
	const calls: string[][] = [];
	const exec: Exec = async (_command, args) => {
		calls.push(args);
		const [sub] = args;
		const out =
			sub === "show" ? [rows.epic]
			: sub === "ready" ? rows.ready ?? []
			: args.includes("--parent") ? rows.children ?? []
			: rows.active;
		return { code: 0, stdout: JSON.stringify(out) };
	};
	return { exec, calls };
}

test("a claimed child shows its epic and the children's states in id order", async () => {
	const { exec } = fakeBd({
		active: [issue("p-1.2", "in_progress", { parent: "p-1" })],
		epic: issue("p-1", "open", { issue_type: "epic" }),
		children: [
			issue("p-1.10", "open"),
			issue("p-1.2", "in_progress", { parent: "p-1" }),
			issue("p-1.1", "closed"),
			issue("p-1.3", "open"),
		],
		ready: [issue("p-1.3", "open")],
	});
	const snapshot = await fetchBeads(exec, "/repo");
	assert.deepEqual(snapshot?.claimed, { id: "p-1.2", title: "Title p-1.2", state: "in_progress" });
	assert.deepEqual(snapshot?.epic, { id: "p-1", title: "Title p-1" });
	assert.deepEqual(
		snapshot?.children.map((c) => `${c.id}:${c.state}`),
		["p-1.1:closed", "p-1.2:in_progress", "p-1.3:ready", "p-1.10:blocked"],
	);
});

test("a claimed epic is its own epic and is not looked up again", async () => {
	const epic = issue("p-1", "in_progress", { issue_type: "epic" });
	const { exec, calls } = fakeBd({ active: [epic], children: [issue("p-1.1", "open")], ready: [] });
	const snapshot = await fetchBeads(exec, "/repo");
	assert.equal(snapshot?.epic?.id, "p-1");
	assert.equal(snapshot?.claimed.id, "p-1");
	assert.ok(!calls.some(([sub]) => sub === "show"));
});

test("a claimed leaf wins over a claimed epic", async () => {
	const { exec } = fakeBd({
		active: [issue("p-1", "in_progress", { issue_type: "epic" }), issue("p-1.1", "in_progress", { parent: "p-1" })],
		epic: issue("p-1", "in_progress", { issue_type: "epic" }),
	});
	assert.equal((await fetchBeads(exec, "/repo"))?.claimed.id, "p-1.1");
});

test("a claimed bead without a parent has no epic and makes no further calls", async () => {
	const { exec, calls } = fakeBd({ active: [issue("p-9", "in_progress", { issue_type: "bug" })] });
	const snapshot = await fetchBeads(exec, "/repo");
	assert.equal(snapshot?.epic, undefined);
	assert.deepEqual(snapshot?.children, []);
	assert.equal(calls.length, 1);
});

test("idle parents use the unassigned top-level non-closed query without a limit", async () => {
	const calls: string[][] = [];
	const exec: Exec = async (_command, args, options) => {
		calls.push(args);
		assert.equal(options.cwd, "/repo");
		return { code: 0, stdout: JSON.stringify([issue("p-1", "open", { issue_type: "epic" }), issue("p-2", "blocked")]) };
	};
	assert.deepEqual(await fetchUnclaimedParents(exec, "/repo"), [
		{ id: "p-1", title: "Title p-1" },
		{ id: "p-2", title: "Title p-2" },
	]);
	assert.deepEqual(calls, [["list", "--no-assignee", "--no-parent", "--brief", "-n", "0", "--json"]]);
	assert.deepEqual(await fetchUnclaimedParents(fakeBd({ active: [] }).exec, "/repo"), []);
	assert.deepEqual(await fetchUnclaimedParents(async () => ({ code: 1, stdout: "" }), "/repo"), []);
});

test("nothing claimed or a failing bd yields no snapshot", async () => {
	assert.equal(await fetchBeads(fakeBd({ active: [] }).exec, "/repo"), undefined);
	assert.equal(await fetchBeads(async () => ({ code: 1, stdout: "" }), "/repo"), undefined);
});

test("only a workspace with metadata counts, found from any subdirectory", () => {
	const root = fs.mkdtempSync(path.join(os.tmpdir(), "beads-test-"));
	try {
		const nested = path.join(root, "a", "b");
		fs.mkdirSync(nested, { recursive: true });
		// bd's global ~/.beads has no metadata.json and must not count.
		fs.mkdirSync(path.join(root, ".beads"));
		assert.equal(hasBeadsWorkspace(nested, {}), false);
		fs.writeFileSync(path.join(root, ".beads", "metadata.json"), "{}");
		assert.equal(hasBeadsWorkspace(nested, {}), true);
		assert.equal(hasBeadsWorkspace(os.tmpdir(), { BEADS_DIR: "/elsewhere/.beads" }), true);
	} finally {
		fs.rmSync(root, { recursive: true, force: true });
	}
});

test("the recorded guidance is read from the branch, including an empty record", () => {
	const record = (text: unknown) => ({ type: "custom", customType: GUIDANCE_ENTRY, data: { text } });
	assert.equal(recordedGuidance([]), undefined);
	assert.equal(recordedGuidance([{ type: "custom", customType: "other", data: { text: "x" } }, record(1)]), undefined);
	// A session started outside beads records "" and must keep it.
	assert.equal(recordedGuidance([record(""), { type: "message" }]), "");
	assert.equal(recordedGuidance([record("old"), record("new")]), "new");
});
