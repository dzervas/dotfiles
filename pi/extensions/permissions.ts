import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import {
	bashToolDefinition,
	editToolDefinition,
	findToolDefinition,
	grepToolDefinition,
	isToolCallEventType,
	lsToolDefinition,
	readToolDefinition,
	type ExtensionAPI,
	type ExtensionContext,
	type ToolCallEvent,
	writeToolDefinition,
} from "@mariozechner/pi-coding-agent";
import { z } from "zod";
import { getProperty } from "dot-prop";
import Parser from "tree-sitter";
import Bash from "tree-sitter-bash";

const CWD = resolvePath(process.cwd());
const CONFIG_PATHS = [
	path.join(os.homedir(), ".pi", "permissions.json"),
	path.join(process.cwd(), ".pi", "permissions.json"),
	path.join(process.cwd(), ".agent-permissions.json"),
];
const COMPLEX_TYPES = new Set([
	"arithmetic_expansion",
	"brace_expression",
	"for_statement",
	"function_definition",
	"herestring_redirect",
	"if_statement",
	"process_substitution",
	"while_statement",
]);
const SIMPLE = new Set(["pwd", "echo", "printf", "true", "false"]);
const READ = new Set(["cat", "head", "tail", "less", "file", "sort", "jq", "ls", "xxd", "nl"]);
const WRITE = new Set(["touch", "mkdir", "rm", "sed"]);

type Action = "allow" | "ask" | "deny";
type ToolKind = "builtin" | "custom" | "mcp";
type PathRef = { access: "read" | "write" | "search" | "list"; raw: string; resolved: string };
type Subject = {
	toolName: string;
	toolKind: ToolKind;
	mcpServer?: string;
	mcpTool?: string;
	rawInput: string;
	input: Record<string, unknown>;
	paths: PathRef[];
	ask: string[];
};
type Rule = {
	action: Action;
	priority?: number;
	comment?: string;
	tool?: { kind?: ToolKind; name?: string | string[]; server?: string | string[] };
	match?: {
		raw?: string | string[];
		fields?: Record<string, string | string[] | { equals?: unknown; regex?: string | string[] }>;
	};
	paths?: { allowRoots?: string[]; denyRoots?: string[] };
};
type Config = {
	version: 2;
	defaultAction: Action;
	allowRoots: string[];
	denyRoots: string[];
	rules: Rule[];
};
type FieldMatcher = string | string[] | { equals?: unknown; regex?: string | string[] };

const Regexes = z.union([z.string(), z.array(z.string())]);
const RuleSchema = z.object({
	action: z.enum(["allow", "ask", "deny"]),
	priority: z.number().optional(),
	comment: z.string().optional(),
	tool: z
		.object({
			kind: z.enum(["builtin", "custom", "mcp"]).optional(),
			name: Regexes.optional(),
			server: Regexes.optional(),
		})
		.optional(),
	match: z
		.object({
			raw: Regexes.optional(),
			fields: z
				.record(
					z.union([Regexes, z.object({ equals: z.any().optional(), regex: Regexes.optional() })]),
				)
				.optional(),
		})
		.optional(),
	paths: z
		.object({
			allowRoots: z.array(z.string()).optional(),
			denyRoots: z.array(z.string()).optional(),
		})
		.optional(),
});
const ConfigSchema = z.object({
	version: z.literal(2).default(2),
	defaultAction: z.enum(["allow", "ask", "deny"]).default("ask"),
	allowRoots: z.array(z.string()).default([resolvePath("."), "/nix/store"]),
	denyRoots: z.array(z.string()).default([]),
	rules: z.array(RuleSchema).default([]),
});

const parser = new Parser();
parser.setLanguage(Bash);

