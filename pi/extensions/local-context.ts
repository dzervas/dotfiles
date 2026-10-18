import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getPrompt } from "./lib/prompts.ts";

const LOCAL_CONTEXT_FILES = ["AGENTS.local.md", ".pi/AGENTS.md"];
/** Session entry recording the local context frozen into the system prompt ("" for none). */
const SNAPSHOT_ENTRY = "local-context";

function recordedContext(ctx: ExtensionContext): string | undefined {
	let text: string | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== SNAPSHOT_ENTRY) continue;
		const data = entry.data as { text?: unknown } | undefined;
		if (typeof data?.text === "string") text = data.text;
	}
	return text;
}

export default function (pi: ExtensionAPI) {
	const contexts = new Map<string, string>();
	const sessionId = (ctx: ExtensionContext) => ctx.sessionManager.getSessionId();

	// The files are read once, when a session first starts, and the result is
	// recorded in it: reload, resume, and fork reuse the record, so editing the
	// files mid-session cannot change the system prompt and bust its cache.
	pi.on("session_start", async (_event, ctx) => {
		const recorded = recordedContext(ctx);
		if (recorded !== undefined) {
			contexts.set(sessionId(ctx), recorded);
			return;
		}

		const sections: string[] = [];
		let loaded = true;
		for (const relativePath of LOCAL_CONTEXT_FILES) {
			try {
				const content = await readFile(join(ctx.cwd, relativePath), "utf8");
				sections.push(getPrompt("local-context", "file-section", { path: relativePath, content: content.trim() }));
			} catch (error) {
				if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
					loaded = false;
					ctx.ui.notify(`Could not load local context from ${relativePath}`, "warning");
				}
			}
		}

		const text = sections.join("\n\n");
		contexts.set(sessionId(ctx), text);
		// A failed read is not recorded, so the next start of this session retries.
		if (loaded) pi.appendEntry(SNAPSHOT_ENTRY, { text });
	});
	pi.on("session_shutdown", (_event, ctx) => {
		contexts.delete(sessionId(ctx));
	});

	pi.on("before_agent_start", (event, ctx) => {
		const localContext = contexts.get(sessionId(ctx));
		if (!localContext) return;

		return {
			systemPrompt: `${event.systemPrompt}\n\n${getPrompt("local-context", "system-context", { context: localContext })}`,
		};
	});
}
