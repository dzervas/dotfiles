/**
 * resume-turn — shared "resume the turn without polluting the context" logic.
 *
 * Used by both `continue.ts` (the /continue command) and `limit-wait.ts`
 * (usage-limit auto-retry). A turn is resumed by sending an invisible custom
 * message with `triggerTurn: true`; a single `context` handler then strips that
 * sentinel — and any failed (error) assistant turns — from every LLM request so
 * the model just picks up from the existing conversation state.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** customType marker for the (invisible) turn-trigger message. */
export const RESUME_CUSTOM_TYPE = "continue-resume";

type InspectableMessage = {
	role: string;
	customType?: string;
	stopReason?: string;
};

function isResumeSentinel(message: InspectableMessage): boolean {
	return message.role === "custom" && message.customType === RESUME_CUSTOM_TYPE;
}

function isFailedAssistantTurn(message: InspectableMessage): boolean {
	return message.role === "assistant" && message.stopReason === "error";
}

/**
 * Messages that must never reach the model when resuming: the resume sentinel
 * and failed assistant turns (provider errors like 429s). Pi itself drops error
 * turns from agent state on auto-retry; we mirror that for the LLM context.
 */
function shouldStripFromContext(message: InspectableMessage): boolean {
	return isResumeSentinel(message) || isFailedAssistantTurn(message);
}

/**
 * Register the single `context` handler that keeps resumed turns clean. Guarded
 * so multiple extensions can call it without stacking duplicate handlers.
 */
export function registerResumeContextStripper(pi: ExtensionAPI): void {
	const g = globalThis as typeof globalThis & { __DZERVAS_RESUME_STRIPPER__?: boolean };
	if (g.__DZERVAS_RESUME_STRIPPER__) return;
	g.__DZERVAS_RESUME_STRIPPER__ = true;

	pi.on("context", (event) => {
		const messages = event.messages as InspectableMessage[];
		if (!messages.some(shouldStripFromContext)) return;
		return { messages: messages.filter((m) => !shouldStripFromContext(m)) as typeof event.messages };
	});
}

/**
 * Trigger a fresh turn that resumes the conversation without adding any
 * user-visible or model-visible message.
 *
 * @returns false when the agent is busy or has queued messages (nothing sent).
 */
export function triggerResume(pi: ExtensionAPI, isIdle: boolean, hasPendingMessages: boolean): boolean {
	if (!isIdle || hasPendingMessages) return false;
	pi.sendMessage(
		{
			customType: RESUME_CUSTOM_TYPE,
			content: "Continue.",
			display: false,
		},
		{ triggerTurn: true },
	);
	return true;
}
