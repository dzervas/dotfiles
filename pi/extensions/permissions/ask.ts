// The ask flow: emits a request that the permission-prompt extension answers.

import type {
	ExtensionAPI,
	ExtensionContext,
	ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { saveRule } from "./config";
import type { PermissionSubject } from "./types";

export const PERMISSIONS_ASK_EVENT = "permissions:ask";

export type PermissionAskRequest = {
	subject: PermissionSubject;
	reason: string;
	ctx: ExtensionContext;
	accept: () => void;
	resolve: (result: ToolCallEventResult | undefined) => void;
	saveRule: () => string;
};

export async function askPermission(
	pi: ExtensionAPI,
	subject: PermissionSubject,
	reason: string,
	ctx: ExtensionContext,
): Promise<ToolCallEventResult | undefined> {
	if (!ctx.hasUI) return { block: true, reason: `${reason} (no UI available)` };

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
