import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Pi sorts extension statuses by key before rendering the bottom bar.
const STATUS_KEY = "zz-compactions";
const ICON = "󰿺 ";

function updateStatus(ctx: ExtensionContext): void {
	if (ctx.mode !== "tui") return;

	const count = ctx.sessionManager.getBranch().filter((entry) => entry.type === "compaction").length;
	ctx.ui.setStatus(
		STATUS_KEY,
		count > 0 ? ctx.ui.theme.fg("customMessageLabel", `${ICON}${count} compactions`) : undefined,
	);
}

export default function compactionStatus(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => updateStatus(ctx));
	pi.on("session_compact", (_event, ctx) => updateStatus(ctx));
	pi.on("session_tree", (_event, ctx) => updateStatus(ctx));
	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode === "tui") ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