function resolvePath(target: string) {
	const expanded =
		target === "~"
			? os.homedir()
			: target.startsWith("~/")
				? path.join(os.homedir(), target.slice(2))
				: target;
	const absolute = path.isAbsolute(expanded) ? expanded : path.resolve(process.cwd(), expanded);
	try {
		return fs.realpathSync.native(path.normalize(absolute));
	} catch {
		return path.normalize(absolute);
	}
}

function inside(target: string, root: string) {
	const relative = path.relative(root, target);
	return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function matches(value: string | undefined, pattern?: string | string[]) {
	if (!value || !pattern) return !pattern;
	return (Array.isArray(pattern) ? pattern : [pattern]).some((entry) =>
		new RegExp(entry, "u").test(value),
	);
}

function coerceConfig(parsed: unknown): Config {
	return Array.isArray(parsed)
		? {
				version: 2,
				defaultAction: "ask",
				allowRoots: [],
				denyRoots: [],
				rules: parsed.flatMap(
					(entry: { tool?: string; action?: Action; patterns?: string[]; comment?: string }) =>
						(entry.patterns ?? []).map((regex) => ({
							action: entry.action ?? "ask",
							comment: entry.comment,
							tool: { name: entry.tool ?? ".*" },
							match: { raw: regex },
						})),
				),
			}
		: ConfigSchema.parse(parsed);
}

function loadConfig(): Config {
	let config: Config = {
		version: 2,
		defaultAction: "ask",
		allowRoots: [],
		denyRoots: [],
		rules: [],
	};
	for (const file of CONFIG_PATHS) {
		if (!fs.existsSync(file)) continue;
		const next = coerceConfig(JSON.parse(fs.readFileSync(file, "utf8")));
		config = {
			...config,
			...next,
			allowRoots: [...config.allowRoots, ...next.allowRoots],
			denyRoots: [...config.denyRoots, ...next.denyRoots],
			rules: [...config.rules, ...next.rules],
		};
	}
	config.allowRoots = [...new Set([CWD, ...config.allowRoots.map(resolvePath)])];
	config.denyRoots = [...new Set(config.denyRoots.map(resolvePath))];
	return config;
}

function argText(node: any, ask: string[], paths: PathRef[]): string | undefined {
	const stack = [node];
	let dynamic = false;
	while (stack.length > 0) {
		const current = stack.pop();
		for (const child of current?.namedChildren ?? []) {
			if (child.type === "command_substitution") walk(child, ask, paths, 1);
			if (
				child.type.includes("expansion") ||
				child.type.includes("substitution") ||
				child.type.includes("variable")
			)
				dynamic = true;
			stack.push(child);
		}
	}
	if (dynamic) return undefined;
	const text = node.text;
	return text.length > 1 &&
		((text.startsWith("'") && text.endsWith("'")) || (text.startsWith(`"`) && text.endsWith(`"`)))
		? text.slice(1, -1)
		: text;
}

function pushPath(paths: PathRef[], raw: string, access: PathRef["access"]) {
	paths.push({ raw, access, resolved: resolvePath(raw) });
}

// Walk the provided tree-sitter node to understand the command and its arguments
function classifyCommand(node: any, ask: string[], paths: PathRef[]) {
	const children = node.namedChildren ?? [];
	const nameNode = children.find((child: any) => child.type === "command_name");

	if (!nameNode) return ask.push("Unknown shell command");

	const name = nameNode.text;

	if (["eval", "source", "."].includes(name)) return ask.push(`${name} requires confirmation`);

	const args = children
		.filter(
			(child: any) =>
				child !== nameNode &&
				child.type !== "variable_assignment" &&
				!child.type.includes("redirect"),
		)
		.map((child: any) => argText(child, ask, paths));

	for (const redirect of children.filter((child: any) => child.type.includes("redirect"))) {
		if (redirect.text.includes("<<") || COMPLEX_TYPES.has(redirect.type))
			return ask.push(`Complex redirect in ${name}`);

		const target = argText(redirect.namedChildren?.at(-1), ask, paths);

		if (!target) return ask.push(`Dynamic redirect in ${name}`);

		pushPath(paths, target, /^\d*<(?!=|<)/u.test(redirect.text.trim()) ? "read" : "write");
	}

	// Simple commands don't need further analysis
	if (SIMPLE.has(name)) return;

	// ls without positionals still affects the current directory as read op
	if (name === "ls") {
		const positionals = args.filter(Boolean).filter((arg) => !arg!.startsWith("-")) as string[];
		positionals.forEach((arg) => pushPath(paths, arg, "list"));

		if (positionals.length === 0) pushPath(paths, ".", "list");
	}

	// Read/write commands are simple enough to handle directly
	if (READ.has(name) || WRITE.has(name))
		return args
			.filter(Boolean)
			.filter((arg) => !arg!.startsWith("-"))
			.forEach((arg) => pushPath(paths, arg!, READ.has(name) ? "read" : "write"));

	if (name === "cp" || name === "mv") {
		const positional = args.filter(Boolean).filter((arg) => !arg!.startsWith("-")) as string[];

		if (positional.length < 2) return ask.push(`${name} needs source and destination`);

		positional.slice(0, -1).forEach((arg) => pushPath(paths, arg, "read"));
		return pushPath(paths, positional.at(-1)!, "write");
	}

	if (name === "find") {
		const tokens = args.filter(Boolean) as string[];
		const roots: string[] = [];
		let parsingRoots = true;

		for (let index = 0; index < tokens.length; index += 1) {
			const arg = tokens[index]!;

			if ((arg === "-exec" || arg === "-execdir") && index + 1 < tokens.length) {
				const terminatorIndex = tokens.findIndex(
					(token, tokenIndex) =>
						tokenIndex > index && (token === ";" || token === "\\;" || token === "+"),
				);
				const execArgs = tokens.slice(
					index + 1,
					terminatorIndex === -1 ? tokens.length : terminatorIndex,
				);
				const execName = execArgs[0];
				if (!execName) return void ask.push(`Incomplete ${arg} in find`);
				if (WRITE.has(execName) || execName === "cp" || execName === "mv")
					return void ask.push(`find ${arg} runs ${execName}`);
				ask.push(`find ${arg} requires confirmation`);
				return;
			}

			if (parsingRoots) {
				if (arg.startsWith("-") || ["!", "(", ")"].includes(arg)) parsingRoots = false;
				else roots.push(arg);
			}
		}

		(roots.length > 0 ? roots : ["."]).forEach((arg) => pushPath(paths, arg, "search"));
		return;
	}
	if (name === "rg" || name === "grep") {
		let positional = 0;
		for (let index = 0; index < args.length; index += 1) {
			const arg = args[index];
			if (!arg) return void ask.push(`Dynamic ${name} argument`);
			if (arg === "-f" || arg === "--file") {
				if (!args[index + 1]) return void ask.push(`Dynamic ${name} pattern file`);
				pushPath(paths, args[index + 1]!, "read");
				index += 1;
				continue;
			}
			if (["-e", "--regexp", "-g", "--glob"].includes(arg)) {
				index += 1;
				continue;
			}
			if (arg.startsWith("--pre")) return void ask.push(`${name} --pre requires confirmation`);
			if (arg.startsWith("-")) continue;
			if (positional > 0) pushPath(paths, arg, "search");
			positional += 1;
		}
		return;
	}
	ask.push(`Unsupported shell command: ${name}`);
}

// === Event normalization ===

function walk(
	node: any,
	ask: string[],
	paths: PathRef[],
	depth: number,
	seen = { nodes: 0, commands: 0 },
) {
	if (!node) return;

	seen.nodes += 1;

	if (depth > 8 || seen.nodes > 120 || seen.commands > 24)
		return ask.push("Shell command is too complex to classify safely");

	if (COMPLEX_TYPES.has(node.type)) return ask.push(`Unsupported shell construct: ${node.type}`);

	if (node.type === "command") {
		seen.commands += 1;
		return classifyCommand(node, ask, paths);
	}

	for (const child of node.namedChildren ?? []) walk(child, ask, paths, depth + 1, seen);
}

function parseMcp(toolName: string) {
	const parts = toolName.split("__");
	if (parts[0] !== "mcp") return undefined;
	return { server: parts[1], tool: parts[2] };
}

// Extract any meaningful info from the event to create a subject
// That could mean a list of commands (after breaking down mutliple piped commands), affected paths, etc.
function normalize(event: ToolCallEvent): Subject {
	const mcp = parseMcp(event.toolName);
	let toolKind: ToolKind = "custom";

	// TODO: Access these procedurally
	switch (event.toolName) {
		case "bash":
		case "read":
		case "edit":
		case "write":
		case "grep":
		case "find":
		case "ls":
			toolKind = "builtin";
			break;
		default:
			toolKind = mcp ? "mcp" : "custom";
			break;
	}

	const subject: Subject = {
		toolName: event.toolName,
		toolKind,
		mcpServer: mcp?.server,
		mcpTool: mcp?.tool,
		rawInput: isToolCallEventType("bash", event)
			? event.input.command
			: JSON.stringify(event.input),
		input: event.input,
		paths: [],
		ask: [],
	};

	if (isToolCallEventType("bash", event)) {
		if (event.input.command.length > 4000)
			subject.ask.push("Shell command is too long to classify safely");
		else {
			try {
				walk(parser.parse(event.input.command).rootNode, subject.ask, subject.paths, 0);
			} catch {
				subject.ask.push("Shell command could not be parsed safely");
			}
		}
	} else if (isToolCallEventType("read", event)) pushPath(subject.paths, event.input.path, "read");
	else if (isToolCallEventType("edit", event) || isToolCallEventType("write", event))
		pushPath(subject.paths, event.input.path, "write");
	else if (isToolCallEventType("grep", event) || isToolCallEventType("find", event))
		pushPath(
			subject.paths,
			typeof event.input.path === "string" ? event.input.path : ".",
			"search",
		);
	else if (isToolCallEventType("ls", event))
		pushPath(subject.paths, typeof event.input.path === "string" ? event.input.path : ".", "list");

	return subject;
}

function fieldMatches(value: unknown, matcher: FieldMatcher) {
	if (typeof matcher === "string" || Array.isArray(matcher))
		return matches(typeof value === "string" ? value : JSON.stringify(value), matcher);
	if (matcher.equals !== undefined && JSON.stringify(value) !== JSON.stringify(matcher.equals))
		return false;
	return (
		matcher.regex === undefined ||
		matches(typeof value === "string" ? value : JSON.stringify(value), matcher.regex)
	);
}

function ruleScore(rule: Rule, subject: Subject) {
	let score = 0;
	if (rule.tool?.kind && rule.tool.kind !== subject.toolKind) return undefined;
	if (rule.tool?.kind) score += 4;
	if (
		rule.tool?.name &&
		!matches(
			subject.toolKind === "mcp" ? (subject.mcpTool ?? subject.toolName) : subject.toolName,
			rule.tool.name,
		)
	)
		return undefined;
	if (rule.tool?.name) score += 8;
	if (rule.tool?.server && !matches(subject.mcpServer, rule.tool.server)) return undefined;
	if (rule.tool?.server) score += 8;
	if (rule.match?.raw && !matches(subject.rawInput, rule.match.raw)) return undefined;
	if (rule.match?.raw) score += 3;
	for (const [key, matcher] of Object.entries(rule.match?.fields ?? {})) {
		if (!fieldMatches(getProperty(subject.input, key), matcher)) return undefined;
		score += 2;
	}
	const allowRoots = (rule.paths?.allowRoots ?? []).map(resolvePath);
	const denyRoots = (rule.paths?.denyRoots ?? []).map(resolvePath);
	if (
		denyRoots.length > 0 &&
		subject.paths.some((entry) => denyRoots.some((root) => inside(entry.resolved, root)))
	)
		return undefined;
	if (
		allowRoots.length > 0 &&
		!subject.paths.every((entry) => allowRoots.some((root) => inside(entry.resolved, root)))
	)
		return undefined;
	if (allowRoots.length + denyRoots.length > 0) score += 6;
	return score;
}

function decide(subject: Subject, config: Config) {
	if (subject.paths.some((entry) => config.denyRoots.some((root) => inside(entry.resolved, root))))
		return { action: "deny" as const, reason: "Path is inside a denied root" };

	const best = config.rules
		.map((rule, index) => ({ rule, index, score: ruleScore(rule, subject) }))
		.filter((entry) => entry.score !== undefined)
		.sort(
			(left, right) =>
				right.score! - left.score! ||
				(right.rule.priority ?? 0) - (left.rule.priority ?? 0) ||
				{ deny: 3, ask: 2, allow: 1 }[right.rule.action] -
					{ deny: 3, ask: 2, allow: 1 }[left.rule.action] ||
				left.index - right.index,
		)[0];
	if (best?.rule.action === "deny")
		return { action: "deny" as const, reason: best.rule.comment ?? "Denied by rule" };
	if (subject.ask.length > 0)
		return { action: "ask" as const, reason: [...new Set(subject.ask)].join("; ") };
	if (best)
		return {
			action: best.rule.action,
			reason: best.rule.comment ?? `${best.rule.action}ed by rule`,
		};
	if (
		subject.paths.length > 0 &&
		subject.paths.every((entry) => config.allowRoots.some((root) => inside(entry.resolved, root)))
	)
		return { action: "allow" as const, reason: "All paths are inside allowed roots" };
	return { action: config.defaultAction, reason: "Default policy" };
}

function toolSelector(subject: Subject) {
	return subject.toolKind === "mcp"
		? {
				kind: "mcp" as const,
				server: `^${escape(subject.mcpServer ?? "")}$`,
				name: `^${escape(subject.mcpTool ?? subject.toolName)}$`,
			}
		: { kind: subject.toolKind, name: `^${escape(subject.toolName)}$` };
}

function savePathRoot(resolved: string) {
	try {
		return fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);
	} catch {
		return path.dirname(resolved);
	}
}

