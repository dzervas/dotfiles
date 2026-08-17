import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

interface InspectSystemPromptData {
	prompt: string;
	tools: Array<{
		name: string;
		description: string;
		parameters: unknown;
	}>;
}

export default function (pi: ExtensionAPI) {
	pi.registerEntryRenderer<InspectSystemPromptData>("inspect-system-prompt", (entry, { expanded }, theme) => {
		const prompt = entry.data?.prompt ?? "";
		const toolDefinitions = entry.data?.tools ?? [];
		const tools = JSON.stringify(toolDefinitions, null, 2);
		const content = `${prompt}\n${tools}`;
		const lines = content.split("\n").length;
		const words = content.trim() ? content.trim().split(/\s+/).length : 0;

		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		box.addChild(new Text(theme.fg("accent", "[system prompt]"), 0, 0));
		box.addChild(new Text(prompt, 0, 0));
		box.addChild(
			new Text(
				theme.fg(
					"accent",
					`\n[tools — separate provider API field: ${toolDefinitions.length} active${expanded ? "" : "; Ctrl+O to expand"}]`,
				),
				0,
				0,
			),
		);
		if (expanded) {
			box.addChild(new Text(tools, 0, 0));
		}
		box.addChild(new Text(theme.fg("dim", `\n[total: ${lines} lines, ${words} words]`), 0, 0));
		return box;
	});

	pi.registerCommand("inspect-system-prompt", {
		description: "Show the current system prompt and separately sent tool definitions",
		handler: async (_args, ctx) => {
			const activeTools = new Set(pi.getActiveTools());
			const tools = pi
				.getAllTools()
				.filter((tool) => activeTools.has(tool.name))
				.map((tool) => ({
					name: tool.name,
					description: tool.description,
					parameters: tool.parameters,
				}));

			pi.appendEntry<InspectSystemPromptData>("inspect-system-prompt", {
				prompt: ctx.getSystemPrompt(),
				tools,
			});
		},
	});
}
