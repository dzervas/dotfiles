/** Loaded explicitly by pifleet. Report Pi-owned session transitions over its terminal. */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	function report(ctx: ExtensionContext) {
		if (ctx.mode !== "tui") return;
		const file = ctx.sessionManager.getSessionFile();
		if (!file) return;
		const payload = Buffer.from(JSON.stringify({ file, cwd: ctx.cwd, name: pi.getSessionName() })).toString("base64");
		process.stdout.write(`\u001b]777;pi-session;${payload}\u0007`);
	}
	pi.on("session_start", (_event, ctx) => report(ctx));
	pi.on("session_info_changed", (_event, ctx) => report(ctx));
}
