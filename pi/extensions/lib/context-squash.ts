// Pure logic for context-squash.ts. No runtime imports from pi so node tests can load it;
// the token estimator is injected (the extension passes pi's own estimateTokens).
import type { SessionBoundaryDraft, SessionEntry } from "@earendil-works/pi-coding-agent";
import { getPrompt } from "./prompts.ts";

type AgentMessage = Extract<SessionEntry, { type: "message" }>["message"];

export const STATE_TYPE = "context-squash";
export const NUDGE_TYPE = "context-squash-nudge";
const SUGGEST_RATIO = 0.85;
const MAX_REMAINING_TOKENS = 65_000;
export const TARGET_RATIO = 0.5;

/** Trigger with at most 15% of the window or 65k tokens left, whichever is smaller. */
export function suggestionThreshold(contextWindow: number): number {
	return Math.max(contextWindow * SUGGEST_RATIO, contextWindow - MAX_REMAINING_TOKENS);
}
export const KEEP_ERROR_CHARS = 2000;
export const ARG_CHARS = 80;
const LOG_OPEN = "<tool-call-log>";
const LOG_CLOSE = "</tool-call-log>";

export type Estimate = (message: AgentMessage) => number;

type ContentBlock = { type: string; text?: string };
type ToolResult = {
	role: "toolResult";
	toolCallId: string;
	toolName: string;
	content: ContentBlock[];
	isError: boolean;
	nestedCalls?: { calls: { name: string; arguments?: unknown; argumentsBytes?: number; status: string }[] };
	details?: unknown;
};
type ToolCall = { type: "toolCall"; id: string; name: string; arguments?: unknown };

function messageOf(entry: SessionEntry): { role?: string; content?: unknown } | undefined {
	return entry.type === "message" ? (entry.message as { role?: string; content?: unknown }) : undefined;
}

function toolResultOf(entry: SessionEntry): ToolResult | undefined {
	const message = messageOf(entry);
	return message?.role === "toolResult" ? (message as unknown as ToolResult) : undefined;
}

function textOf(result: ToolResult): string {
	return result.content.filter((block) => block.type === "text").map((block) => block.text ?? "").join("\n");
}

function lineCount(text: string): number {
	const trimmed = text.replace(/\n+$/, "");
	return trimmed ? trimmed.split("\n").length : 0;
}

export function truncateArgs(args: unknown, max = ARG_CHARS): string {
	const json = typeof args === "string" ? args : (JSON.stringify(args ?? {}) ?? "");
	return json.length > max ? `${json.slice(0, max)}…` : json;
}

function outcome(result: ToolResult | undefined): string {
	if (!result) return "no result";
	const images = result.content.filter((block) => block.type === "image").length;
	const lines = `${result.isError ? "error" : "ok"}, ${lineCount(textOf(result))} lines`;
	return images ? `${lines}, ${images} images` : lines;
}

// Inner calls of tools that run other tools (codemode). `nestedCalls` is pi's record; older
// codemode results only carry `details.calls` with stringified args.
function nestedLines(result: ToolResult | undefined): string[] {
	if (!result) return [];
	if (result.nestedCalls?.calls.length) {
		return result.nestedCalls.calls.map((call) => {
			const args = call.arguments === undefined ? `<${call.argumentsBytes ?? "?"} bytes>` : truncateArgs(call.arguments);
			return `  - ${call.name}(${args}) → ${call.status}`;
		});
	}
	const legacy = (result.details as { calls?: { name?: string; args?: string; status?: string }[] } | undefined)?.calls;
	if (!Array.isArray(legacy)) return [];
	return legacy.map((call) => `  - ${call.name ?? "?"}(${truncateArgs(call.args ?? "")}) → ${call.status ?? "?"}`);
}

export function stubFor(result: ToolResult): string {
	return [getPrompt("context-squash", "output-stub", { toolName: result.toolName, outcome: outcome(result) }), ...nestedLines(result)].join(
		"\n",
	);
}

/** Index of the first branch entry that is still in model context (after the latest compaction's kept boundary). */
function contextStart(branch: SessionEntry[]): number {
	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry.type !== "compaction") continue;
		const kept = branch.findIndex((candidate) => candidate.id === entry.firstKeptEntryId);
		return kept >= 0 ? kept : i + 1;
	}
	return 0;
}

export interface SquashPlan {
	edits: SessionBoundaryDraft[];
	savedTokens: number;
}

