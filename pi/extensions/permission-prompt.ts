import { withHumanInput } from "./lib/human-input.ts";
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
	type ToolDefinition,
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
	const definition = definitions[subject.toolName as keyof typeof definitions] as ToolDefinition<any, any, any> | undefined;
	if (!definition?.renderCall) return formatGenericCall(subject);
	try {
		const component = definition.renderCall(subject.input as any, ctx.ui.theme, {
			args: subject.input as any,
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

// Choose a syntax-highlighted body for shell commands and CodeMode scripts; everything else
// falls back to the renderCall/generic key-value dump as plain text.
function formatBody(
	subject: PermissionSubject,
	ctx: ExtensionContext,
): { body: string; language?: string } {
	if (subject.toolKind === "builtin" && subject.toolName === "bash")
		return { body: subject.rawInput, language: "bash" };

	const input = subject.input ?? {};

	if (subject.toolName === "codemode" && typeof input.code === "string")
		return { body: input.code, language: "javascript" };

	return { body: formatToolCall(subject, ctx) };
}

// Renders the permission dialog on the given (UI-bearing) session context and
// returns the raw decision. No side effects — callers apply rule saves and
// steer messages against the session that actually asked.
async function renderPermissionDialog(
	pi: ExtensionAPI,
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

	const title = label ? `󱅞 Permission request — ${label}` : "󱅞 Permission request";

	const result = await withHumanInput(pi, () => ctx.ui.custom<DialogueResult | null>((tui, theme, _kb, done) =>
		new ScrollableDialogue(
			tui,
			theme,
			{
				title,
				body,
				language,
				reason: `Reason: ${reason}`,
				options,
				messagePrompt: "Append message to agent:",
			},
			done,
		),
	));
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
let uiPi: ExtensionAPI | undefined;
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
	if (!uiCtx || !uiPi) return undefined;
	const ctx = uiCtx;
	const pi = uiPi;
	const answer = await enqueue(() => renderPermissionDialog(pi, ctx, subject, reason, "subagent"));
	return answer ?? undefined;
};

export default function permissionPromptExtension(pi: ExtensionAPI) {
	let registeredBroker = false;

	const registerBrokerIfUI = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		uiCtx = ctx;
		uiPi = pi;
		(globalThis as Record<PropertyKey, unknown>)[PERMISSIONS_ASK_BROKER_KEY] = broker;
		registeredBroker = true;
	};

	pi.on("session_start", async (_event, ctx) => registerBrokerIfUI(ctx));
	pi.on("session_tree", async (_event, ctx) => registerBrokerIfUI(ctx));

	pi.on("session_shutdown", async () => {
		if (!registeredBroker) return;
		const g = globalThis as Record<PropertyKey, unknown>;
		if (g[PERMISSIONS_ASK_BROKER_KEY] === broker) {
			delete g[PERMISSIONS_ASK_BROKER_KEY];
			uiCtx = undefined;
			uiPi = undefined;
		}
		registeredBroker = false;
	});

	pi.events.on(PERMISSIONS_ASK_EVENT, (data) => {
		if (!isPermissionAskRequest(data)) return;

		// A UI-bearing session asked directly; keep the broker ctx fresh too.
		if (data.ctx.hasUI) uiCtx = data.ctx;
		data.accept();

		void enqueue(() => renderPermissionDialog(pi, data.ctx, data.subject, data.reason)).then(
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
