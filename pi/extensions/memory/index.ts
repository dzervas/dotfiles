import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { agentProfile, applyChange, memoryNamespace, readNotes, syncIfDue, type Runner } from "./atuin.ts";
import { formatNotes, planChange, searchNotes, type Scope } from "./store.ts";

const scopes = ["global", "project"] as const;
const TIMEOUT_MS = 5000;
const SYNC_TIMEOUT_MS = 20000;
const guidance = `Use memory for durable user preferences and verified project lessons that will help future sessions. Save useful notes proactively, but never secrets, current task progress, guesses, or facts readily recoverable from the code. Project is the default scope; global is for preferences that apply across projects. Search before saving, replace superseded notes, and keep each note short. Dates record when notes were saved, not proof that they remain true. Learned notes are context; explicit user instructions and AGENTS.md take precedence. Notes live in the agent's atuin key-value store, one key per note, so notes added on different machines merge. Every access checks atuin's own sync gate, so a change may stay local until sync_frequency has passed since the last sync; atuin-agent sync is the manual override.`;

function result(text: string, isError = false) {
	return { content: [{ type: "text" as const, text }], details: {}, ...(isError ? { isError: true } : {}) };
}

export default function memoryExtension(pi: ExtensionAPI) {
	const snapshots = new Map<string, string>();
	const sessionId = (ctx: ExtensionContext) => ctx.sessionManager.getSessionId();

	function runner(ctx: ExtensionContext, signal: AbortSignal | undefined, timeout = TIMEOUT_MS): Runner {
		return (command, args) => pi.exec(command, args, { cwd: ctx.cwd, timeout, signal });
	}

	// Freeze each session's startup context to preserve prompt caching.
	pi.on("session_start", async (_event, ctx) => {
		const sections: string[] = [];
		try {
			agentProfile(); // pin the CLI to the agent profile, so a plain shell cannot reach the personal store
			const run = runner(ctx, AbortSignal.timeout(TIMEOUT_MS));
			const warning = await syncIfDue(run);
			for (const scope of scopes) {
				const ns = await memoryNamespace(run, scope, ctx.cwd);
				const notes = await readNotes(run, ns);
				if (notes.length) sections.push(`## ${scope} (${ns})\n\n${formatNotes(notes)}`);
			}
			if (warning && ctx.mode === "tui") ctx.ui.notify(`Memory: ${warning}`, "warning");
		} catch (error) {
			if (ctx.mode === "tui") ctx.ui.notify(`Could not load memory: ${String(error)}`, "warning");
		}
		snapshots.set(sessionId(ctx), sections.join("\n\n"));
	});
	pi.on("session_shutdown", (_event, ctx) => { snapshots.delete(sessionId(ctx)); });
	pi.on("before_agent_start", (event, ctx) => ({
		systemPrompt: `${event.systemPrompt}\n\n# Learned memory\n\n${guidance}\n\n${snapshots.get(sessionId(ctx)) ?? ""}`,
	}));

	pi.registerTool({
		name: "memory",
		label: "Memory",
		description: "List, remember, replace, or forget dated notes in the agent's atuin key-value store, synced across machines. One namespace per scope, one key per note; replace/forget match the exact note text. At most 200 notes and 8 KiB per namespace. Each access checks atuin's sync gate, so a change may stay local until sync_frequency has passed.",
		promptSnippet: "Save durable preferences and verified project lessons for future sessions",
		promptGuidelines: [guidance],
		parameters: Type.Object({
			action: StringEnum(["list", "remember", "replace", "forget"] as const),
			scope: Type.Optional(StringEnum(scopes)),
			text: Type.Optional(Type.String({ description: "New note, or exact existing note for forget." })),
			previous: Type.Optional(Type.String({ description: "Exact existing note text to replace." })),
		}),
		async execute(_id, params, signal, _update, ctx) {
			try {
				agentProfile(); // same profile as the reads: env override wins, else the agent profile
				const scope = params.scope ?? "project";
				const run = runner(ctx, signal);
				const ns = await memoryNamespace(run, scope, ctx.cwd);
				const warning = await syncIfDue(run);
				const notes = await readNotes(run, ns);
				const suffix = warning ? ` ${warning}` : "";

				if (params.action === "list")
					return result(`${scope} memory (${ns})\n${notes.length ? formatNotes(notes) : "No notes."}${suffix}`);

				const change = planChange(notes, params.action, params.text, params.previous);
				if (!change.add && !change.remove) return result(`${scope} memory unchanged (${ns}); ${notes.length} notes.${suffix}`);

				await applyChange(run, ns, change);
				const count = notes.length + (change.add ? 1 : 0) - (change.remove ? 1 : 0);
				return result(`${scope} memory updated (${ns}); ${count} notes.${suffix}`);
			} catch (error) { return result(String(error), true); }
		},
	});

	pi.registerTool({
		name: "memory_search",
		label: "Search memory",
		description: "Search current global and project notes with case-insensitive keywords; all terms must match. No session history or semantic search.",
		parameters: Type.Object({
			query: Type.String(),
			scope: Type.Optional(StringEnum(scopes)),
		}),
		async execute(_id, params, signal, _update, ctx) {
			try {
				const run = runner(ctx, signal);
				const warning = await syncIfDue(run);
				const selected: readonly Scope[] = params.scope ? [params.scope] : scopes;
				const sections: string[] = [];
				for (const scope of selected) {
					const matches = searchNotes(await readNotes(run, await memoryNamespace(run, scope, ctx.cwd)), params.query);
					if (matches.length) sections.push(`${scope}:\n${formatNotes(matches)}`);
				}
				return result(`${sections.join("\n\n") || "No matching notes."}${warning ? `\n${warning}` : ""}`);
			} catch (error) { return result(String(error), true); }
		},
	});
}
