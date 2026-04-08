import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PERMS_FILE = ".agent-permissions.json";

enum SavedPatternAction {
	deny = "deny",
	ask = "ask",
	allow = "allow",
}

interface SavedPattern {
	tool: string;
	patterns: string[];
	action: SavedPatternAction;
	comment: string | undefined;
}

function loadPatterns(): SavedPattern[] {
	let paths = [
		path.join(os.homedir(), ".pi", "permissions.json"),
		path.join(process.cwd(), PERMS_FILE),
	];
	let patterns: SavedPattern[] = [];

	for (const p in paths) {
		try {
			if (fs.existsSync(p)) {
				patterns.concat(JSON.parse(fs.readFileSync(p, "utf-8")));
			}
		} catch {}
	}
	return [];
}

function savePatterns(patterns: SavedPattern[]) {
	const dir = path.join(process.cwd(), ".pi");
	if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
	fs.writeFileSync(path.join(dir, "permissions.json"), JSON.stringify(patterns, null, 2));
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		const toolPatterns = loadPatterns().filter((p) => p.tool === event.toolName);
		let effectiveInput;
		switch (event.toolName) {
			case "bash":
				// TODO: Split commands based on ;/&&/||/etc.
				effectiveInput = event.input.command;
				break;
			case "read":
			case "edit":
			case "write":
			case "grep":
			case "find":
			case "ls":
				effectiveInput = event.input.path;
				break;
			default:
				// TODO: Add support for mcp tools
				return { block: true, reason: "MCP tools are not supported yet" };
		}

		for (const action in SavedPatternAction) {
			const actionPatterns = toolPatterns.filter((p) => p.action === action);
			for (const rule of actionPatterns) {
				for (const pattern in rule.patterns) {
					// TODO: Add basic templating support for file-based rules
					if (new RegExp(pattern).test(effectiveInput as string)) {
						switch (action) {
							case SavedPatternAction.allow:
								return { block: false, reason: `Allowed due to ${pattern}` };
							case SavedPatternAction.deny:
								return { block: true, reason: `Blocked due to ${pattern}` };
						}

						console.log(`Forcing ask due to ${pattern}`);
					}
				}
			}
		}

		if (!ctx.hasUI) {
			return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
		}

		const choice = await ctx.ui.select(
			`Permission request:\n\n  ${effectiveInput}(${effectiveInput})\n\nAllow?`,
			["Yes", "Add pattern", "Yes, always", "No"],
		);

		if (choice === "No") {
			return { block: true, reason: "Blocked by user" };
		}

		if (choice === "Add pattern") {
			const edited = await ctx.ui.input("Add RegEx pattern:");
			if (edited !== undefined) {
				const newPattern: SavedPattern = {
					tool: event.toolName,
					patterns: [edited.trim()],
					action: SavedPatternAction.allow,
					comment: `Manually added through the UI for '${effectiveInput}'`,
				};

				toolPatterns.push(newPattern);
				savePatterns(toolPatterns);
				ctx.ui.notify(`Saved '${newPattern.patterns[0]}' to local patterns`, "info");
				if (new RegExp(newPattern.patterns[0]).test(effectiveInput as string)) return undefined;

				return { block: true, reason: "The new pattern did not match the command" };
			}

			return { block: true, reason: "Edit cancelled" };
		}

		if (choice === "Yes, always") {
			const escaped = (effectiveInput as string).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
			const newPattern: SavedPattern = {
				tool: event.toolName,
				patterns: [escaped.trim()],
				action: SavedPatternAction.allow,
				comment: `Always allowed through the UI for '${effectiveInput}'`,
			};

			toolPatterns.push(newPattern);
			savePatterns(toolPatterns);
			ctx.ui.notify(`Saved '${newPattern.patterns[0]}' to local patterns`, "info");
		}

		return undefined;
	});
}
