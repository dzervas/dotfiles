import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { getPrompt } from "../lib/prompts.ts";

export const MAX_BYTES = 25 * 1024;
export const MAX_ENTRIES = 200;
export const NAMESPACE_PREFIX = "pi";
export const KEY_LENGTH = 12;
const HEADER = `${getPrompt("memory", "notes-heading")}\n\n`;
const SEPARATOR = "\t";

export type Note = { date: string; text: string };
export type Scope = "global" | "project";
export type Action = "list" | "remember" | "replace" | "forget";
/** One kv change: a note to set, and the note text whose key to tombstone. */
export type Change = { add?: Note; remove?: string };

/** Session entry type recording the memory section frozen into the system prompt. */
export const SNAPSHOT_ENTRY = "memory-snapshot";

/** The memory section recorded on this session branch, if any. */
export function recordedSnapshot(branch: Iterable<unknown>): string | undefined {
	let text: string | undefined;
	for (const entry of branch) {
		const { type, customType, data } = entry as { type?: string; customType?: string; data?: { text?: unknown } };
		if (type === "custom" && customType === SNAPSHOT_ENTRY && typeof data?.text === "string") text = data.text;
	}
	return text;
}

export function projectRoot(cwd: string, home = homedir()): string {
	let root = resolve(cwd);
	while (!existsSync(join(root, ".git")) && !existsSync(join(root, ".jj"))) {
		const parent = dirname(root);
		if (parent === root) { root = resolve(cwd); break; }
		root = parent;
	}
	return root;
}

export function namespace(scope: Scope, root: string, remote?: string): string {
	return `${NAMESPACE_PREFIX}/${scope === "global" ? "global" : projectSlug(root, remote)}`;
}

/** Stable across machines: the remote's owner/repo, falling back to the repository directory. */
export function projectSlug(root: string, remote?: string): string {
	if (!remote) return basename(root);
	const match = /^(?:git@|ssh:\/\/|https?:\/\/|file:\/\/)?[^\/:]+[\/:](.+?)(?:\.git)?\/?$/.exec(remote.trim());
	return match?.[1] ?? basename(root);
}

/** Content-addressed: the same note text is the same key on every machine, so it cannot duplicate. */
export function noteKey(text: string): string {
	return createHash("sha256").update(text).digest("hex").slice(0, KEY_LENGTH);
}

export function encodeNote(note: Note): string {
	return `${note.date}${SEPARATOR}${note.text}`;
}

export function decodeNote(value: string): Note {
	const index = value.indexOf(SEPARATOR);
	if (index < 0) throw new Error(`Unsupported kv value ${value}; expected <date>${SEPARATOR}<note>.`);
	return { date: value.slice(0, index), text: value.slice(index + 1) };
}

export function formatNotes(notes: Note[]): string {
	return HEADER + notes.map(({ date, text }) => `- ${date}: ${text}\n`).join("");
}

/** Storage is not capped: these limits apply only to the startup index. */
export function indexLimitError(notes: Note[]): string | undefined {
	const bytes = Buffer.byteLength(formatNotes(notes), "utf8");
	if (notes.length <= MAX_ENTRIES && bytes <= MAX_BYTES) return undefined;
	return getPrompt("memory", "index-limit", { count: notes.length, maxEntries: MAX_ENTRIES, bytes, maxBytes: MAX_BYTES });
}

/** Load a complete-note prefix, reserving room for the overflow notice. */
export function formatStartupNotes(notes: Note[]): string {
	const warning = indexLimitError(notes);
	if (!warning) return formatNotes(notes);
	const notice = `\n${getPrompt("memory", "startup-overflow", { warning })}\n`;
	let text = HEADER;
	let bytes = Buffer.byteLength(text + notice, "utf8");
	for (const note of notes.slice(0, MAX_ENTRIES)) {
		const line = formatNotes([note]).slice(HEADER.length);
		const size = Buffer.byteLength(line, "utf8");
		if (bytes + size > MAX_BYTES) break;
		text += line;
		bytes += size;
	}
	return text + notice;
}

export function noteText(text: string | undefined): string {
	const value = text?.trim();
	if (!value || /[\r\n\x00-\x1f\x7f]/.test(value)) throw new Error(getPrompt("memory", "invalid-note"));
	return value;
}

/** The tool semantics, expressed as the kv ops a change implies. */
export function planChange(notes: Note[], action: Exclude<Action, "list">, text?: string, previous?: string, date = new Date().toISOString().slice(0, 10)): Change {
	const value = noteText(text);
	if (action === "remember") {
		if (notes.some((note) => note.text === value)) return {};
		const note = { date, text: value };
		return { add: note };
	}

	const target = action === "replace" ? noteText(previous) : value;
	const matches = notes.flatMap((note, i) => note.text === target ? [i] : []);
	if (matches.length !== 1) throw new Error(getPrompt("memory", "missing-note"));

	if (action === "forget") return { remove: target };

	if (notes.some((note, i) => i !== matches[0] && note.text === value)) throw new Error(getPrompt("memory", "duplicate-note"));
	const note = { date, text: value };
	return { remove: target, add: note };
}

export function searchNotes(notes: Note[], query: string): Note[] {
	const terms = query.toLocaleLowerCase().split(/\s+/).filter(Boolean);
	if (!terms.length) throw new Error(getPrompt("memory", "missing-search-term"));
	return notes.filter((note) => terms.every((term) => note.text.toLocaleLowerCase().includes(term)));
}

/** Keys are hashes, so read order comes from the date in the value. */
export function sortNotes(notes: Note[]): Note[] {
	return [...notes].sort((a, b) => a.date.localeCompare(b.date) || noteKey(a.text).localeCompare(noteKey(b.text)));
}

/** Stable, duplicate-free set diff; both date and text identify a stored note. */
export function diffNotes(before: Note[], after: Note[]): string {
	const lines = (notes: Note[]) => new Set(notes.map(({ date, text }) => `${date}: ${text}`));
	const old = lines(before);
	const next = lines(after);
	return [
		...[...old].filter((line) => !next.has(line)).sort().map((line) => `- ${line}`),
		...[...next].filter((line) => !old.has(line)).sort().map((line) => `+ ${line}`),
	].join("\n");
}
