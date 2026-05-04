import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

export const PI_SANDBOX_STATE_KEY = Symbol.for("dzervas.pi.sandbox");
export const PI_SANDBOX_STATE_EVENT = "sandbox:state";

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

export default function sandboxExtension(pi: ExtensionAPI) {
	publish(pi);

	pi.on("session_start", async (_event, ctx) => {
		publish(pi);
		updateUi(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		publish(pi);
		updateUi(ctx);
	});
}
