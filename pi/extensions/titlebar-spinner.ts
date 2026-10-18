/**
 * https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/examples/extensions/titlebar-spinner.ts
 * Titlebar Spinner Extension
 *
 * Shows a braille spinner while working and alternating warning icons while a dialog awaits input.
 * Uses `ctx.ui.setTitle()` to update the terminal title via the extension API.
 *
 * Usage:
 *   pi --extension examples/extensions/titlebar-spinner.ts
 */

import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { HUMAN_INPUT_EVENT, type HumanInputEvent } from "./lib/human-input.ts";
import { terminalActivity } from "./lib/terminal-progress.ts";
import { installSubagentLivenessHost, titleAnimation } from "./lib/subagent-liveness.ts";
import { activeTaskSuffix, renderTasks, TODO_CHANGED_EVENT } from "./todo/state.ts";

const INPUT_FRAMES = [" ", " "];
const BRAILLE_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

export function getBaseTitle(pi: Pick<ExtensionAPI, "getSessionName">): string {
	const cwd = path.basename(process.cwd());
	const session = pi.getSessionName();
	const title = session ? `π - ${session} - ${cwd}` : `π - ${cwd}`;
	const progress = activeTaskSuffix(renderTasks());
	return progress ? `${title} ${progress}` : title;
}

export default function (pi: ExtensionAPI) {
	const childState = installSubagentLivenessHost();
	let childTimer: ReturnType<typeof setInterval> | undefined;
	let subscriptions: Array<() => void> = [];
	let timer: ReturnType<typeof setInterval> | undefined;
	let frameIndex = 0;
	let uiCtx: ExtensionContext | undefined;
	let animation: "idle" | "working" | "waiting" = "idle";
	const waiting = new Set<symbol>();

	function renderTitle() {
		if (!uiCtx) return;
		const frames = animation === "waiting" ? INPUT_FRAMES : BRAILLE_FRAMES;
		const prefix = animation === "idle" ? "" : `${frames[frameIndex % frames.length]} `;
		uiCtx.ui.setTitle(prefix + getBaseTitle(pi));
	}

	function updateAnimation() {
		if (!uiCtx) return;
		const next = titleAnimation(waiting.size > 0, !uiCtx.isIdle() || terminalActivity.isActive(), childState(uiCtx.sessionManager.getSessionId()));
		if (next !== animation) {
			if (timer) clearInterval(timer);
			timer = undefined;
			animation = next;
			frameIndex = 0;
			if (next !== "idle") {
				timer = setInterval(() => {
					frameIndex++;
					renderTitle();
				}, next === "waiting" ? 1000 : 80);
			}
		}
		renderTitle();
	}

	function resetActivity() {
		if (childTimer) clearInterval(childTimer);
		childTimer = undefined;
		for (const unsubscribe of subscriptions) unsubscribe();
		subscriptions = [];
		if (timer) clearInterval(timer);
		timer = undefined;
		animation = "idle";
		frameIndex = 0;
		waiting.clear();
	}

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		resetActivity();
		uiCtx = ctx;
		subscriptions = [
			pi.events.on(TODO_CHANGED_EVENT, renderTitle),
			pi.events.on(HUMAN_INPUT_EVENT, (value) => {
				const event = value as HumanInputEvent;
				if (event.waiting) waiting.add(event.id);
				else waiting.delete(event.id);
				updateAnimation();
			}),
		];
		// The versioned host callback is designed to be sampled, not event-based.
		// It includes quiet detached/nested work even after agent_settled.
		// Sample shared terminal activity too, including background Bash jobs.
		childTimer = setInterval(updateAnimation, 250);
		childTimer.unref?.();
		updateAnimation();
	});

	pi.on("agent_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		uiCtx = ctx;
		updateAnimation();
	});

	pi.on("agent_settled", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		updateAnimation();
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		resetActivity();
		renderTitle();
		uiCtx = undefined;
	});
}
