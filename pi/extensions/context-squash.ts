import { compact, estimateTokens, type ExtensionAPI, type SessionBoundaryDraft } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import {
	compactionBudget,
	formatToolLog,
	NUDGE_TYPE,
	planSquash,
	readState,
	STATE_TYPE,
	stripToolLog,
	SUGGEST_RATIO,
	TARGET_RATIO,
} from "./lib/context-squash.ts";

// Context pressure helper:
// - Above 85% usage, offers to squash old tool outputs (context_edit stubs, raw history stays on
//   disk) when that would bring the context under 50%. "No" is remembered for the session.
// - Above 85%, nudges the model once per cycle to call `compact` at its next natural gap.
// - `compact` tool: deferred until the run settles, then pi compacts and the run resumes.
// - Every compaction gets a deterministic log of earlier tool calls appended to its summary.

const PROMPT_TIMEOUT_MS = 5 * 60_000;
const MIN_COMPACT_RATIO = 0.5;
const VIRTUAL_MODEL_API = "pi-virtual";

const percent = (ratio: number) => `${Math.round(ratio * 100)}%`;

export default function contextSquash(pi: ExtensionAPI): void {
	let pendingCompact: { note?: string } | undefined;

	pi.on("turn_end", async (event, ctx) => {
		const usage = ctx.getContextUsage();
		if (!usage?.tokens || !usage.contextWindow) return;
		const ratio = usage.tokens / usage.contextWindow;
		if (ratio < SUGGEST_RATIO) return;

		const branch = ctx.sessionManager.getBranch();
		const state = readState(branch);
		const entries: SessionBoundaryDraft[] = [];

		if (!state.declined && ctx.hasUI) {
			const plan = planSquash(branch, new Set(event.toolResultEntryIds), estimateTokens);
			const projected = (usage.tokens - plan.savedTokens) / usage.contextWindow;
			if (plan.edits.length > 0 && projected < TARGET_RATIO) {
				const choice = await ctx.ui.select(
					`Context at ${percent(ratio)}. Squash ${plan.edits.length} old tool outputs (→ ~${percent(projected)})?`,
					["Not yet", "Yes", "No"],
					{ timeout: PROMPT_TIMEOUT_MS, signal: ctx.signal },
				);
				if (choice === "Yes") {
					return {
						entries: [...plan.edits, { type: "custom", customType: STATE_TYPE, data: { squashed: plan.edits.length } }],
					};
				}
				if (choice === "No") entries.push({ type: "custom", customType: STATE_TYPE, data: { declined: true } });
			}
		}

		if (!state.nudged) {
			entries.push({
				type: "custom_message",
				customType: NUDGE_TYPE,
				display: false,
				content:
					`Context usage is at ${percent(ratio)} of the window. At your next natural gap (a subtask finished, ` +
					"tests passing, before starting a new phase), consider calling the `compact` tool. Do not interrupt " +
					"work in progress for it.",
			});
		}
		return entries.length > 0 ? { entries } : undefined;
	});

	pi.registerTool({
		name: "compact",
		label: "Compact",
		description:
			"Compact the conversation context: older messages are summarized, recent ones are kept, and the run " +
			"resumes automatically afterwards. Optional: only call it at a natural gap (a subtask finished, tests " +
			"passing, before starting a new phase), never in the middle of a change. Refused below 50% context usage. " +
			"Pass `note` only when the summary should focus on something specific.",
		parameters: Type.Object({
			note: Type.Optional(Type.String({ description: "Optional focus for the compaction summary" })),
		}),
		async execute(_toolCallId, { note }, _signal, _onUpdate, ctx) {
			const usage = ctx.getContextUsage();
			if (!usage?.tokens || !usage.contextWindow) throw new Error("Context usage is unknown; nothing to compact yet.");
			const ratio = usage.tokens / usage.contextWindow;
			if (ratio < MIN_COMPACT_RATIO) {
				throw new Error(`Context is at ${percent(ratio)}; compaction is refused below 50%. Continue working.`);
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
						content: "Context was compacted at your request. Continue the task where you left off.",
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
