import { compact, estimateTokens, type ExtensionAPI, type SessionBoundaryDraft } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { getPrompt } from "./lib/prompts.ts";
import {
	compactionBudget,
	formatToolLog,
	NUDGE_TYPE,
	planSquash,
	readState,
	STATE_TYPE,
	stripToolLog,
	suggestionThreshold,
	TARGET_RATIO,
} from "./lib/context-squash.ts";

// Context pressure helper:
// - With at most min(15% of the window, 65k tokens) left, nudges once per cycle.
// - Offers squashing only at the final pre-settlement boundary, after tools, retries
//   and queued continuations finish. Accepted edits need this actionable boundary;
//   agent_settled is notification-only. "No" is remembered for the session.
// - `compact` tool: deferred until the run settles, then pi compacts and the run resumes.
// - Every compaction gets a deterministic log of earlier tool calls appended to its summary.

const PROMPT_TIMEOUT_MS = 5 * 60_000;
const MIN_COMPACT_RATIO = 0.5;
const VIRTUAL_MODEL_API = "pi-virtual";

const percent = (ratio: number) => `${Math.round(ratio * 100)}%`;

export default function contextSquash(pi: ExtensionAPI): void {
	let pendingCompact: { note?: string } | undefined;
	let unseenToolResults = new Set<string>();
	const reset = () => {
		pendingCompact = undefined;
		unseenToolResults.clear();
	};
	const hideDirectCompact = () => {
		const active = pi.getActiveTools();
		if (active.includes("compact")) pi.setActiveTools(active.filter((name) => name !== "compact"));
	};
	pi.on("session_start", () => {
		reset();
		// Old session transcripts may restore compact's former direct declaration.
		hideDirectCompact();
	});
	pi.on("session_tree", hideDirectCompact);
	pi.on("session_shutdown", reset);

	pi.on("turn_end", (event, ctx) => {
		unseenToolResults = new Set(event.toolResultEntryIds);
		if (pendingCompact) return;
		const usage = ctx.getContextUsage();
		if (!usage?.tokens || !usage.contextWindow || usage.tokens < suggestionThreshold(usage.contextWindow)) return;
		if (readState(ctx.sessionManager.getBranch()).nudged) return;
		const entries: SessionBoundaryDraft[] = [{
			type: "custom_message",
			customType: NUDGE_TYPE,
			display: false,
			content: getPrompt("context-squash", "compaction-nudge", { usage: percent(usage.tokens / usage.contextWindow) }),
		}];
		return { entries };
	});

	pi.on("agent_before_settle", async (event, ctx) => {
		if (pendingCompact || !ctx.hasUI || event.outcome !== "completed" || event.continue || ctx.hasPendingMessages()) return;
		const usage = ctx.getContextUsage();
		if (!usage?.tokens || !usage.contextWindow || usage.tokens < suggestionThreshold(usage.contextWindow)) return;
		const branch = ctx.sessionManager.getBranch();
		if (readState(branch).declined) return;
		const plan = planSquash(branch, unseenToolResults, estimateTokens);
		const projected = (usage.tokens - plan.savedTokens) / usage.contextWindow;
		if (plan.edits.length === 0 || projected >= TARGET_RATIO) return;
		const signal = ctx.signal;
		if (signal?.aborted) return;
		const leafId = ctx.sessionManager.getLeafId();
		const choice = await ctx.ui.select(
			`Context at ${percent(usage.tokens / usage.contextWindow)}. Squash ${plan.edits.length} old tool outputs (→ ~${percent(projected)})?`,
			["Not yet", "Yes", "No"],
			{ timeout: PROMPT_TIMEOUT_MS, signal },
		);
		// User input or session navigation while the dialog was open invalidates
		// the idle offer; don't apply a stale plan or delay their queued work.
		if (signal?.aborted || ctx.hasPendingMessages() || ctx.sessionManager.getLeafId() !== leafId) return;
		if (choice === "Yes") {
			return {
				entries: [...plan.edits, { type: "custom", customType: STATE_TYPE, data: { squashed: plan.edits.length } }],
			};
		}
		if (choice === "No") return { entries: [{ type: "custom", customType: STATE_TYPE, data: { declined: true } }] };
	});

	pi.registerTool({
		name: "compact",
		label: "Compact",
		exposure: "codemode",
		description: getPrompt("context-squash", "tool-description"),
		parameters: Type.Object({
			note: Type.Optional(Type.String({ description: getPrompt("context-squash", "note-description") })),
		}),
		async execute(_toolCallId, { note }, _signal, _onUpdate, ctx) {
			const usage = ctx.getContextUsage();
			if (!usage?.tokens || !usage.contextWindow) throw new Error("Context usage is unknown; nothing to compact yet.");
			const ratio = usage.tokens / usage.contextWindow;
			if (ratio < MIN_COMPACT_RATIO) {
				throw new Error(getPrompt("context-squash", "compaction-refused", { usage: percent(ratio) }));
			}
			pendingCompact = { note: note?.trim() || undefined };
			return {
				content: [{ type: "text", text: "Compaction scheduled; the run resumes after it." }],
				details: undefined,
				terminate: true,
			};
		},
	});

	// ctx.compact() aborts the active run, so wait until the run has settled (like the clear tool),
	// then resume with a hidden message since pi never continues after a manual compaction.
	pi.on("agent_settled", (_event, ctx) => {
		if (!pendingCompact) return;
		const { note } = pendingCompact;
		pendingCompact = undefined;
		ctx.compact({
			customInstructions: note,
			onComplete: () =>
				pi.sendMessage(
					{
						customType: "context-squash-resume",
						display: false,
						content: getPrompt("context-squash", "compaction-resume"),
					},
					{ triggerTurn: true },
				),
			onError: (error) => ctx.ui.notify(`Compaction failed: ${error.message}`, "error"),
		});
	});

	pi.on("session_before_compact", async (event, ctx) => {
		const model = ctx.model;
		if (!model || model.api === VIRTUAL_MODEL_API) return;
		const { preparation, branchEntries, customInstructions, signal } = event;
		try {
			const result = await compact(
				{ ...preparation, previousSummary: preparation.previousSummary && stripToolLog(preparation.previousSummary) },
				model,
				undefined,
				undefined,
				customInstructions,
				signal,
				pi.getThinkingLevel(),
				(requestModel, context, options) => ctx.modelRegistry.streamSimple(requestModel, context, options),
			);
			const budget =
				compactionBudget(preparation.settings.reserveTokens, model.maxTokens, model.contextWindow) -
				Math.ceil(result.summary.length / 4);
			const log = formatToolLog(branchEntries, preparation.firstKeptEntryId, budget);
			return { compaction: log ? { ...result, summary: `${result.summary}\n\n${log}` } : result };
		} catch (error) {
			if (signal.aborted) return { cancel: true };
			ctx.ui.notify(`Tool-log compaction failed, using pi's default: ${(error as Error).message}`, "warning");
			return;
		}
	});
}
