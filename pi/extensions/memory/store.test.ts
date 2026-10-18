import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import test, { type TestContext } from "node:test";
import { MAX_BYTES, MAX_ENTRIES, decodeNote, encodeNote, formatNotes, formatStartupNotes, indexLimitError, namespace, noteKey, planChange, projectRoot, projectSlug, recordedSnapshot, searchNotes, SNAPSHOT_ENTRY, sortNotes, type Note } from "./store.ts";

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

test("note-count overflow warns but remembering and replacing still plan complete changes", () => {
	assert.equal(MAX_ENTRIES, 200);
	const notes = Array.from({ length: MAX_ENTRIES }, (_, i) => ({ date: "2026-10-02", text: `${i}` }));
	const original = structuredClone(notes);
	assert.equal(indexLimitError(notes), undefined);
	const added = { date: "2026-10-03", text: "201" };
	assert.deepEqual(planChange(notes, "remember", added.text, undefined, added.date), { add: added });
	const overflowing = [...notes, added];
	assert.match(indexLimitError(overflowing)!, /200/);
	assert.deepEqual(planChange(overflowing, "replace", "updated", "0", added.date), {
		remove: "0", add: { date: added.date, text: "updated" },
	});
	assert.deepEqual(planChange(overflowing, "remember", added.text), {});
	assert.deepEqual(notes, original);
});

test("25 KiB is inclusive, and a one-byte overflow warns without rejecting the write", () => {
	assert.equal(MAX_BYTES, 25 * 1024);
	const date = "2026-10-18";
	const overhead = Buffer.byteLength(formatNotes([{ date, text: "" }]), "utf8");
	const text = "x".repeat(MAX_BYTES - overhead);
	assert.equal(indexLimitError([{ date, text }]), undefined);
	assert.equal(formatStartupNotes([{ date, text }]), formatNotes([{ date, text }]));
	assert.deepEqual(planChange([], "remember", text, undefined, date), { add: { date, text } });
	assert.deepEqual(planChange([], "remember", text + "x", undefined, date), { add: { date, text: text + "x" } });
	assert.equal(Buffer.byteLength(formatNotes([{ date, text: text + "x" }])), MAX_BYTES + 1);
	assert.match(indexLimitError([{ date, text: text + "x" }])!, /bytes/);
});

test("byte limits count UTF-8 bytes rather than multibyte characters", () => {
	const date = "2026-10-18";
	const available = MAX_BYTES - Buffer.byteLength(formatNotes([{ date, text: "" }]));
	const text = "π".repeat(Math.floor(available / 2)) + "x".repeat(available % 2);
	assert.equal(Buffer.byteLength(formatNotes([{ date, text }])), MAX_BYTES);
	assert.equal(indexLimitError([{ date, text }]), undefined);
	assert.ok(indexLimitError([{ date, text: text + "π" }]));
	assert.deepEqual(planChange([], "remember", text + "π", undefined, date), { add: { date, text: text + "π" } });
});

/** Overflow may hide notes from startup, but never split or skip a note in its prefix. */
function assertStartupPrefix(notes: Note[]) {
	const original = structuredClone(notes);
	const rendered = formatStartupNotes(notes);
	assert.ok(Buffer.byteLength(rendered, "utf8") <= MAX_BYTES);
	assert.equal(Buffer.from(rendered).toString("utf8"), rendered);
	assert.ok(!rendered.includes("\uFFFD"));
	const lines = rendered.split("\n").filter((line) => line.startsWith("- "));
	assert.ok(lines.length <= MAX_ENTRIES);
	assert.deepEqual(lines, notes.slice(0, lines.length).map(({ date, text }) => `- ${date}: ${text}`));
	assert.match(rendered, /prefix|truncat|omitt/i);
	assert.match(rendered, /list/);
	assert.match(rendered, /search/);
	assert.deepEqual(notes, original);
	return lines;
}

test("startup includes ordinary notes unchanged and bounds note-count overflow to 200 complete entries", () => {
	assert.equal(formatStartupNotes([]), formatNotes([]));
	const notes = Array.from({ length: MAX_ENTRIES + 3 }, (_, i) => ({ date: "2026-10-18", text: `note ${i}` }));
	assert.equal(formatStartupNotes(notes.slice(0, MAX_ENTRIES)), formatNotes(notes.slice(0, MAX_ENTRIES)));
	assert.equal(assertStartupPrefix(notes).length, MAX_ENTRIES);
	assert.equal(searchNotes(notes, "note").length, MAX_ENTRIES + 3);
	assert.ok(formatNotes(notes).includes("note 202"));
});

test("startup reserves notice space and never splits multibyte notes to fill the byte budget", () => {
	const notes = Array.from({ length: 40 }, (_, i) => ({ date: "2026-10-18", text: `${i}: ${"🦊π".repeat(200)}` }));
	const lines = assertStartupPrefix(notes);
	assert.ok(lines.length > 0 && lines.length < notes.length);
	assert.equal(searchNotes(notes, "🦊").length, notes.length);
});

test("an oversized first note yields only a notice, not a partial note or later entries", () => {
	const notes = [{ date: "2026-10-18", text: "🦊".repeat(MAX_BYTES) }, { date: "2026-10-18", text: "later small note" }];
	assert.equal(assertStartupPrefix(notes).length, 0);
	assert.ok(formatNotes(notes).includes(notes[0].text));
});

test("soft limits do not permit malformed notes", () => {
	const notes = [{ date: "2026-10-18", text: "x".repeat(MAX_BYTES) }];
	for (const text of ["", "   ", "a\nb", "a\rb", "a\tb", "a\0b"]) {
		assert.throws(() => planChange(notes, "remember", text), /single-line/);
		assert.throws(() => planChange(notes, "replace", text, notes[0].text), /single-line/);
	}
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
