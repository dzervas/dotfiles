// Pi's beads guidance and team actor: sessions started in a beads workspace get
// the guidance in their system prompt, and every agent shell command runs with
// BEADS_ACTOR set to the root of its subagent chain.
import { Plugin } from "@opencode/plugin";
import { BEADS_GUIDANCE, hasBeadsWorkspace } from "../../../pi/extensions/todo/beads.ts";

type SessionID = Parameters<Plugin.Context["session"]["get"]>[0]["sessionID"];

export default Plugin.define({
	id: "dotfiles.beads",
	async setup(ctx) {
		// Decided on a session's first request and persisted: a changing system
		// prompt would miss the provider's prompt cache, even if `bd init` runs later.
		async function guidance(sessionID: SessionID): Promise<string> {
			const stored = await ctx.storage.get(sessionID);
			if (typeof stored === "string") return stored;
			const { location } = await ctx.session.get({ sessionID });
			const text = hasBeadsWorkspace(location.directory) ? BEADS_GUIDANCE : "";
			await ctx.storage.set(sessionID, text);
			return text;
		}

		await ctx.session.hook("context", async (event) => {
			const text = await guidance(event.sessionID);
			if (text) event.system.push({ type: "text", text });
		});

		const roots = new Map<string, string>();
		async function root(sessionID: SessionID): Promise<string> {
			const cached = roots.get(sessionID);
			if (cached) return cached;
			const { parentID } = await ctx.session.get({ sessionID });
			const id = parentID ? await root(parentID) : sessionID;
			roots.set(sessionID, id);
			return id;
		}

		// The shell hook carries no session, so the actor is resolved per tool call
		// and matched to the shell it spawns by command.
		const pending = new Map<string, { command: string; actor: string }>();
		await ctx.tool.hook("execute.before", async (event) => {
			const command = (event.input as { command?: unknown } | undefined)?.command;
			if (event.tool !== "shell" || typeof command !== "string") return;
			pending.set(event.id, { command, actor: `oc:${await root(event.sessionID)}` });
		});
		await ctx.tool.hook("execute.after", (event) => {
			pending.delete(event.id);
		});
		await ctx.shell.hook("create.before", (event) => {
			for (const [id, call] of pending) {
				if (call.command !== event.command) continue;
				pending.delete(id);
				event.env.BEADS_ACTOR = call.actor;
				return;
			}
		});
	},
});
