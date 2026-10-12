import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

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

/** Shutdown may arrive after Pi has already invalidated the context. */
function setFooter(ctx: ExtensionContext, text: string | undefined): void {
	try {
		const ui = ctx.ui;
		ui.setStatus(STATUS_KEY, text === undefined ? undefined : ui.theme.fg("accent", text));
	} catch (error) {
		if (!/extension ctx is stale after session replacement or reload/.test(String(error))) throw error;
	}
}

async function updateJjFooter(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	signal: AbortSignal,
	isCurrent: () => boolean,
): Promise<void> {
	if (!ctx.hasUI) return;

	const cwd = ctx.cwd ?? process.cwd();
	if (!hasCurrentDirJj(cwd)) {
		setFooter(ctx, undefined);
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
			signal,
		),
		jjOutput(pi, ["log", ...JJ_ARGS, "-n1", "-r@", "--template", JJ_STATUS_TEMPLATE], signal),
	]);

	if (!isCurrent()) return;
	const parts = [JJ_ICON, branch, status].filter((part): part is string => Boolean(part));
	setFooter(ctx, parts.join(" "));
}

export default function jjFooter(pi: ExtensionAPI) {
	let updateInFlight: Promise<void> | undefined;
	let refreshController: AbortController | undefined;

	function cancelRefresh(): void {
		const previous = refreshController;
		refreshController = undefined;
		updateInFlight = undefined;
		previous?.abort();
	}

	function scheduleUpdate(ctx: ExtensionContext): void {
		if (updateInFlight) return;
		const controller = new AbortController();
		refreshController = controller;
		const isCurrent = () => refreshController === controller;
		const signal = ctx.signal ? AbortSignal.any([controller.signal, ctx.signal]) : controller.signal;
		updateInFlight = updateJjFooter(pi, ctx, signal, isCurrent)
			.catch(() => {
				if (isCurrent()) setFooter(ctx, undefined);
			})
			.finally(() => {
				// An old refresh must not clear a replacement session's pending one.
				if (isCurrent()) updateInFlight = undefined;
			});
	}

	pi.on("session_start", async (_event, ctx) => {
		cancelRefresh();
		scheduleUpdate(ctx);
	});
	pi.on("agent_end", async (_event, ctx) => scheduleUpdate(ctx));
	pi.on("tool_execution_end", async (_event, ctx) => scheduleUpdate(ctx));
	pi.on("session_shutdown", async (_event, ctx) => {
		cancelRefresh();
		setFooter(ctx, undefined);
	});
}
