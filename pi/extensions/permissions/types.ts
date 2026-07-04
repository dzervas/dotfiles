// The shared vocabulary of the permissions extension.
//
// Data flow: a tool_call event is normalized into a PermissionSubject
// (subject.ts), classifiers append Findings to it (classify/), and the
// decision engine turns findings + rules into allow/ask/deny (decide.ts).

export type Action = "allow" | "ask" | "deny";
export type LlmClassifierAdvice = {
	action: Action;
	confidence: number;
	reason: string;
	model: string;
	baseUrl?: string;
};
export type ToolKind = "builtin" | "custom" | "mcp";
export type PathRef = { access: "read" | "write" | "search" | "list"; raw: string; resolved: string };

// "unknown": we simply couldn't classify it — a future safety model may vouch for it.
// "unsafe": statically identified as dangerous — must never be auto-vouched.
export type Verdict = "unsafe" | "unknown";

// A single classifier observation that would cause an ask.
// - scope "global": not tied to one sub-command (parse failure, complexity limit,
//   unsupported construct, problematic redirect, nested $(...)). Global findings
//   can never be overridden by an allow rule.
// - scope { command }: tied to that exact sub-command text. A match.raw allow
//   rule that textually covers the command may override it (see decide.ts).
export type Finding = {
	scope: "global" | { command: string };
	verdict: Verdict;
	reason: string;
};

export type PermissionSubject = {
	toolName: string;
	toolKind: ToolKind;
	mcpServer?: string;
	mcpTool?: string;
	rawInput: string;
	input: Record<string, unknown>;
	paths: PathRef[];
	// Parsed sub-commands (bash only); match.raw rules are tested per sub-command.
	commands: string[];
	findings: Finding[];
	// Advisory-only local LLM output. The decision engine intentionally ignores it
	// until the classifier earns trust.
	llmAdvice?: LlmClassifierAdvice;
};

// A classifier inspects the subject and reports findings. It may also enrich
// subject.paths / subject.commands (the bash classifier does). Classifiers run
// as a pipeline — see classify/index.ts for where a safety model would slot in.
export type Classifier = (subject: PermissionSubject) => Finding[] | Promise<Finding[]>;

export function askReasons(subject: PermissionSubject) {
	return [...new Set(subject.findings.map((finding) => finding.reason))];
}

export function hasGlobalFinding(subject: PermissionSubject) {
	return subject.findings.some((finding) => finding.scope === "global");
}

// Sub-commands that produced a finding. A match.raw allow rule only overrides
// the ask-net for the sub-commands it actually covers.
export function flaggedCommands(subject: PermissionSubject) {
	return subject.findings.flatMap((finding) =>
		finding.scope === "global" ? [] : [finding.scope.command],
	);
}
