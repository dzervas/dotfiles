/**
 * Re-applies hand-written patches to third-party Pi packages installed at
 * runtime into ~/.pi/agent/npm/node_modules/ (not managed by Nix, reverted on
 * every reinstall). Runs on session start; each patch is idempotent. Restart pi
 * after adding a patch, since the target module is already loaded.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface Patch {
	/** Short patch name, shown in warnings. */
	name: string;
	/** Path relative to ~/.pi/agent/npm/node_modules/. */
	file: string;
	/** Exact text to replace. */
	find: string;
	/** Replacement text; if already present the patch is considered applied. */
	replace: string;
}

const PATCHES: Patch[] = [
	{
		// AgentSession.prompt() resolves after a provider failure and records an
		// assistant message with stopReason "error". Without this check, pi-subagents
		// reports success and returns stale text from an earlier assistant message.
		name: "pi-subagents: fail initial runs on terminal provider errors",
		file: "@gotgenes/pi-subagents/src/lifecycle/subagent-session.ts",
		find: "      await session.prompt(effectivePrompt);\n      this.meta.lifecycle.completed({",
		replace: "      await session.prompt(effectivePrompt);\n      const response = session.messages.at(-1);\n      if (response?.role === \"assistant\" && response.stopReason === \"error\") {\n        throw new Error(response.errorMessage || \"Subagent model request failed\");\n      }\n      this.meta.lifecycle.completed({",
	},
	{
		name: "pi-subagents: fail resumed runs on terminal provider errors",
		file: "@gotgenes/pi-subagents/src/lifecycle/subagent-session.ts",
		find: "      await session.prompt(prompt);\n    } finally {",
		replace: "      await session.prompt(prompt);\n      const response = session.messages.at(-1);\n      if (response?.role === \"assistant\" && response.stopReason === \"error\") {\n        throw new Error(response.errorMessage || \"Subagent model request failed\");\n      }\n    } finally {",
	},
];

const MODULES_DIR = join(homedir(), ".pi", "agent", "npm", "node_modules");

function applyPatch(patch: Patch): string | undefined {
	const path = join(MODULES_DIR, patch.file);

	let content: string;
	try {
		content = readFileSync(path, "utf8");
	} catch (error) {
		return `cannot read ${path}: ${(error as Error).message}`;
	}

	if (content.includes(patch.replace)) return undefined;
	if (!content.includes(patch.find)) return `pattern not found in ${path}`;

	try {
		writeFileSync(path, content.replace(patch.find, patch.replace));
	} catch (error) {
		return `cannot write ${path}: ${(error as Error).message}`;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx: ExtensionContext) => {
		for (const patch of PATCHES) {
			const failure = applyPatch(patch);
			if (failure) ctx.ui.notify(`local-patches: ${patch.name} failed - ${failure}`, "warning");
		}
	});
}
