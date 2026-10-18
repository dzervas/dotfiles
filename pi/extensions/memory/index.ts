import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { getPrompt } from "../lib/prompts.ts";

import { agentProfile, applyChange, memoryNamespace, readNotes, syncIfDue, type Runner } from "./atuin.ts";
import { createMemoryMonitor, type MemoryData } from "./monitor.ts";
import { formatNotes, formatStartupNotes, indexLimitError, planChange, recordedSnapshot, searchNotes, SNAPSHOT_ENTRY, sortNotes, type Action, type Note, type Scope } from "./store.ts";

const scopes = ["global", "project"] as const;
const TIMEOUT_MS = 5000;
const SYNC_TIMEOUT_MS = 20000;
const guidance = getPrompt("memory", "guidance");

function result(text: string, isError = false) {
	return { content: [{ type: "text" as const, text }], details: {}, ...(isError ? { isError: true } : {}) };
}

export default function memoryExtension(pi: ExtensionAPI) {
	const snapshots = new Map<string, string>();
	const sessionId = (ctx: ExtensionContext) => ctx.sessionManager.getSessionId();
	let access: Promise<void> = Promise.resolve();
	let lifecycle = 0;

	// Keep panel writes, model writes and polling from interleaving locally.
	function serial<T>(work: () => Promise<T>): Promise<T> {
		const pending = access.then(work, work);
		access = pending.then(() => {}, () => {});
		return pending;
	}

	function runner(ctx: ExtensionContext, signal: AbortSignal | undefined, timeout = TIMEOUT_MS): Runner {
		const cwd = ctx.cwd;
		return (command, args) => pi.exec(command, args, { cwd, timeout, signal });
	}

	async function load(ctx: ExtensionContext, selected: readonly Scope[], signal?: AbortSignal) {
		agentProfile();
		const cwd = ctx.cwd;
		const run = runner(ctx, signal);
		const warning = await syncIfDue(runner(ctx, signal, SYNC_TIMEOUT_MS));
		const data = new Map<Scope, { namespace: string; notes: Note[] }>();
		for (const scope of selected) {
			const namespace = await memoryNamespace(run, scope, cwd);
			data.set(scope, { namespace, notes: await readNotes(run, namespace) });
		}
		return { data, warning };
	}

	const monitor = createMemoryMonitor(pi, async (ctx, signal) => (await serial(() => load(ctx, scopes, signal))).data);

	function mutate(ctx: ExtensionContext, scope: Scope, action: Exclude<Action, "list">, text: string | undefined, previous?: string, signal?: AbortSignal, notify = true) {
		return serial(async () => {
			const { data, warning } = await load(ctx, [scope], signal);
			const { namespace, notes } = data.get(scope)!;
			const change = planChange(notes, action, text, previous);
			const changed = Boolean(change.add || change.remove);
			let refreshWarning: string | undefined;
			if (changed) {
				try {
					await applyChange(runner(ctx, signal), namespace, change);
				} catch (error) {
					// A replacement may have saved the new key before deletion failed.
					const actual = await readNotes(runner(ctx, signal), namespace).catch(() => undefined);
					if (actual !== undefined) {
						data.set(scope, { namespace, notes: actual });
						monitor.observe(sessionId(ctx), data, notify);
					}
					throw error;
				}
				// Re-read after persistence to include concurrently added/synced notes.
				try {
					data.set(scope, { namespace, notes: await readNotes(runner(ctx, signal), namespace) });
				} catch {
					// The write succeeded. Don't report a failed save or invite a retry.
					data.set(scope, { namespace, notes: sortNotes([
						...notes.filter((note) => note.text !== change.remove),
						...(change.add ? [change.add] : []),
					]) });
					refreshWarning = "Memory saved, but refreshing the store failed; the next poll will retry.";
				}
			}
			monitor.observe(sessionId(ctx), data, notify);
			const updated = data.get(scope)!.notes;
			return { namespace, notes: updated, changed, warning: [warning, refreshWarning].filter(Boolean).join("\n") || undefined, indexError: indexLimitError(updated) };
		});
	}

	// Frozen startup context stays intact; live changes arrive as appended diffs.
	pi.on("session_start", async (_event, ctx) => {
		const generation = ++lifecycle;
		monitor.stop();
		const id = sessionId(ctx);
		const recorded = recordedSnapshot(ctx.sessionManager.getBranch());
		if (recorded !== undefined) snapshots.set(id, recorded);
		// A resumed parent still needs a fresh polling baseline; SDK children do not.
		if (recorded !== undefined && ctx.mode !== "tui") return;
		let initial: MemoryData | undefined;
		try {
			const { data, warning } = await serial(() => load(ctx, scopes, AbortSignal.timeout(SYNC_TIMEOUT_MS)));
			if (generation !== lifecycle) return;
			initial = data;
			if (recorded === undefined) {
				const sections: string[] = [];
				for (const [scope, { namespace, notes }] of data) {
					if (notes.length) sections.push(getPrompt("memory", "startup-section", { scope, namespace, notes: formatStartupNotes(notes) }));
				}
				const text = sections.join("\n\n");
				snapshots.set(id, text);
				pi.appendEntry(SNAPSHOT_ENTRY, { text });
			}
			if (warning && ctx.mode === "tui") ctx.ui.notify(`Memory: ${warning}`, "warning");
		} catch (error) {
			if (generation !== lifecycle) return;
			if (recorded === undefined) snapshots.set(id, "");
			if (ctx.mode === "tui") ctx.ui.notify(`Could not load memory: ${String(error)}`, "warning");
		}
		monitor.start(ctx, initial);
	});
	pi.on("session_shutdown", (_event, ctx) => {
		lifecycle++;
		monitor.stop();
		snapshots.delete(sessionId(ctx));
	});
	pi.on("before_agent_start", (event, ctx) => ({
		systemPrompt: `${event.systemPrompt}\n\n${getPrompt("memory", "system-context", { guidance, notes: snapshots.get(sessionId(ctx)) ?? "" })}`,
	}));

	pi.registerCommand("mem", {
		description: "Manage project and global memories",
		handler: async (_args, ctx) => {
			// Keep TUI dependencies out of headless child sessions.
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/mem requires TUI mode", "error");
				return;
			}
			const { showMemoryPanel } = await import("./panel.ts");
			await showMemoryPanel(pi, ctx, {
				read: async (scope) => (await serial(() => load(ctx, [scope], ctx.signal))).data.get(scope)!,
				mutate: async (scope, action, text, previous) => {
					const saved = await mutate(ctx, scope, action, text, previous, ctx.signal);
					return { notes: saved.notes, warning: [saved.warning, saved.indexError].filter(Boolean).join("\n") || undefined };
				},
			});
		},
	});

	pi.registerTool({
		name: "memory",
		label: "Memory",
		description: getPrompt("memory", "description"),
		promptSnippet: getPrompt("memory", "snippet"),
		promptGuidelines: [guidance],
		parameters: Type.Object({
			action: StringEnum(["list", "remember", "replace", "forget"] as const),
			scope: Type.Optional(StringEnum(scopes)),
			text: Type.Optional(Type.String({ description: getPrompt("memory", "parameter-text") })),
			previous: Type.Optional(Type.String({ description: getPrompt("memory", "parameter-previous") })),
		}),
		async execute(_id, params, signal, _update, ctx) {
			try {
				const scope = params.scope ?? "project";
				if (params.action === "list") {
					const { data, warning } = await serial(() => load(ctx, [scope], signal));
					const { namespace, notes } = data.get(scope)!;
					return result(`${scope} memory (${namespace})\n${notes.length ? formatNotes(notes) : "No notes."}${warning ? ` ${warning}` : ""}`);
				}
				// The tool result already acknowledges this session's own write.
				// Advance the polling baseline without echoing it as a live change.
				const saved = await mutate(ctx, scope, params.action, params.text, params.previous, signal, false);
				const message = `${scope} memory ${saved.changed ? "saved" : "unchanged"} (${saved.namespace}); ${saved.notes.length} notes.${saved.warning ? ` ${saved.warning}` : ""}`;
				return result(`${message}${saved.indexError ? `\n${saved.changed ? "Write succeeded. " : ""}${saved.indexError}` : ""}`, Boolean(saved.indexError));
			} catch (error) { return result(String(error), true); }
		},
	});

	pi.registerTool({
		name: "memory_search",
		label: "Search memory",
		description: getPrompt("memory", "search-description"),
		parameters: Type.Object({
			query: Type.String(),
			scope: Type.Optional(StringEnum(scopes)),
		}),
		async execute(_id, params, signal, _update, ctx) {
			try {
				const { data, warning } = await serial(() => load(ctx, params.scope ? [params.scope] : scopes, signal));
				const sections: string[] = [];
				for (const [scope, { notes }] of data) {
					const matches = searchNotes(notes, params.query);
					if (matches.length) sections.push(`${scope}:\n${formatNotes(matches)}`);
				}
				return result(`${sections.join("\n\n") || "No matching notes."}${warning ? `\n${warning}` : ""}`);
			} catch (error) { return result(String(error), true); }
		},
	});
}
