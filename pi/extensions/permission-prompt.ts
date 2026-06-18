import {
	createBashToolDefinition,
	createEditToolDefinition,
	createFindToolDefinition,
	createGrepToolDefinition,
	createLsToolDefinition,
	createReadToolDefinition,
	createWriteToolDefinition,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import type { PermissionAskRequest, PermissionSubject } from "./permissions";

const PERMISSIONS_ASK_EVENT = "permissions:ask";

function getToolDefinitions(cwd: string) {
	return {
		bash: createBashToolDefinition(cwd),
		read: createReadToolDefinition(cwd),
		edit: createEditToolDefinition(cwd),
		write: createWriteToolDefinition(cwd),
		grep: createGrepToolDefinition(cwd),
		find: createFindToolDefinition(cwd),
		ls: createLsToolDefinition(cwd),
	} as const;
}

function formatValue(value: unknown) {
	if (typeof value === "string") return value;
	return JSON.stringify(value);
}

// Clean key/value rendering for custom and MCP tools, which lack a native
// renderCall here. MCP tools are shown as `MCP(server) tool`.
function formatGenericCall(subject: PermissionSubject) {
	const header =
		subject.toolKind === "mcp"
			? `MCP(${subject.mcpServer ?? "?"}) ${subject.mcpTool ?? subject.toolName}`
			: subject.toolName;

	const entries = Object.entries(subject.input ?? {});
	if (entries.length === 0) return header;

	const args = entries.map(([key, value]) => `  ${key}: ${formatValue(value)}`);
	return [header, ...args].join("\n");
}

function formatToolCall(subject: PermissionSubject, request: PermissionAskRequest) {
	const definitions = getToolDefinitions(request.ctx.cwd);
	const definition = definitions[subject.toolName as keyof typeof definitions];
	if (!definition?.renderCall) return formatGenericCall(subject);
	try {
		const component = definition.renderCall(subject.input as any, request.ctx.ui.theme, {
			args: subject.input,
			toolCallId: `permissions:${subject.toolName}`,
			invalidate: () => {},
			lastComponent: undefined,
			state: {},
			cwd: request.ctx.cwd,
			executionStarted: false,
			argsComplete: true,
			isPartial: false,
			expanded: false,
			showImages: false,
			isError: false,
		});
		const lines = component.render(100).map((line) => line.trimEnd());
		while (lines[0]?.trim() === "") lines.shift();
		while (lines.at(-1)?.trim() === "") lines.pop();
		return lines.join("\n");
	} catch {
		return formatGenericCall(subject);
	}
}

async function answerPermissionRequest(pi: ExtensionAPI, request: PermissionAskRequest) {
	const { subject, reason, ctx } = request;
	const options = [
		"Allow once",
		"Allow once + message",
		"Allow and save",
		"Allow and save + message",
		"No",
		"No + message",
	];
	process.stderr.write("\x07"); // ring the terminal bell to flag the prompt
	const choice = await ctx.ui.select(
		`󱅞 Permission request:\n${formatToolCall(subject, request)}\n\nReason: ${reason}`,
		options,
	);

	if (choice?.includes("save")) ctx.ui.notify(request.saveRule(), "info");

	if (choice?.includes("message")) {
		const message = await ctx.ui.input("Append message to agent:");
		if (message?.trim()) pi.sendUserMessage(message.trim(), { deliverAs: "steer" });
	}

	if (choice?.startsWith("Allow")) return undefined;

	return { block: true, reason: "Blocked by user" };
}

function isPermissionAskRequest(value: unknown): value is PermissionAskRequest {
	return (
		typeof value === "object" &&
		value !== null &&
		"subject" in value &&
		"reason" in value &&
		"ctx" in value &&
		"accept" in value &&
		"resolve" in value &&
		"saveRule" in value
	);
}

export default function permissionPromptExtension(pi: ExtensionAPI) {
	pi.events.on(PERMISSIONS_ASK_EVENT, (data) => {
		if (!isPermissionAskRequest(data)) return;

		data.accept();
		void answerPermissionRequest(pi, data).then(data.resolve, (error: unknown) =>
			data.resolve({
				block: true,
				reason: error instanceof Error ? error.message : "Permission prompt failed",
			}),
		);
	});
}
