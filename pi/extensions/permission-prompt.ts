import {
	createBashToolDefinition,
	createEditToolDefinition,
	createFindToolDefinition,
	createGrepToolDefinition,
	createLsToolDefinition,
	createReadToolDefinition,
	createWriteToolDefinition,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
	PERMISSIONS_ASK_BROKER_KEY,
	PERMISSIONS_ASK_EVENT,
	type PermissionAskAnswer,
	type PermissionAskBroker,
	type PermissionAskRequest,
	type PermissionSubject,
} from "./permissions";
import {
	type DialogueOption,
	type DialogueResult,
	ScrollableDialogue,
} from "./lib/scrollable-dialogue";

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

function formatToolCall(subject: PermissionSubject, ctx: ExtensionContext) {
	const definitions = getToolDefinitions(ctx.cwd);
	const definition = definitions[subject.toolName as keyof typeof definitions];
	if (!definition?.renderCall) return formatGenericCall(subject);
	try {
		const component = definition.renderCall(subject.input as any, ctx.ui.theme, {
			args: subject.input,
			toolCallId: `permissions:${subject.toolName}`,
			invalidate: () => {},
			lastComponent: undefined,
			state: {},
			cwd: ctx.cwd,
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
	ctx: ExtensionContext,
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

	return { body: formatToolCall(subject, ctx) };
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

// Renders the permission dialog on the given (UI-bearing) session context and
// returns the raw decision. No side effects — callers apply rule saves and
// steer messages against the session that actually asked.
async function renderPermissionDialog(
	ctx: ExtensionContext,
	subject: PermissionSubject,
	reason: string,
	label?: string,
): Promise<PermissionAskAnswer | null> {
	const { body, language } = formatBody(subject, ctx);

	const options: DialogueOption[] = [
		{ value: "allow", label: "Allow once", allowMessage: true },
		{ value: "allow-save", label: "Allow and save", allowMessage: true },
		{ value: "deny", label: "No", allowMessage: true },
	];

	process.stderr.write("\x07"); // ring the terminal bell to flag the prompt

	const title = label ? `󱅞 Permission request — ${label}` : "󱅞 Permission request";

	const result = await ctx.ui.custom<DialogueResult | null>((tui, theme, _kb, done) =>
		new ScrollableDialogue(
			tui,
			theme,
			{
				title,
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

	if (!result) return null;
	return { value: result.value as PermissionAskAnswer["value"], message: result.message };
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

// Shared, process-wide state. The extension module is a singleton across all
// in-process sessions (parent + subagents), so a single dialog queue serializes
// every prompt onto one terminal and a single ctx points at the UI session.
let uiCtx: ExtensionContext | undefined;
let dialogChain: Promise<unknown> = Promise.resolve();

// Serialize all dialogs (same-session and bridged) so concurrent subagents
// don't fight over the terminal.
function enqueue<T>(fn: () => Promise<T>): Promise<T> {
	const run = dialogChain.then(fn, fn);
	dialogChain = run.then(
		() => undefined,
		() => undefined,
	);
	return run;
}

// The bridge target: no-UI sessions (subagents) look this up on globalThis and
// call it to surface their prompt on the UI session's terminal.
const broker: PermissionAskBroker = async (subject, reason) => {
	if (!uiCtx) return undefined;
	const ctx = uiCtx;
	const answer = await enqueue(() => renderPermissionDialog(ctx, subject, reason, "subagent"));
	return answer ?? undefined;
};

export default function permissionPromptExtension(pi: ExtensionAPI) {
	let registeredBroker = false;

	const registerBrokerIfUI = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		uiCtx = ctx;
		(globalThis as Record<PropertyKey, unknown>)[PERMISSIONS_ASK_BROKER_KEY] = broker;
		registeredBroker = true;
	};

	pi.on("session_start", async (_event, ctx) => registerBrokerIfUI(ctx));
	pi.on("session_tree", async (_event, ctx) => registerBrokerIfUI(ctx));

	pi.on("session_shutdown", async () => {
		if (!registeredBroker) return;
		const g = globalThis as Record<PropertyKey, unknown>;
		if (g[PERMISSIONS_ASK_BROKER_KEY] === broker) delete g[PERMISSIONS_ASK_BROKER_KEY];
		registeredBroker = false;
	});

	pi.events.on(PERMISSIONS_ASK_EVENT, (data) => {
		if (!isPermissionAskRequest(data)) return;

		// A UI-bearing session asked directly; keep the broker ctx fresh too.
		if (data.ctx.hasUI) uiCtx = data.ctx;
		data.accept();

		void enqueue(() => renderPermissionDialog(data.ctx, data.subject, data.reason)).then(
			(answer) => {
				if (!answer) return data.resolve({ block: true, reason: "Blocked by user" });
				if (answer.value === "allow-save") data.ctx.ui.notify(data.saveRule(), "info");
				if (answer.message) pi.sendUserMessage(answer.message, { deliverAs: "steer" });
				if (answer.value === "allow" || answer.value === "allow-save")
					return data.resolve(undefined);
				return data.resolve({ block: true, reason: "Blocked by user" });
			},
			(error: unknown) =>
				data.resolve({
					block: true,
					reason: error instanceof Error ? error.message : "Permission prompt failed",
				}),
		);
	});
}
