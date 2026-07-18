import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "turn-timer";
const ICON = "󱑒 ";
const TICK_MS = 1000;

function formatDuration(ms: number): string {
	const totalSeconds = Math.floor(ms / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	const seconds = totalSeconds % 60;

	if (hours > 0) return `${hours}h${minutes}m${seconds}s`;
	if (minutes > 0) return `${minutes}m${seconds}s`;
	return `${seconds}s`;
}

// Shared, process-wide state. The extension module is a singleton across all
// in-process sessions (parent + subagents), so a single active-agent count keeps
// the timer running while any session — including background subagents — is busy.
let totalMs = 0;
let turnStart: number | undefined;
let timer: ReturnType<typeof setInterval> | null = null;
let activeAgents = 0;
let uiCtx: ExtensionContext | undefined;

function elapsed(): number {
	return totalMs + (turnStart !== undefined ? Date.now() - turnStart : 0);
}

function render(): void {
	if (!uiCtx?.hasUI) return;
	uiCtx.ui.setStatus(STATUS_KEY, uiCtx.ui.theme.fg("dim", ICON + formatDuration(elapsed())));
}

function stopTimer(): void {
	if (timer) {
		clearInterval(timer);
		timer = null;
	}
}

export default function turnTimer(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.hasUI) uiCtx = ctx;
	});

	pi.on("agent_start", async (_event, ctx) => {
		if (ctx.hasUI) uiCtx = ctx;
		activeAgents++;
		if (turnStart === undefined) turnStart = Date.now();
		render();
		stopTimer();
		timer = setInterval(render, TICK_MS);
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (ctx.hasUI) uiCtx = ctx;
		if (activeAgents > 0) activeAgents--;
		// Keep running while any other session (e.g. background subagents) is active.
		if (activeAgents > 0) {
			render();
			return;
		}
		stopTimer();
		if (turnStart !== undefined) {
			totalMs += Date.now() - turnStart;
			turnStart = undefined;
		}
		render();
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		stopTimer();
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
