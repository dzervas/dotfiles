/**
 * /tools - list all configured tools with their metadata.
 *
 * Collapsed: one line per tool (active marker, name, source, description).
 * Expanded: parameter schema and prompt guidelines.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

interface ToolInfo {
	name: string;
	active: boolean;
	source: string;
	path: string;
	description: string;
	promptGuidelines: string[];
	parameters: unknown;
}

interface ToolsListData {
	tools: ToolInfo[];
}

export default function (pi: ExtensionAPI) {
	pi.registerEntryRenderer<ToolsListData>("tools-list", (entry, { expanded }, theme) => {
		const tools = entry.data?.tools ?? [];
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		box.addChild(new Text(theme.fg("accent", `[tools] ${tools.length} configured`), 0, 0));

		for (const tool of tools) {
			const marker = tool.active ? theme.fg("success", "*") : theme.fg("dim", " ");
			const head = `${marker} ${theme.bold(tool.name)} ${theme.fg("dim", `(${tool.source})`)}`;
			box.addChild(new Text(head, 0, 0));
			box.addChild(new Text(theme.fg("dim", `    ${tool.description}`), 0, 0));

			if (expanded) {
				box.addChild(new Text(theme.fg("dim", `    path: ${tool.path}`), 0, 0));
				for (const guideline of tool.promptGuidelines) {
					box.addChild(new Text(theme.fg("dim", `    - ${guideline}`), 0, 0));
				}
				box.addChild(new Text(theme.fg("dim", `    params: ${JSON.stringify(tool.parameters)}`), 0, 0));
			}
		}

		return box;
	});

	pi.registerCommand("tools", {
		description: "List all available tools with their metadata",
		handler: async (args) => {
			const filter = args.trim().toLowerCase();
			const active = new Set(pi.getActiveTools());

			const tools: ToolInfo[] = pi
				.getAllTools()
				.filter((tool) => !filter || tool.name.toLowerCase().includes(filter))
				.map((tool) => ({
					name: tool.name,
					active: active.has(tool.name),
					source: tool.sourceInfo.source,
					path: tool.sourceInfo.path,
					description: (tool.description ?? "").split("\n")[0],
					promptGuidelines: tool.promptGuidelines ?? [],
					parameters: tool.parameters,
				}));

			pi.appendEntry<ToolsListData>("tools-list", { tools });
		},
	});
}
