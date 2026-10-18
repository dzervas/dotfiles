// Thin entry point: pi loads top-level extension files. The implementation
// lives in permissions/ — start reading at permissions/types.ts, then follow
// the pipeline: subject.ts → classify/ → decide.ts → ask.ts.

import { createRequire } from "node:module";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import permissionsExtension from "./permissions/extension";
import { isSandboxed } from "./lib/sandbox-state.ts";

export {
	PERMISSIONS_ASK_BROKER_KEY,
	PERMISSIONS_ASK_EVENT,
	type PermissionAskAnswer,
	type PermissionAskBroker,
	type PermissionAskRequest,
} from "./permissions/ask";
export type { PermissionSubject } from "./permissions/types";

export default function permissions(pi: ExtensionAPI) {
	if (isSandboxed()) return;
	permissionsExtension(pi);
	let registration: { dispose(): void } | undefined;
	pi.on("session_start", (_event, ctx) => {
		registration?.dispose();
		registration = undefined;
		// The CLI sandbox extension may load after this factory. By startup its
		// state is published; don't force permission hooks into contained children.
		if (isSandboxed()) return;
		// Resolve the public API from Pi's managed npm installation, not from
		// the symlinked dotfiles directory's unrelated dependency closure.
		const agentDir = path.join(os.homedir(), ".pi", "agent");
		const require = createRequire(path.join(agentDir, "npm", "package.json"));
		const { registerRequiredChildExtensions } = require("pi-subagents/required-child-extensions");
		// Defaults are overridable by custom agents; these hooks are mandatory
		// for native, nested and detached children. Unsupported runners fail closed.
		registration = registerRequiredChildExtensions({
			sessionId: ctx.sessionManager.getSessionId(),
			extensions: ["permissions", "permission-prompt", "protected-paths"].map((name) => ({
				id: `dotfiles.${name}`,
				path: path.join(agentDir, "extensions", `${name}.ts`),
			})),
			requireForAllRunners: true,
		});
	});
	pi.on("session_shutdown", () => {
		registration?.dispose();
		registration = undefined;
	});
}
