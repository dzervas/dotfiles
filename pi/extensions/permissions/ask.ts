// The ask flow: emits a request that the permission-prompt extension answers.
//
// When the current session has no UI (e.g. a subagent), the request is bridged
// to a process-global broker registered by a UI-bearing session (see
// permission-prompt.ts) so the prompt surfaces on that session's terminal.

import type {
	ExtensionAPI,
	ExtensionContext,
	ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { saveRule } from "./config";
import type { PermissionSubject } from "./types";

export const PERMISSIONS_ASK_EVENT = "permissions:ask";

// Process-global channel used to bubble a no-UI session's permission prompt up
// to a UI-bearing session. Registered by permission-prompt.ts on globalThis.
export const PERMISSIONS_ASK_BROKER_KEY = Symbol.for("dzervas.pi.permissions.ask-broker");

export type PermissionAskAnswer = {
	value: "allow" | "allow-save" | "deny";
	message?: string;
};

// Renders the prompt on a UI-bearing session and returns the raw decision.
// Side effects (rule persistence, steering the asking agent) are applied by the
// caller against the asking session, not here.
export type PermissionAskBroker = (
	subject: PermissionSubject,
	reason: string,
) => Promise<PermissionAskAnswer | undefined>;

export type PermissionAskRequest = {
	subject: PermissionSubject;
	reason: string;
	ctx: ExtensionContext;
	accept: () => void;
	resolve: (result: ToolCallEventResult | undefined) => void;
	saveRule: () => string;
};

function getBroker(): PermissionAskBroker | undefined {
	return (globalThis as Record<PropertyKey, unknown>)[PERMISSIONS_ASK_BROKER_KEY] as
		| PermissionAskBroker
		| undefined;
}

// No UI in this session (e.g. a subagent): try to bubble the prompt up to a
// UI-bearing session via the global broker, then apply the decision here so
// rule saves and steer messages land on this session. Falls back to blocking.
async function askViaBroker(
	pi: ExtensionAPI,
	subject: PermissionSubject,
	reason: string,
): Promise<ToolCallEventResult | undefined> {
	const broker = getBroker();
	if (!broker) return { block: true, reason: `${reason} (no UI available)` };

	let answer: PermissionAskAnswer | undefined;
	try {
		answer = await broker(subject, reason);
	} catch (error) {
		return { block: true, reason: error instanceof Error ? error.message : "Permission prompt failed" };
	}
	if (!answer) return { block: true, reason: "Blocked by user" };

	if (answer.value === "allow-save") saveRule(subject);
	if (answer.message) pi.sendUserMessage(answer.message, { deliverAs: "steer" });
	if (answer.value === "allow" || answer.value === "allow-save") return undefined;
	return { block: true, reason: "Blocked by user" };
}

export async function askPermission(
	pi: ExtensionAPI,
	subject: PermissionSubject,
	reason: string,
	ctx: ExtensionContext,
): Promise<ToolCallEventResult | undefined> {
	if (!ctx.hasUI) return askViaBroker(pi, subject, reason);

	return new Promise((resolve) => {
		let accepted = false;
		const request: PermissionAskRequest = {
			subject,
			reason,
			ctx,
			accept: () => {
				accepted = true;
			},
			resolve,
			saveRule: () => saveRule(subject),
		};

		pi.events.emit(PERMISSIONS_ASK_EVENT, request);

		if (!accepted)
			resolve({ block: true, reason: `${reason} (permission prompt extension unavailable)` });
	});
}
