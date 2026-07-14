// Extension wiring: registers commands and event handlers, and holds the
// sandbox override state. The pipeline per tool call is:
//   normalize (subject.ts) → classify (classify/) → read mode gate
//   (read-mode.ts) → decide (decide.ts) → ask (ask.ts) when needed.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { askPermission } from "./ask";
import { classify } from "./classify";
import { loadConfig } from "./config";
import { decide } from "./decide";
import { createReadMode } from "./read-mode";
import { runSelfTest } from "./self-test";
import { normalize } from "./subject";

const PI_SANDBOX_STATE_KEY = Symbol.for("dzervas.pi.sandbox");
const PI_SANDBOX_STATE_EVENT = "sandbox:state";

type SandboxState = { enabled?: boolean };

function isSandboxed() {
	const globalWithSandbox = globalThis as typeof globalThis & {
		__DZERVAS_PI_SANDBOX__?: SandboxState;
		[PI_SANDBOX_STATE_KEY]?: SandboxState;
	};
	return Boolean(
		globalWithSandbox.__DZERVAS_PI_SANDBOX__?.enabled ||
		globalWithSandbox[PI_SANDBOX_STATE_KEY]?.enabled,
	);
}

export default function permissionsExtension(pi: ExtensionAPI) {
	const readMode = createReadMode(pi);
	let sandboxed = isSandboxed();
	let disablePermissions = sandboxed;

	pi.events.on(PI_SANDBOX_STATE_EVENT, (state) => {
		const wasSandboxed = sandboxed;
		sandboxed = Boolean((state as SandboxState | undefined)?.enabled);
		if (sandboxed && !wasSandboxed) disablePermissions = true;

		if (sandboxed) {
			pi.registerCommand("yolo", {
				description: "Toggle allow all permissions (sandboxed)",
				handler: async (_args, ctx) => {
					if (!sandboxed) {
						disablePermissions = false;
					} else {
						disablePermissions = !disablePermissions;
					}
					ctx.ui.setStatus(
						"permissions-read-mode",
						disablePermissions
							? ctx.ui.theme.fg("error", "  yolo")
							: ctx.ui.theme.fg("success", "󰏫 edit"),
					);
				},
			});
		}
	});

	function permissionsDisabled() {
		return (sandboxed || isSandboxed()) && disablePermissions;
	}

	pi.registerCommand("read-only", {
		description: "Toggle read-only mode: /read-only [on|off|toggle]",
		handler: async (args, ctx) => {
			const action = args.trim().toLowerCase();
			if (!action || action === "toggle") return readMode.set(!readMode.enabled, ctx);
			if (action === "on") return readMode.set(true, ctx);
			if (action === "off") return readMode.set(false, ctx);
			ctx.ui.notify("Usage: /read-mode [on|off|toggle]", "warning");
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		if (permissionsDisabled()) {
			readMode.clear(ctx);
			ctx.ui.setStatus("permissions-read-mode", ctx.ui.theme.fg("error", "  yolo"));
			return;
		}

		const failures = await runSelfTest();
		if (failures.length === 0) ctx.ui.notify("[permissions] self-test passed", "info");
		else {
			ctx.ui.notify(`[permissions] self-test failed (${failures.length})`, "error");
			ctx.ui.setWidget(
				"permissions-self-test",
				failures.map((failure) => `- ${failure}`),
			);
		}
		readMode.restore(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		if (permissionsDisabled()) return;
		readMode.restore(ctx);
	});

	pi.on("tool_call", async (event, ctx) => {
		if (permissionsDisabled()) return { block: false, reason: "Permissions disabled in sandbox" };

		const subject = await classify(normalize(event), { signal: ctx.signal, localLlm: true });
		if (readMode.enabled) {
			const readModeDecision = readMode.decide(subject, ctx);
			if (readModeDecision) return readModeDecision;
		}
		const result = decide(subject, loadConfig());
		if (result.action === "allow") return { block: false, reason: result.reason };
		if (result.action === "deny") return { block: true, reason: result.reason };
		return askPermission(pi, subject, result.reason, ctx);
	});
}
