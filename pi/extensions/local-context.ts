import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const LOCAL_CONTEXT_FILES = ["AGENTS.local.md", ".pi/AGENTS.md"];

export default function (pi: ExtensionAPI) {
	let localContext = "";

	pi.on("session_start", async (_event, ctx) => {
		const sections: string[] = [];

		for (const relativePath of LOCAL_CONTEXT_FILES) {
			try {
				const content = await readFile(join(ctx.cwd, relativePath), "utf8");
				sections.push(`## ${relativePath}\n\n${content.trim()}`);
			} catch (error) {
				if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
					ctx.ui.notify(`Could not load local context from ${relativePath}`, "warning");
				}
			}
		}

		localContext = sections.join("\n\n");
	});

	pi.on("before_agent_start", (event) => {
		if (!localContext) return;

		return {
			systemPrompt: `${event.systemPrompt}\n\n# Local project context\n\n${localContext}`,
		};
	});
}
