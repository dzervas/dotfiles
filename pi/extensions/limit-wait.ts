/**
 * limit-wait — Handle provider usage limits (HTTP 429) gracefully.
 *
 * When a turn ends in a usage-limit / rate-limit error, this shows a modal:
 *
 *   ▸ Wait for the limit to reset (retry automatically)
 *     Cancel (Esc)
 *
 * The modal has a 10-minute countdown; if you don't respond it auto-picks
 * "Wait". While waiting it retries the turn — reusing the /continue mechanism so
 * nothing is added to the context — either at the provider's reset time (parsed
 * from the `retry-after` header or the error text when available) or every 10
 * minutes otherwise. It keeps retrying until the turn succeeds or you cancel
 * (Esc during the wait, `/limit-cancel`, or by sending a new message).
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { Key, matchesKey, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { registerResumeContextStripper, triggerResume } from "./lib/resume-turn";

const TEN_MINUTES_MS = 10 * 60_000;
const MIN_DELAY_MS = 5_000;
const MAX_DELAY_MS = 6 * 60 * 60_000; // don't wait more than 6h on a single hop
const RESET_BUFFER_MS = 5_000; // wait a touch past the stated reset
const RESET_FRESHNESS_MS = 2 * 60_000; // how long a captured 429 reset stays relevant

/** Matches provider usage/quota/rate-limit exhaustion (mirrors pi's own table). */
const LIMIT_ERROR_RE =
	/usage limit|limit reached|insufficient[_\s]?quota|quota exceeded|exceeded your current quota|out of budget|available balance|\bquota\b|rate.?limit|too many requests|\b429\b|GoUsageLimitError|FreeUsageLimitError|\bbilling\b/i;

type InspectableMessage = {
	role: string;
	stopReason?: string;
	errorMessage?: string;
};

function lastAssistant(messages: InspectableMessage[]): InspectableMessage | undefined {
	for (let i = messages.length - 1; i >= 0; i--) {
		if (messages[i]?.role === "assistant") return messages[i];
	}
	return undefined;
}

function fmtDuration(ms: number): string {
	const total = Math.max(0, Math.ceil(ms / 1000));
	const h = Math.floor(total / 3600);
	const m = Math.floor((total % 3600) / 60);
	const s = total % 60;
	const pad = (n: number) => String(n).padStart(2, "0");
	return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/** Parse a `retry-after` header (seconds or HTTP date) into an absolute epoch ms. */
function parseRetryAfter(headers: Record<string, string>): number | undefined {
	const raw = headers["retry-after"] ?? headers["Retry-After"];
	if (!raw) return undefined;
	const seconds = Number(raw);
	if (Number.isFinite(seconds)) return Date.now() + seconds * 1000;
	const date = Date.parse(raw);
	return Number.isNaN(date) ? undefined : date;
}

/** Best-effort "resets in ~3h" / "try again in 45s" parsing from error text. */
function parseResetFromText(text: string | undefined): number | undefined {
	if (!text) return undefined;
	const match = text.match(/(?:resets?|try again|retry)\s+(?:in|after)\s+~?\s*(\d+)\s*(h|hours?|m|mins?|minutes?|s|secs?|seconds?)/i);
	if (!match) return undefined;
	const value = Number(match[1]);
	if (!Number.isFinite(value)) return undefined;
	const unit = match[2].toLowerCase();
	const factor = unit.startsWith("h") ? 3600_000 : unit.startsWith("m") ? 60_000 : 1000;
	return Date.now() + value * factor;
}

/** Short human hint like "Resets in ~3h", extracted verbatim from the error. */
function resetHint(text: string | undefined): string | undefined {
	return text?.match(/resets?\s+(?:in|at)\s+[^.\n]+/i)?.[0]?.trim();
}

/** Modal component: two choices with a live countdown that auto-picks "wait". */
class LimitModal implements Component {
	private interval: ReturnType<typeof setInterval>;
	private done = false;

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly errorText: string,
		private readonly deadline: number,
		private readonly onDone: (choice: "wait" | "cancel") => void,
	) {
		this.interval = setInterval(() => {
			if (Date.now() >= this.deadline) {
				this.finish("wait");
				return;
			}
			this.tui.requestRender();
		}, 1000);
		this.interval.unref?.();
	}

	private finish(choice: "wait" | "cancel"): void {
		if (this.done) return;
		this.done = true;
		this.onDone(choice);
	}

	dispose(): void {
		clearInterval(this.interval);
	}

	invalidate(): void {}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.finish("cancel");
			return;
		}
		if (matchesKey(data, Key.return)) {
			this.finish("wait");
		}
	}

	render(width: number): string[] {
		const theme = this.theme;
		const remaining = Math.max(0, this.deadline - Date.now());
		const lines: string[] = [];
		lines.push(theme.fg("warning", theme.bold("⚠ Usage limit reached (HTTP 429)")));
		if (this.errorText) {
			for (const line of wrapTextWithAnsi(this.errorText, Math.min(width, 100))) {
				lines.push(theme.fg("muted", line));
			}
		}
		lines.push("");
		lines.push(theme.fg("dim", `Auto-continuing in ${fmtDuration(remaining)} if you don't choose.`));
		lines.push("");
		lines.push(theme.fg("accent", "⏎ Wait for the limit to reset — retry automatically"));
		lines.push(theme.fg("muted", "Esc  Cancel"));
		return lines;
	}
}

