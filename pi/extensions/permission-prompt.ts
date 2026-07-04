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
import {
	type DialogueOption,
	type DialogueResult,
	ScrollableDialogue,
} from "./lib/scrollable-dialogue";

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

// Choose a syntax-highlighted body for the dialog. Bash and the context-mode
// execute tools carry source/commands worth highlighting; everything else
// falls back to the renderCall/generic key-value dump as plain text.
function formatBody(
	subject: PermissionSubject,
	request: PermissionAskRequest,
): { body: string; language?: string } {
	if (subject.toolKind === "builtin" && subject.toolName === "bash")
		return { body: subject.rawInput, language: "bash" };

	const input = subject.input ?? {};

	// ctx_execute / ctx_execute_file: a single code block in its own language.
	if (
		(subject.toolName === "ctx_execute" || subject.toolName === "ctx_execute_file") &&
		typeof input.code === "string"
	)
		return {
			body: input.code,
			language: typeof input.language === "string" ? input.language : undefined,
		};

	// ctx_batch_execute: show each command on its own line, highlighted as shell.
	if (subject.toolName === "ctx_batch_execute" && Array.isArray(input.commands))
		return {
			body: (input.commands as Array<{ label?: string; command?: string }>)
				.map((entry) => `# ${entry.label ?? ""}\n${entry.command ?? ""}`)
				.join("\n\n"),
			language: "bash",
		};

	return { body: formatToolCall(subject, request) };
}

function classifierEmoji(action: "allow" | "ask" | "deny", confidence: number): string {
	if (confidence < 90) return "❔ ";
	if (action === "allow") return "✅ ";
	if (action === "deny") return "🛑 ";
	return "⚠️ ";
}
function classifierDetails(subject: PermissionSubject): string[] | undefined {
	const advice = subject.llmAdvice;
	if (!advice) return undefined;

	const emoji = classifierEmoji(advice.action, advice.confidence);

	return [
		`${emoji}Local LLM classifier (advisory only): ${advice.action} (${advice.confidence}%)`,
		`LLM reason: ${advice.reason}`,
	];
}

async function answerPermissionRequest(pi: ExtensionAPI, request: PermissionAskRequest) {
	const { subject, reason, ctx } = request;

	const { body, language } = formatBody(subject, request);

	const options: DialogueOption[] = [
		{ value: "allow", label: "Allow once", allowMessage: true },
		{ value: "allow-save", label: "Allow and save", allowMessage: true },
		{ value: "deny", label: "No", allowMessage: true },
	];

	process.stderr.write("\x07"); // ring the terminal bell to flag the prompt

	const result = await ctx.ui.custom<DialogueResult | null>((tui, theme, _kb, done) =>
		new ScrollableDialogue(
			tui,
			theme,
			{
				title: "󱅞 Permission request",
				body,
				language,
				reason: `Reason: ${reason}`,
				details: classifierDetails(subject),
				options,
				messagePrompt: "Append message to agent:",
			},
			done,
		),
	);

	if (!result) return { block: true, reason: "Blocked by user" };

	if (result.value === "allow-save") ctx.ui.notify(request.saveRule(), "info");

	if (result.message) pi.sendUserMessage(result.message, { deliverAs: "steer" });

	if (result.value === "allow" || result.value === "allow-save") return undefined;

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
