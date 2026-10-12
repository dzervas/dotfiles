import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import test, { type TestContext } from "node:test";
import { MAX_BYTES, decodeNote, encodeNote, namespace, noteKey, planChange, projectRoot, projectSlug, recordedSnapshot, searchNotes, SNAPSHOT_ENTRY, sortNotes } from "./store.ts";

async function fixture(t: TestContext) {
	const directory = await mkdtemp(join(process.cwd(), ".memory-test-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	return directory;
}

test("project namespace follows the repository root, including worktree .git files", async (t) => {
	const directory = await fixture(t);
	const root = join(directory, "project");
	const nested = join(root, "src", "nested");
	await mkdir(nested, { recursive: true });
	await writeFile(join(root, ".git"), "gitdir: elsewhere");
	assert.equal(namespace("global", nested), "pi/global");
	assert.equal(namespace("project", projectRoot(nested, directory), "git@git.vpn.dzerv.art:dzervas/dotfiles"), "pi/dzervas/dotfiles");
});

test("slug is machine-independent, falling back to the repository directory", () => {
	assert.equal(projectSlug("/home/dzervas/Lab/dotfiles", "https://github.com/dzervas/dotfiles.git"), "dzervas/dotfiles");
	assert.equal(projectSlug("/home/dzervas/Lab/dotfiles", "git@host:dzervas/dotfiles"), "dzervas/dotfiles");
	assert.equal(projectSlug("/home/dzervas/Lab/dotfiles", "ssh://host/owner/repo"), "owner/repo");
	assert.equal(projectSlug("/home/dzervas/Lab/dotfiles"), "dotfiles");
});

test("note keys are content-addressed, so the same note cannot duplicate across machines", () => {
	assert.equal(noteKey("Prefer Fish"), noteKey("Prefer Fish"));
	assert.notEqual(noteKey("Prefer Fish"), noteKey("Prefer Fish scripts"));
	assert.match(noteKey("Prefer Fish"), /^[0-9a-f]{12}$/);
});

test("remember deduplicates, replace refreshes date, forget matches exact text", () => {
	assert.deepEqual(planChange([], "remember", "Prefer Fish", undefined, "2026-10-01"), { add: { date: "2026-10-01", text: "Prefer Fish" } });
	assert.deepEqual(planChange([{ date: "2026-10-01", text: "Prefer Fish" }], "remember", "Prefer Fish", undefined, "2026-10-02"), {});
	assert.deepEqual(
		planChange([{ date: "2026-10-01", text: "Prefer Fish" }], "replace", "Prefer Fish scripts", "Prefer Fish", "2026-10-02"),
		{ remove: "Prefer Fish", add: { date: "2026-10-02", text: "Prefer Fish scripts" } },
	);
	assert.deepEqual(planChange([{ date: "2026-10-01", text: "Prefer Fish" }], "forget", "Prefer Fish"), { remove: "Prefer Fish" });
	assert.throws(() => planChange([], "forget", "Fish"), /exact note/);
	assert.throws(() => planChange([], "remember", "a\nb"), /single-line/);
});

test("limits reject rather than silently evict, including multibyte notes", () => {
	const notes = Array.from({ length: 200 }, (_, i) => ({ date: "2026-10-02", text: `${i}` }));
	assert.throws(() => planChange(notes, "remember", "201"), /Memory is full/);
	assert.throws(() => planChange([], "remember", "π".repeat(MAX_BYTES / 2)), /Memory is full/);
	assert.equal(notes.length, 200);
});

test("values round-trip through the date-tab-text encoding", () => {
	const note = { date: "2026-10-02", text: "Prefer Fish" };
	assert.equal(encodeNote(note), "2026-10-02\tPrefer Fish");
	assert.deepEqual(decodeNote(encodeNote(note)), note);
	assert.throws(() => decodeNote("handwritten value"), /Unsupported kv value/);
});

test("search matches all case-insensitive keywords, and notes read in date order", () => {
	const notes = [{ date: "2026-10-02", text: "Use Fish scripts" }, { date: "2026-10-01", text: "Use Nix" }];
	assert.deepEqual(searchNotes(notes, "FISH use"), [notes[0]]);
	assert.deepEqual(searchNotes(notes, "Fish Nix"), []);
	assert.throws(() => searchNotes(notes, " "), /search term/);
	assert.deepEqual(sortNotes(notes), [notes[1], notes[0]]);
});

test("the recorded memory snapshot is read from the branch, ignoring other entries", () => {
	const snapshot = (text: unknown) => ({ type: "custom", customType: SNAPSHOT_ENTRY, data: { text } });
	assert.equal(recordedSnapshot([]), undefined);
	assert.equal(recordedSnapshot([{ type: "custom", customType: "other", data: { text: "x" } }, snapshot(42)]), undefined);
	assert.equal(recordedSnapshot([snapshot(""), { type: "message" }]), "");
	assert.equal(recordedSnapshot([snapshot("old"), snapshot("new")]), "new");
});
