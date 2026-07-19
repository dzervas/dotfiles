/**
 * continue — Resume a stopped turn without polluting the context.
 *
 * Adds a `/continue` command that triggers a fresh agent turn without adding
 * any visible or model-visible "continue" message. Useful after you hit a
 * provider limit or press escape by
 * mistake and want the agent to simply pick up where it left off.
 *
 * How it stays out of the context:
 * - The triggering message is a custom message with `display: false`, so it
 *   never shows in the UI.
 * - A `context` handler strips that sentinel message from every LLM request, so
 *   the model never sees a "continue" prompt — it just resumes from the existing
 *   conversation state.
 */

import type {
	ContextEvent,
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

/** customType marker for the (invisible) turn-trigger message. */
const CONTINUE_CUSTOM_TYPE = "continue-resume";

function isContinueMessage(message: { role: string; customType?: string }): boolean {
	return message.role === "custom" && message.customType === CONTINUE_CUSTOM_TYPE;
}

export default function continueExtension(pi: ExtensionAPI): void {
	// Strip the sentinel from anything sent to the model so the turn resumes
	// from the existing conversation without an injected "continue" prompt.
	pi.on("context", (event: ContextEvent) => {
		if (!event.messages.some(isContinueMessage)) return;
		return { messages: event.messages.filter((m) => !isContinueMessage(m)) };
	});

	pi.registerCommand("continue", {
		description: "Resume the stopped turn without adding a message to the context",
		handler: (_args: string | undefined, ctx: ExtensionContext) => {
			if (!ctx.isIdle()) {
				ctx.ui.notify("Agent is already running", "warning");
				return;
			}

			pi.sendMessage(
				{
					customType: CONTINUE_CUSTOM_TYPE,
					content: "Continue.",
					display: false,
				},
				{ triggerTurn: true },
			);
		},
	});
}
