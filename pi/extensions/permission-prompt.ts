import {
	createBashToolDefinition,
	createEditToolDefinition,
	createFindToolDefinition,
	createGrepToolDefinition,
	createLsToolDefinition,
	createReadToolDefinition,
	createWriteToolDefinition,
	type ExtensionAPI,
} from "@mariozechner/pi-coding-agent";
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

function formatToolCall(subject: PermissionSubject, request: PermissionAskRequest) {
	const definitions = getToolDefinitions(request.ctx.cwd);
	const definition = definitions[subject.toolName as keyof typeof definitions];
	if (!definition?.renderCall)
		return `${subject.toolName} ${JSON.stringify(subject.input, null, 2)}`;
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
		return `${subject.toolName} ${JSON.stringify(subject.input, null, 2)}`;
	}
}

async function answerPermissionRequest(request: PermissionAskRequest) {
	const { subject, reason, ctx } = request;
	const options = ["Allow once", "Allow and save", "No"];
	const choice = await ctx.ui.select(
		`󱅞 Permission request:\n${formatToolCall(subject, request)}\n\nReason: ${reason}`,
		options,
	);

	if (choice === "Allow once") return undefined;

	if (choice === "Allow and save") {
		ctx.ui.notify(request.saveRule(), "info");
		return undefined;
	}

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
		void answerPermissionRequest(data).then(data.resolve, (error: unknown) =>
			data.resolve({
				block: true,
				reason: error instanceof Error ? error.message : "Permission prompt failed",
			}),
		);
	});
}
