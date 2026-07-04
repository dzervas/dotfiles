// Static bash classifier: parses the command with tree-sitter and walks the
// tree, collecting sub-commands, touched paths, and findings. Per-command
// argument semantics live in handlers.ts.

import Parser from "tree-sitter";
import Bash from "tree-sitter-bash";
import { pushPath } from "../paths";
import type { Finding, PathRef, PermissionSubject, Verdict } from "../types";
import { HANDLERS, HANDLES_DYNAMIC_ARGS, READ, SIMPLE, WRITE } from "./handlers";

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

const parser = new Parser();
parser.setLanguage(Bash);

type WalkAcc = {
	findings: Finding[];
	paths: PathRef[];
	commands: string[];
};

// Asks raised outside a single command node (parse/complexity/construct/redirect)
// can never be vouched for by a match.raw allow rule, so mark them global.
function globalFinding(acc: WalkAcc, reason: string, verdict: Verdict = "unknown") {
	acc.findings.push({ scope: "global", verdict, reason });
}

// Resolve an argument node to its static text, or undefined when it's dynamic
// (substitution/expansion/variable). Nested command substitutions are walked in
// their own right; their findings are forwarded as global (a nested $(...)
// can't be vouched for by the outer rule's raw pattern).
function argText(node: any, acc: WalkAcc): string | undefined {
	const stack = [node];
	let dynamic = false;
	while (stack.length > 0) {
		const current = stack.pop();
		if (!current) continue;
		// A command/process substitution anywhere in the arg makes its value
		// unknowable, and runs nested commands we must classify in their own right.
		if (current.type === "command_substitution" || current.type === "process_substitution") {
			// Nested sub-commands are kept out of acc.commands so raw allow
			// patterns can't match (and thereby vouch for) them.
			const subAcc: WalkAcc = { findings: [], paths: acc.paths, commands: [] };
			walk(current, subAcc, 1);
			for (const finding of subAcc.findings)
				acc.findings.push({ ...finding, scope: "global" });
			dynamic = true;
			continue;
		}
		if (
			current.type.includes("expansion") ||
			current.type.includes("substitution") ||
			current.type.includes("variable")
		)
			dynamic = true;
		for (const child of current.namedChildren ?? []) stack.push(child);
	}
	if (dynamic) return undefined;
	const text = node.text;
	return text.length > 1 &&
		((text.startsWith("'") && text.endsWith("'")) || (text.startsWith(`"`) && text.endsWith(`"`)))
		? text.slice(1, -1)
		: text;
}

// Classify a single command node: resolve its name and args, then dispatch to
// the per-command handler table (or the SIMPLE/READ/WRITE sets).
function classifyCommand(node: any, acc: WalkAcc) {
	const ask = (reason: string, verdict: Verdict = "unknown") =>
		acc.findings.push({ scope: { command: node.text }, verdict, reason });

	const children = node.namedChildren ?? [];
	const nameNode = children.find((child: any) => child.type === "command_name");

	if (!nameNode) return ask("Unknown shell command");

	const name = nameNode.text;

	if (["eval", "source", "."].includes(name)) return ask(`${name} requires confirmation`, "unsafe");

	const args = children
		.filter(
			(child: any) =>
				child !== nameNode &&
				child.type !== "variable_assignment" &&
				!child.type.includes("redirect"),
		)
		.map((child: any) => argText(child, acc));

	if (SIMPLE.has(name)) return;

	// argText returns undefined for any argument we can't resolve statically.
	// Commands whose positionals are filesystem targets must confirm an
	// unknowable target rather than silently dropping it — otherwise
	// `rm -rf $(...)` slips through. HANDLES_DYNAMIC_ARGS handlers are excluded:
	// they inspect dynamic args per-position.
	const hasDynamicArg = args.some((arg: string | undefined) => arg === undefined);
	if (hasDynamicArg && !HANDLES_DYNAMIC_ARGS.has(name))
		return ask(`${name} has a dynamic argument`);

	const handler = HANDLERS[name];
	if (handler) return handler({ name, args, paths: acc.paths, ask });

	// Read/write commands are simple enough to handle directly.
	if (READ.has(name) || WRITE.has(name))
		return args
			.filter(Boolean)
			.filter((arg: string) => !arg.startsWith("-"))
			.forEach((arg: string) => pushPath(acc.paths, arg, READ.has(name) ? "read" : "write"));

	ask(`Unsupported shell command: ${name}`);
}

// Redirects are siblings of the command they apply to (under a
// `redirected_statement`), so they're classified during the walk rather than
// inside classifyCommand, which only sees the command node's own children.
function isFileDescriptorDuplication(redirectText: string, target: string) {
	// Bash fd duplication/closure redirects (`2>&1`, `>&2`, `<&0`, `2>&-`)
	// do not touch the filesystem. Do not skip `&> file` or `>& file`: those
	// redirect output to an actual path unless the target is fd-shaped.
	return /[<>]&/u.test(redirectText) && (/^\d+$/u.test(target) || target === "-");
}

function classifyRedirect(node: any, acc: WalkAcc) {
	if (node.text.includes("<<") || COMPLEX_TYPES.has(node.type))
		return globalFinding(acc, "Complex redirect");

	const target = argText(node.namedChildren?.at(-1), acc);

	if (!target) return globalFinding(acc, "Dynamic redirect");
	if (isFileDescriptorDuplication(node.text.trim(), target)) return;

	pushPath(acc.paths, target, /^\d*<(?!=|<)/u.test(node.text.trim()) ? "read" : "write");
}

function walk(node: any, acc: WalkAcc, depth: number, seen = { nodes: 0, commands: 0 }) {
	if (!node) return;

	seen.nodes += 1;

	if (depth > 8 || seen.nodes > 120 || seen.commands > 24)
		return globalFinding(acc, "Shell command is too complex to classify safely");

	if (COMPLEX_TYPES.has(node.type))
		return globalFinding(acc, `Unsupported shell construct: ${node.type}`);

	if (node.type === "command") {
		seen.commands += 1;
		acc.commands.push(node.text);
		classifyCommand(node, acc);
		return;
	}

	if (node.type.endsWith("_redirect")) {
		classifyRedirect(node, acc);
		return;
	}

	for (const child of node.namedChildren ?? []) walk(child, acc, depth + 1, seen);
}

// The static classifier: only applies to the builtin bash tool.
export function classifyBash(subject: PermissionSubject): Finding[] {
	if (subject.toolKind !== "builtin" || subject.toolName !== "bash") return [];

	const acc: WalkAcc = { findings: [], paths: subject.paths, commands: subject.commands };

	if (subject.rawInput.length > 4000) {
		globalFinding(acc, "Shell command is too long to classify safely");
		return acc.findings;
	}

	try {
		walk(parser.parse(subject.rawInput).rootNode, acc, 0);
	} catch {
		globalFinding(acc, "Shell command could not be parsed safely");
	}
	return acc.findings;
}