function escape(text: string) {
	return text.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
}

function saveRule(subject: Subject) {
	const source = fs.existsSync(CONFIG_PATHS[1]) ? CONFIG_PATHS[1] : CONFIG_PATHS[2];
	const parsed = fs.existsSync(source) ? JSON.parse(fs.readFileSync(source, "utf8")) : undefined;
	const local = !parsed
		? { version: 2, defaultAction: "ask" as Action, allowRoots: [], denyRoots: [], rules: [] }
		: coerceConfig(parsed);
	const roots = [
		...new Set(
			subject.paths
				.map((entry) => savePathRoot(entry.resolved))
				.filter((root) => !inside(root, CWD)),
		),
	];
	if (roots.length > 0) local.allowRoots.push(...roots);
	else
		local.rules.push({
			action: "allow",
			tool: toolSelector(subject),
			match: { raw: `^${escape(subject.rawInput)}$` },
		});
	fs.mkdirSync(path.dirname(CONFIG_PATHS[1]), { recursive: true });
	fs.writeFileSync(
		CONFIG_PATHS[1],
		`${JSON.stringify({ ...local, allowRoots: [...new Set(local.allowRoots.map(resolvePath))] }, null, 2)}\n`,
	);
	return roots.length > 0
		? `Saved ${roots.length} allowed root${roots.length === 1 ? "" : "s"}`
		: "Saved allow rule";
}

