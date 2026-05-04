import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "jj-footer";
const JJ_ICON = "󰠬 ";
const JJ_ARGS = ["--config", "signing.backend=none", "--color", "never", "--no-graph"];

const JJ_STATUS_TEMPLATE = `
separate(" ",
  if(diff.files().filter(|e| e.status()=="added"), "+" ++ diff.files().filter(|e| e.status()=="added").len()),
  if(diff.files().filter(|e| e.status()=="removed"), "✘ " ++ diff.files().filter(|e| e.status()=="removed").len()),
  if(diff.files().filter(|e| e.status()=="modified"), "!" ++ diff.files().filter(|e| e.status()=="modified").len()),
  if(diff.files().filter(|e| e.status()=="renamed"), " " ++ diff.files().filter(|e| e.status()=="renamed").len()),
  if(diff.files().filter(|e| e.status()=="copied"), " " ++ diff.files().filter(|e| e.status()=="copied").len()),
  if(conflict, " "),
  if(divergent, "⇕ "),
  if(hidden, "󰘓 "),
  surround("\\\"", "\\\"", truncate_end(24, description.first_line(), "…")),
)`;

function hasCurrentDirJj(cwd: string): boolean {
	return fs.existsSync(path.join(cwd, ".jj"));
}

async function jjOutput(
	pi: ExtensionAPI,
	args: string[],
	signal?: AbortSignal,
): Promise<string | undefined> {
	const result = await pi.exec("jj", args, { signal, timeout: 5000 });
	if (result.code !== 0) return undefined;
	return result.stdout.trim();
}

async function updateJjFooter(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;

	const cwd = ctx.cwd ?? process.cwd();
	if (!hasCurrentDirJj(cwd)) {
		ctx.ui.setStatus(STATUS_KEY, undefined);
		return;
	}

	const [branch, status] = await Promise.all([
		jjOutput(
			pi,
			[
				"log",
				...JJ_ARGS,
				"--ignore-working-copy",
				"-r",
				"closest_bookmark(@-)",
				"--template",
				'bookmarks.join("/")',
			],
			ctx.signal,
		),
		jjOutput(pi, ["log", ...JJ_ARGS, "-n1", "-r@", "--template", JJ_STATUS_TEMPLATE], ctx.signal),
	]);

	const parts = [JJ_ICON, branch, status].filter((part): part is string => Boolean(part));
	ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", parts.join(" ")));
}

export default function jjFooter(pi: ExtensionAPI) {
	let updateInFlight: Promise<void> | undefined;

	function scheduleUpdate(ctx: ExtensionContext): void {
		if (updateInFlight) return;
		updateInFlight = updateJjFooter(pi, ctx)
			.catch(() => ctx.ui.setStatus(STATUS_KEY, undefined))
			.finally(() => {
				updateInFlight = undefined;
			});
	}

	pi.on("session_start", async (_event, ctx) => scheduleUpdate(ctx));
	pi.on("agent_end", async (_event, ctx) => scheduleUpdate(ctx));
	pi.on("tool_execution_end", async (_event, ctx) => scheduleUpdate(ctx));
	pi.on("session_shutdown", async (_event, ctx) => ctx.ui.setStatus(STATUS_KEY, undefined));
}