export default function limitWaitExtension(pi: ExtensionAPI): void {
	registerResumeContextStripper(pi);

	let waiting = false;
	let modalOpen = false;
	let retryTimer: ReturnType<typeof setTimeout> | undefined;
	let countdownTimer: ReturnType<typeof setInterval> | undefined;
	let escUnsub: (() => void) | undefined;
	let latestCtx: ExtensionContext | undefined;

	// Reset time captured from the most recent 429 provider response.
	let captured429ResetAt: number | undefined;
	let captured429At = 0;

	function clearTimers(): void {
		if (retryTimer) clearTimeout(retryTimer);
		if (countdownTimer) clearInterval(countdownTimer);
		retryTimer = undefined;
		countdownTimer = undefined;
	}

	function stopWaiting(ctx: ExtensionContext, notice?: string): void {
		waiting = false;
		clearTimers();
		escUnsub?.();
		escUnsub = undefined;
		if (ctx.hasUI) ctx.ui.setWidget("limit-wait", undefined);
		if (notice) ctx.ui.notify(notice, "info");
	}

	function computeDelayMs(errorText: string | undefined): number {
		let resetAt: number | undefined;
		if (captured429ResetAt && Date.now() - captured429At < RESET_FRESHNESS_MS) {
			resetAt = captured429ResetAt;
		}
		resetAt ??= parseResetFromText(errorText);
		if (resetAt === undefined) return TEN_MINUTES_MS;
		const delay = resetAt - Date.now() + RESET_BUFFER_MS;
		return Math.min(MAX_DELAY_MS, Math.max(MIN_DELAY_MS, delay));
	}

	/**
	 * Access `ctx.hasUI` safely. A ctx captured before a session
	 * replacement/reload becomes stale and throws on any property access; treat
	 * that as "abandon" rather than letting it crash a timer callback.
	 */
	function isCtxStale(ctx: ExtensionContext): boolean {
		try {
			void ctx.hasUI;
			return false;
		} catch {
			return true;
		}
	}

	function updateWidget(ctx: ExtensionContext, fireAt: number): void {
		if (isCtxStale(ctx) || !ctx.hasUI) return;
		const remaining = fmtDuration(fireAt - Date.now());
		ctx.ui.setWidget("limit-wait", [
			ctx.ui.theme.fg("warning", `⏳ Usage limit — retrying in ${remaining} · Esc to cancel`),
		]);
	}

	function armEscapeCancel(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		escUnsub?.();
		escUnsub = ctx.ui.onTerminalInput((data) => {
			if (matchesKey(data, Key.escape)) {
				stopWaiting(ctx, "Usage-limit wait cancelled");
				return { consume: true };
			}
			return undefined;
		});
	}

	function scheduleRetry(ctx: ExtensionContext, errorText: string | undefined): void {
		clearTimers();
		const delay = computeDelayMs(errorText);
		const fireAt = Date.now() + delay;

		updateWidget(ctx, fireAt);
		countdownTimer = setInterval(() => {
			const active = latestCtx ?? ctx;
			if (isCtxStale(active)) {
				// Session was replaced/reloaded out from under us; abandon quietly.
				waiting = false;
				clearTimers();
				return;
			}
			updateWidget(active, fireAt);
		}, 1000);
		countdownTimer.unref?.();

		retryTimer = setTimeout(() => {
			clearTimers();
			const active = latestCtx ?? ctx;
			if (isCtxStale(active)) {
				waiting = false;
				return;
			}
			if (active.hasUI) active.ui.setWidget("limit-wait", undefined);
			if (!triggerResume(pi, active.isIdle(), active.hasPendingMessages())) {
				// Agent busy right now — check again shortly.
				scheduleRetry(active, errorText);
			}
		}, delay);
		retryTimer.unref?.();
	}

	async function handleLimit(ctx: ExtensionContext, errorText: string): Promise<void> {
		// Already committed to waiting (or headless): retry silently, no modal.
		if (waiting || !ctx.hasUI) {
			waiting = true;
			armEscapeCancel(ctx);
			scheduleRetry(ctx, errorText);
			return;
		}
		if (modalOpen) return;

		modalOpen = true;
		const hint = resetHint(errorText);
		const choice = await ctx.ui.custom<"wait" | "cancel">((tui, theme, _kb, done) => {
			const deadline = Date.now() + TEN_MINUTES_MS;
			return new LimitModal(tui, theme, hint ?? errorText, deadline, done);
		});
		modalOpen = false;

		if (choice === "wait") {
			waiting = true;
			armEscapeCancel(ctx);
			scheduleRetry(ctx, errorText);
		} else {
			stopWaiting(ctx, "Usage-limit wait cancelled");
		}
	}

	// Capture provider reset info the moment a 429 comes back.
	pi.on("after_provider_response", (event) => {
		if (event.status !== 429) return;
		const resetAt = parseRetryAfter(event.headers);
		if (resetAt !== undefined) {
			captured429ResetAt = resetAt;
			captured429At = Date.now();
		}
	});

	pi.on("agent_end", async (event, ctx) => {
		latestCtx = ctx;
		const last = lastAssistant(event.messages as InspectableMessage[]);

		const isLimit = last?.stopReason === "error" && LIMIT_ERROR_RE.test(last.errorMessage ?? "");
		if (isLimit) {
			await handleLimit(ctx, last?.errorMessage ?? "Usage limit reached.");
			return;
		}

		// A clean finish (or a manual abort) ends any active wait loop.
		if (waiting && (last?.stopReason === "stop" || last?.stopReason === "aborted")) {
			stopWaiting(ctx, "Usage limit cleared — continued.");
		}
	});

	// If the user takes over by sending a message, drop the wait loop.
	pi.on("input", (_event, ctx) => {
		if (waiting) stopWaiting(ctx);
	});

	pi.registerCommand("limit-cancel", {
		description: "Cancel the pending usage-limit retry wait",
		handler: (_args: string | undefined, ctx: ExtensionContext) => {
			if (!waiting) {
				ctx.ui.notify("No usage-limit wait is active", "info");
				return;
			}
			stopWaiting(ctx, "Usage-limit wait cancelled");
		},
	});
}