const TOOL_DEFINITIONS = {
	bash: bashToolDefinition,
	read: readToolDefinition,
	edit: editToolDefinition,
	write: writeToolDefinition,
	grep: grepToolDefinition,
	find: findToolDefinition,
	ls: lsToolDefinition,
} as const;

function stripAnsi(text: string) {
	return text.replace(/\u001b\[[0-?]*[ -/]*[@-~]|\u001b[@-Z\\-_]/gu, "");
}

function formatToolCall(subject: Subject, ctx: ExtensionContext) {
	const definition = TOOL_DEFINITIONS[subject.toolName as keyof typeof TOOL_DEFINITIONS];
	if (!definition?.renderCall)
		return `${subject.toolName} ${JSON.stringify(subject.input, null, 2)}`;
	try {
		const component = definition.renderCall(subject.input, ctx.ui.theme, {
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
		return component.render(1000).join("\n").trim();
	} catch {
		return `${subject.toolName} ${JSON.stringify(subject.input, null, 2)}`;
	}
}

async function confirm(subject: Subject, reason: string, ctx: ExtensionContext) {
	if (!ctx.hasUI) return { block: true, reason: `${reason} (no UI available)` };

	const options =
		subject.ask.length > 0 ? ["Allow once", "No"] : ["Allow once", "Allow and save", "No"];
	const choice = await ctx.ui.select(
		`󱅞 Permission request:\n${formatToolCall(subject, ctx)}\n\nReason: ${reason}`,
		options,
	);

	if (choice === "Allow once") return undefined;

	if (choice === "Allow and save") {
		ctx.ui.notify(saveRule(subject), "info");
		return undefined;
	}

	return { block: true, reason: "Blocked by user" };
}

export default function permissionsExtension(pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const failures = runSelfTest();
		if (failures.length === 0) ctx.ui.notify("[permissions] self-test passed", "info");
		else {
			ctx.ui.notify(`[permissions] self-test failed (${failures.length})`, "error");
			ctx.ui.setWidget(
				"permissions-self-test",
				failures.map((failure) => `- ${failure}`),
			);
		}
	});

	pi.on("tool_call", async (event, ctx) => {
		const subject = normalize(event);
		const result = decide(subject, loadConfig());
		if (result.action === "allow") return { block: false, reason: result.reason };
		if (result.action === "deny") return { block: true, reason: result.reason };
		return confirm(subject, result.reason, ctx);
	});
}

type SelfTestAction = z.infer<typeof RuleSchema>["action"];

function runSelfTest(): string[] {
	const tests: Record<string, SelfTestAction> = {
		"ls -lah /tmp/allow": "allow",
		"ls -lah": "allow",
		"rm -rf /tmp/deny": "deny",
		"python script.py": "ask",
		"rg 'hello world' ./file.txt": "allow",
		"rg 'hello world' ../file.txt": "ask",
		"rg 'hello world' /tmp/deny/file.txt": "deny",
		"find . -name '*.txt' -print": "allow",
		"find . -name '*.txt' -exec rm {} \\;": "ask",
		"kubectl get all": "ask",
		"find . -name '*.txt' -print | sed 's#^./##'": "allow",
		"sed -i 's/old/new/g' file.txt": "allow",
		"sed -i 's/old/new/g' /tmp/deny": "deny",
	};

	const allowPath = resolvePath("/tmp/allow");
	const denyPath = resolvePath("/tmp/deny");
	const config: Config = {
		version: 2,
		defaultAction: "ask",
		allowRoots: [resolvePath("."), allowPath],
		denyRoots: [denyPath],
		rules: [],
	};

	const failures: string[] = [];

	for (const [command, expected] of Object.entries(tests)) {
		const subject = normalize({
			type: "tool_call",
			toolCallId: `self-test:${command}`,
			toolName: "bash",
			input: { command },
		} as ToolCallEvent);
		const actual = decide(subject, config);

		if (actual.action !== expected)
			failures.push(
				`'${command}' expected=${expected} vs actual=${actual.action} reason=${actual.reason}`,
			);
	}

	return failures;
}
