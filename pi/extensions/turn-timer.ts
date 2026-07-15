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

export default function turnTimer(pi: ExtensionAPI) {
	let totalMs = 0;
	let turnStart: number | undefined;
	let timer: ReturnType<typeof setInterval> | null = null;

	function elapsed(): number {
		return totalMs + (turnStart !== undefined ? Date.now() - turnStart : 0);
	}

	function render(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", ICON + formatDuration(elapsed())));
	}

	function stopTimer(): void {
		if (timer) {
			clearInterval(timer);
			timer = null;
		}
	}

	pi.on("agent_start", async (_event, ctx) => {
		turnStart = Date.now();
		render(ctx);
		stopTimer();
		timer = setInterval(() => render(ctx), TICK_MS);
	});

	pi.on("agent_end", async (_event, ctx) => {
		stopTimer();
		if (turnStart !== undefined) {
			totalMs += Date.now() - turnStart;
			turnStart = undefined;
		}
		render(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		stopTimer();
		ctx.ui.setStatus(STATUS_KEY, undefined);
	});
}
