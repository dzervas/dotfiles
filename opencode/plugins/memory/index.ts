// Learned memory backed by Pi's atuin store and prompts, so both harnesses share notes.
import { execFile } from "node:child_process";
import { Plugin } from "@opencode/plugin";
import { Schema } from "effect";
import { getPrompt } from "../../../pi/extensions/lib/prompts.ts";
import { agentProfile, applyChange, memoryNamespace, readNotes, syncIfDue, type Runner } from "../../../pi/extensions/memory/atuin.ts";
import { formatNotes, formatStartupNotes, indexLimitError, planChange, searchNotes, type Scope } from "../../../pi/extensions/memory/store.ts";

const scopes = ["global", "project"] as const;
const ScopeInput = Schema.Literals(scopes);
type SessionID = Parameters<Plugin.Context["session"]["get"]>[0]["sessionID"];

function runner(cwd: string, signal: AbortSignal, timeout = 5000): Runner {
	return (command, args) => new Promise((resolve) => {
		execFile(command, args, { cwd, signal, timeout }, (error, stdout, stderr) => {
			resolve({ code: error ? (typeof error.code === "number" ? error.code : 1) : 0, stdout, stderr });
		});
	});
}

async function load(cwd: string, selected: readonly Scope[], signal: AbortSignal) {
	agentProfile();
	const warning = await syncIfDue(runner(cwd, signal, 20000));
	const run = runner(cwd, signal);
	const data = [];
	for (const scope of selected) {
		const namespace = await memoryNamespace(run, scope, cwd);
		data.push({ scope, namespace, notes: await readNotes(run, namespace) });
	}
	return { data, warning };
}

export default Plugin.define({
	id: "dotfiles.memory",
	async setup(ctx) {
		const directory = async (sessionID: SessionID) =>
			(await ctx.session.get({ sessionID })).location.directory;

		// Freeze the notes on a session's first request, persisted across server
		// restarts: a changing system prompt would miss the provider's prompt cache.
		async function snapshot(sessionID: SessionID): Promise<string> {
			const stored = await ctx.storage.get(sessionID);
			if (typeof stored === "string") return stored;
			let notes = "";
			try {
				const { data } = await load(await directory(sessionID), scopes, AbortSignal.timeout(20000));
				notes = data.flatMap(({ scope, namespace, notes }) =>
					notes.length ? [getPrompt("memory", "startup-section", { scope, namespace, notes: formatStartupNotes(notes) })] : [],
				).join("\n\n");
			} catch { /* atuin unavailable: the tools can still retry */ }
			const text = getPrompt("memory", "system-context", { guidance: getPrompt("memory", "guidance"), notes });
			await ctx.storage.set(sessionID, text);
			return text;
		}

		await ctx.session.hook("context", async (event) => {
			event.system.push({ type: "text", text: await snapshot(event.sessionID) });
		});

		await ctx.tool.transform((tools) => {
			tools.add({
				name: "memory",
				description: getPrompt("memory", "description"),
				input: Schema.Struct({
					action: Schema.Literals(["list", "remember", "replace", "forget"]),
					scope: Schema.optional(ScopeInput),
					text: Schema.optional(Schema.String.annotate({ description: getPrompt("memory", "parameter-text") })),
					previous: Schema.optional(Schema.String.annotate({ description: getPrompt("memory", "parameter-previous") })),
				}),
				execute: async (input, call) => {
					const cwd = await directory(call.sessionID);
					const scope = input.scope ?? "project";
					const { data: [{ namespace, notes }], warning } = await load(cwd, [scope], call.signal);
					if (input.action === "list") {
						return { content: `${scope} memory (${namespace})\n${notes.length ? formatNotes(notes) : "No notes."}${warning ? `\n${warning}` : ""}` };
					}
					const change = planChange(notes, input.action, input.text, input.previous);
					if (change.add || change.remove) await applyChange(runner(cwd, call.signal), namespace, change);
					const updated = await readNotes(runner(cwd, call.signal), namespace);
					const message = `${scope} memory ${change.add || change.remove ? "saved" : "unchanged"} (${namespace}); ${updated.length} notes.${warning ? ` ${warning}` : ""}`;
					const indexError = indexLimitError(updated);
					if (indexError) throw new Error(`${message}\n${indexError}`);
					return { content: message };
				},
			});
			tools.add({
				name: "memory_search",
				description: getPrompt("memory", "search-description"),
				input: Schema.Struct({ query: Schema.String, scope: Schema.optional(ScopeInput) }),
				execute: async (input, call) => {
					const { data, warning } = await load(await directory(call.sessionID), input.scope ? [input.scope] : scopes, call.signal);
					const sections = data.flatMap(({ scope, notes }) => {
						const matches = searchNotes(notes, input.query);
						return matches.length ? [`${scope}:\n${formatNotes(matches)}`] : [];
					});
					return { content: `${sections.join("\n\n") || "No matching notes."}${warning ? `\n${warning}` : ""}` };
				},
			});
		});
	},
});
