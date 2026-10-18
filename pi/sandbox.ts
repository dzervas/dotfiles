import { createRequire } from "node:module";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { PI_SANDBOX_STATE_KEY, PI_SANDBOX_STATE_EVENT } from "./extensions/lib/sandbox-state.ts";
export { PI_SANDBOX_STATE_KEY, PI_SANDBOX_STATE_EVENT };

export type PiSandboxState = {
	enabled: true;
	kind: "bubblewrap";
};

declare global {
	// eslint-disable-next-line no-var
	var __DZERVAS_PI_SANDBOX__: PiSandboxState | undefined;
}

const state: PiSandboxState = { enabled: true, kind: "bubblewrap" };

function publish(pi: ExtensionAPI) {
	globalThis.__DZERVAS_PI_SANDBOX__ = state;
	(globalThis as typeof globalThis & { [PI_SANDBOX_STATE_KEY]?: PiSandboxState })[
		PI_SANDBOX_STATE_KEY
	] = state;
	pi.events.emit(PI_SANDBOX_STATE_EVENT, state);
}

function updateUi(ctx: ExtensionContext) {
	if (!ctx.hasUI) return;
	ctx.ui.setStatus("sandbox", ctx.ui.theme.fg("success", "󰆧 sandbox"));
}

export function factory() {
	return {};
}

export default function sandboxExtension(pi: ExtensionAPI) {
	publish(pi);
	let registration: { dispose(): void } | undefined;

	pi.on("session_start", async (_event, ctx) => {
		publish(pi);
		updateUi(ctx);
		registration?.dispose();
		registration = undefined;
		const require = createRequire(join(homedir(), ".pi", "agent", "npm", "package.json"));
		const { registerRequiredChildExtensions } = require("pi-subagents/required-child-extensions");
		// Propagate only this already-loaded extension, including when a child
		// overrides its extension list. Each native child publishes its own state.
		// External CLIs inherit OS containment but do not load Pi extensions.
		registration = registerRequiredChildExtensions({
			sessionId: ctx.sessionManager.getSessionId(),
			extensions: [{ id: "dotfiles.sandbox", path: fileURLToPath(import.meta.url) }],
		});
	});

	pi.on("session_shutdown", () => {
		registration?.dispose();
		registration = undefined;
	});

	pi.on("session_tree", async (_event, ctx) => {
		publish(pi);
		updateUi(ctx);
	});
}
