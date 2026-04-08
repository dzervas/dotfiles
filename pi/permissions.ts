import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PERMS_FILE = ".pi/permissions.json";

interface SavedPattern {
	pattern: string;
	enabled: boolean;
}

function loadPatterns(): SavedPattern[] {
	try {
		const f = path.join(process.cwd(), PERMS_FILE);
		if (fs.existsSync(f)) {
			return JSON.parse(fs.readFileSync(f, "utf-8"));
		}
	} catch {}
	return [];
}

function savePatterns(patterns: SavedPattern[]) {
	const dir = path.join(process.cwd(), ".pi");
	if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
	fs.writeFileSync(path.join(dir, "permissions.json"), JSON.stringify(patterns, null, 2));
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return undefined;

		const command = event.input.command as string;
		const allowed = loadPatterns().filter((p) => p.enabled);

		for (const { pattern } of allowed) {
			try {
				if (new RegExp(pattern).test(command)) return undefined;
			} catch {}
		}

		if (!ctx.hasUI) {
			return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
		}

		const choice = await ctx.ui.select(`⚠️ Dangerous command:\n\n  ${command}\n\nAllow?`, [
			"Yes",
			"Add pattern",
			"Yes, always",
			"No",
		]);

		if (choice === "No") {
			return { block: true, reason: "Blocked by user" };
		}

		if (choice === "Add pattern") {
			const patterns = loadPatterns();
			const edited = await ctx.ui.input("Add RegEx pattern:");
			if (edited !== undefined) {
				const newPattern: SavedPattern = {
					pattern: edited.trim(),
					enabled: true,
				};
				patterns.push(newPattern);
				savePatterns(patterns);
				ctx.ui.notify(`Saved '${newPattern.pattern}' to local patterns`, "info");
				if (new RegExp(newPattern.pattern).test(command)) return undefined;

				return { block: true, reason: "The new pattern did not match the command" };
			}

			return { block: true, reason: "Edit cancelled" };
		}

		if (choice === "Yes, always") {
			const escaped = command.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
			const patterns = loadPatterns();
			if (!patterns.find((p) => p.pattern === escaped)) {
				patterns.push({ pattern: escaped, enabled: true });
				savePatterns(patterns);
				ctx.ui.notify("Pattern saved", "info");
			}
		}

		return undefined;
	});
}
