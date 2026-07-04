// The decision engine: scores rules against a classified subject and produces
// the final allow/ask/deny outcome.

import { getProperty } from "dot-prop";
import type { Config, FieldMatcher, Rule } from "./config";
import { inside, resolvePath } from "./paths";
import {
	askReasons,
	flaggedCommands,
	hasGlobalFinding,
	type PermissionSubject,
} from "./types";

function matches(value: string | undefined, pattern?: string | string[]) {
	if (!value || !pattern) return !pattern;
	return (Array.isArray(pattern) ? pattern : [pattern]).some((entry) =>
		new RegExp(entry, "u").test(value),
	);
}

// Assume a leading `^` so raw patterns anchor to the start of each command.
function anchorStart(pattern?: string | string[]) {
	if (!pattern) return pattern;
	const anchor = (entry: string) => (entry.startsWith("^") ? entry : `^${entry}`);
	return Array.isArray(pattern) ? pattern.map(anchor) : anchor(pattern);
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

// How specifically a rule matches the subject; undefined = no match.
function ruleScore(rule: Rule, subject: PermissionSubject) {
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
	// match.raw is tested per sub-command so an anchored pattern like `kubectl`
	// matches `echo hi && kubectl get all` but not `echo "kubectl get all"`.
	// Non-bash tools (no parsed sub-commands) fall back to the raw input.
	// A leading `^` is assumed when absent so patterns anchor to the command start.
	const rawTargets = subject.commands.length > 0 ? subject.commands : [subject.rawInput];
	const rawPattern = anchorStart(rule.match?.raw);
	if (rawPattern && !rawTargets.some((cmd) => matches(cmd, rawPattern))) return undefined;
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

export function decide(subject: PermissionSubject, config: Config) {
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

	// An explicit allow rule is a deliberate user whitelist, so it can override the
	// classifier's conservative "ask" net (e.g. unrecognized commands like kubectl).
	// But the override is scoped: it must not silently allow unrelated flagged
	// sub-commands (e.g. a `python3 -c` escape riding alongside `kubectl get`) or
	// writes/reads outside the allowed roots. denyRoots/deny rules above still win.
	if (best?.rule.action === "allow") {
		const pathsOk =
			subject.paths.length === 0 ||
			subject.paths.every((entry) => config.allowRoots.some((root) => inside(entry.resolved, root)));

		// A raw-pattern allow only vouches for the sub-commands it textually matches.
		// If any flagged sub-command isn't covered, the ask net stands.
		const rawPattern = anchorStart(best.rule.match?.raw);
		const coversFlagged =
			!rawPattern ||
			flaggedCommands(subject).every((cmd) => matches(cmd, rawPattern));

		if (!hasGlobalFinding(subject) && coversFlagged && pathsOk)
			return { action: "allow" as const, reason: best.rule.comment ?? "Allowed by rule" };
	}
	if (subject.findings.length > 0)
		return { action: "ask" as const, reason: askReasons(subject).join("; ") };
	// A fell-through allow rule (failed the scoped-override checks above) must not
	// be honored here; only non-allow matched actions (ask) fall through.
	if (best && best.rule.action !== "allow")
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
