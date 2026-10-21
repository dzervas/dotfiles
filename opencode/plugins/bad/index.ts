// /bad marks a session for review like Pi's: the note lives in session metadata
// and the title gets an icon, so it shows in the session list but never reaches
// the model. Forks and child sessions inherit the metadata, not the title.
import { Plugin } from "@opencode/plugin";

const ICON = "󰱶 ";

export default Plugin.define({
	id: "dotfiles.bad",
	async setup(ctx) {
		await ctx.command.transform((commands) => {
			commands.add({
				name: "bad",
				description: "Mark this session for review; without a note, clear the marker",
				execute: async ({ sessionID, prompt }) => {
					const session = await ctx.session.get({ sessionID });
					const { bad: _, ...metadata } = session.metadata ?? {};
					const title = session.title?.startsWith(ICON) ? session.title.slice(ICON.length) : session.title;
					const note = prompt.text.trim();
					// An untitled session keeps no title, so OpenCode still generates one.
					await ctx.session.update(note
						? { sessionID, title: title === undefined ? undefined : ICON + title, metadata: { ...metadata, bad: { note, date: new Date().toISOString().slice(0, 10) } } }
						: { sessionID, title, metadata });
				},
			});
		});
	},
});
