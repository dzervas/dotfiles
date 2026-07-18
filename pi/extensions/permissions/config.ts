// Config schema, loading/merging from disk, defaults, and rule persistence.

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { z } from "zod";
import { CWD, inside, resolvePath, savePathRoot } from "./paths";
import type { Action, PermissionSubject, ToolKind } from "./types";

export const CONFIG_PATHS = [
	path.join(os.homedir(), ".pi", "permissions.json"),
	path.join(process.cwd(), ".pi", "permissions.json"),
	path.join(process.cwd(), ".agent-permissions.json"),
];

export type Rule = {
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
export type Config = {
	version: 2;
	defaultAction: Action;
	allowRoots: string[];
	denyRoots: string[];
	rules: Rule[];
};
export type FieldMatcher = string | string[] | { equals?: unknown; regex?: string | string[] };

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
	allowRoots: z.array(z.string()).default([resolvePath("."), "/nix/store", "/dev/null"]),
	denyRoots: z.array(z.string()).default([]),
	rules: z.array(RuleSchema).default([]),
});

// Web search and fetch are read-only network lookups that should never block.
const DEFAULT_RULES: Rule[] = [
	{
		action: "allow",
		comment: "Web search/fetch are always allowed",
		tool: {
			kind: "custom",
			name: [
				"^questionnaire$",
				"^subagent$",
				"^get_subagent_result$",
				"^todo$",

				"^web_search$",
				"^web_read$",
				"^fetch_content$",
				"^get_search_content$",

				"^workflow$",
			],
		},
	},
	{
		action: "allow",
		tool: {
			kind: "builtin",
			name: "^bash$"
		},
		match: {
			raw: [
				"(jj|git) (diff|status|log)",
				"cd \"$(pwd)\"",
			]
		}
	}
];

// Accepts both the current v2 shape and the legacy array-of-rules shape.
export function coerceConfig(parsed: unknown): Config {
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

function readConfigFile(file: string): unknown {
	const raw = fs.readFileSync(file, "utf8");
	try {
		return JSON.parse(raw);
	} catch (err) {
		const reason = err instanceof Error ? err.message : String(err);
		throw new Error(
			`Invalid permissions config: ${file} is not valid JSON (${reason}). ` +
				`Fix the syntax (e.g. a trailing comma or missing quote) or delete the file to reset.`,
		);
	}
}

export function loadConfig(): Config {
	let config: Config = {
		version: 2,
		defaultAction: "ask",
		allowRoots: ["/nix/store", "/dev/null"],
		denyRoots: [],
		rules: [...DEFAULT_RULES],
	};
	for (const file of CONFIG_PATHS) {
		if (!fs.existsSync(file)) continue;
		const next = coerceConfig(readConfigFile(file));
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

function escape(text: string) {
	return text.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
}

function toolSelector(subject: PermissionSubject) {
	return subject.toolKind === "mcp"
		? {
				kind: "mcp" as const,
				server: `^${escape(subject.mcpServer ?? "")}$`,
				name: `^${escape(subject.mcpTool ?? subject.toolName)}$`,
			}
		: { kind: subject.toolKind, name: `^${escape(subject.toolName)}$` };
}

// Persist a user-approved subject: paths outside CWD become allowed roots,
// everything else becomes an exact-match allow rule.
export function saveRule(subject: PermissionSubject) {
	const source = fs.existsSync(CONFIG_PATHS[1]) ? CONFIG_PATHS[1] : CONFIG_PATHS[2];
	const parsed = fs.existsSync(source) ? readConfigFile(source) : undefined;
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