/**
 * Squash every tool output still in context except short errors, results the model has not
 * seen yet (`unseen`, the current turn's results) and results already context-edited.
 */
export function planSquash(branch: SessionEntry[], unseen: ReadonlySet<string>, estimate: Estimate): SquashPlan {
	const edited = new Set(branch.flatMap((entry) => (entry.type === "context_edit" ? [entry.targetId] : [])));
	const edits: SessionBoundaryDraft[] = [];
	let savedTokens = 0;
	for (const entry of branch.slice(contextStart(branch))) {
		const result = toolResultOf(entry);
		if (!result || unseen.has(entry.id) || edited.has(entry.id)) continue;
		if (result.isError && textOf(result).length < KEEP_ERROR_CHARS) continue;
		const content = [{ type: "text" as const, text: stubFor(result) }];
		const saved = estimate(result as unknown as AgentMessage) - estimate({ ...result, content } as unknown as AgentMessage);
		if (saved <= 0) continue;
		savedTokens += saved;
		edits.push({ type: "context_edit", targetId: entry.id, replacement: { content } });
	}
	return { edits, savedTokens };
}

export interface SquashState {
	declined: boolean;
	nudged: boolean;
}

/** Derived from the branch so reloads and forks see the right state. */
export function readState(branch: SessionEntry[]): SquashState {
	let declined = false;
	let nudged = false;
	for (const entry of branch) {
		if (entry.type === "compaction") nudged = false;
		else if (entry.type === "custom" && entry.customType === STATE_TYPE) {
			const data = entry.data as { declined?: boolean; squashed?: number } | undefined;
			if (data?.declined) declined = true;
			if (data?.squashed !== undefined) nudged = false;
		} else if (entry.type === "custom_message" && entry.customType === NUDGE_TYPE) nudged = true;
	}
	return { declined, nudged };
}

/** Total budget for summary + tool log: pi's summary cap doubled, or a tenth of large windows. */
export function compactionBudget(reserveTokens: number, maxTokens: number, contextWindow: number): number {
	const summaryCap = Math.min(0.8 * reserveTokens * 2, maxTokens > 0 ? maxTokens : Number.POSITIVE_INFINITY);
	return Math.floor(Math.max(summaryCap, contextWindow / 10));
}

/**
 * One line per tool call made before `firstKeptEntryId` (later calls are still in context),
 * dropping the oldest lines first to fit `budgetTokens`. Empty when nothing fits.
 */
export function formatToolLog(branch: SessionEntry[], firstKeptEntryId: string, budgetTokens: number): string {
	const end = branch.findIndex((entry) => entry.id === firstKeptEntryId);
	const span = end >= 0 ? branch.slice(0, end) : branch;
	const results = new Map<string, ToolResult>();
	for (const entry of branch) {
		const result = toolResultOf(entry);
		if (result) results.set(result.toolCallId, result);
	}
	const lines: string[] = [];
	for (const entry of span) {
		const message = messageOf(entry);
		if (message?.role !== "assistant" || !Array.isArray(message.content)) continue;
		for (const block of message.content as ToolCall[]) {
			if (block.type !== "toolCall") continue;
			const result = results.get(block.id);
			lines.push([`- ${block.name}(${truncateArgs(block.arguments)}) → ${outcome(result)}`, ...nestedLines(result)].join("\n"));
		}
	}
	const header = getPrompt("context-squash", "tool-log-header");
	const tokens = (text: string) => Math.ceil(text.length / 4);
	// Fixed overhead plus room for the "… N earlier calls omitted" line.
	let used = tokens(`${LOG_OPEN}\n${header}\n${LOG_CLOSE}`) + 10;
	let first = lines.length;
	while (first > 0 && used + tokens(lines[first - 1]) + 1 <= budgetTokens) used += tokens(lines[--first]) + 1;
	if (first === lines.length) return "";
	const omitted = first > 0 ? [`… ${first} earlier calls omitted`] : [];
	return [LOG_OPEN, header, ...omitted, ...lines.slice(first), LOG_CLOSE].join("\n");
}

/** Remove a previous tool log so the summarizer never rewrites it; the extension appends a fresh one. */
export function stripToolLog(summary: string): string {
	const start = summary.indexOf(LOG_OPEN);
	const end = summary.indexOf(LOG_CLOSE);
	if (start < 0 || end < start) return summary;
	return (summary.slice(0, start) + summary.slice(end + LOG_CLOSE.length)).trim();
}
