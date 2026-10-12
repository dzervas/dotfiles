import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const ENTRY_TYPE = "bad-session";
const STATUS_KEY = "bad-session";
const ICON = "󰱶 ";

function getNote(ctx: ExtensionContext): string | undefined {
	// This marks the whole session, not a conversation branch: /tree must not
	// hide a problem recorded on another branch or resurrect a cleared marker.
	const entries = ctx.sessionManager.getEntries();
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (entry.type === "custom" && entry.customType === ENTRY_TYPE) {
			return (entry.data as { note: string | null }).note ?? undefined;
		}
	}
	return undefined;
}

function updateStatus(ctx: ExtensionContext): void {
	if (ctx.mode !== "tui") return;
	ctx.ui.setStatus(STATUS_KEY, getNote(ctx) ? ctx.ui.theme.fg("warning", ICON) : undefined);
}

export default function badSession(pi: ExtensionAPI): void {
	pi.registerCommand("bad", {
		description: "Mark this session for review; without a note, clear the marker",
		handler: async (args, ctx) => {
			const note = args.trim() || null;
			const oldNote = note === null ? getNote(ctx) : undefined;
			// Custom entries are persisted without becoming chat/model messages.
			pi.appendEntry(ENTRY_TYPE, { note });
			updateStatus(ctx);
			if (oldNote !== undefined) ctx.ui.notify(`Cleared bad-session marker: ${oldNote}`, "info");
		},
	});

	pi.registerCommand("bad?", {
		description: "Show this session's review note",
		handler: async (_args, ctx) => {
			ctx.ui.notify(getNote(ctx) ? `Bad-session marker: ${getNote(ctx)}` : "No bad-session marker.", "info");
		},
	});

	pi.on("session_start", (_event, ctx) => updateStatus(ctx));
	pi.on("session_tree", (_event, ctx) => updateStatus(ctx));
}
