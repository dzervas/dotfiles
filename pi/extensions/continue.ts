/**
 * continue — Resume a stopped turn without polluting the context.
 *
 * Adds a `/continue` command that triggers a fresh agent turn without adding
 * any visible or model-visible "continue" message. Useful after you hit a
 * provider limit or press escape by mistake and want the agent to simply pick
 * up where it left off.
 *
 * The actual mechanism (invisible trigger message + context stripping) lives in
 * ./lib/resume-turn and is shared with the usage-limit auto-retry extension.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { registerResumeContextStripper, triggerResume } from "./lib/resume-turn";

export default function continueExtension(pi: ExtensionAPI): void {
	registerResumeContextStripper(pi);

	pi.registerCommand("continue", {
		description: "Resume the stopped turn without adding a message to the context",
		handler: (_args: string | undefined, ctx: ExtensionContext) => {
			if (!ctx.isIdle()) {
				ctx.ui.notify("Agent is already running", "warning");
				return;
			}
			triggerResume(pi, ctx.isIdle(), ctx.hasPendingMessages());
		},
	});
}
