/**
 * todo — a task list for the model, rendered as a live widget above the editor
 * and rebuilt from the session branch so it survives `/reload` and compaction.
 *
 * Every call replaces the whole list (the shape Claude Code, Codex, and jcode
 * all converged on), so a single call can create, update, and drop tasks at
 * once. Each task carries a model-assessed `confidence`; the trail of those
 * assessments is owned by the tool, and an implausible jump to "completed"
 * is flagged back to the model.
 */

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { KeyId } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
	applyWrite,
	counts,
	evictSession,
	getRenderSession,
	getTasks,
	replay,
	setRenderSession,
	setTasks,
	sid,
	type TaskInput,
	type TodoDetails,
	validate,
} from "./state.js";
import { formatList, renderCall, renderResult, TodoWidget } from "./view.js";

const COLLAPSE_KEY = "alt+t";

const TaskSchema = Type.Object({
	id: Type.String({ description: "Stable id you choose; reuse it in later calls to keep the task's history." }),
	subject: Type.String({ description: "Short imperative task line, e.g. 'Add the parser test'." }),
	status: StringEnum(["pending", "in_progress", "completed"] as const),
	activeForm: Type.Optional(
		Type.String({ description: "Present-continuous label shown while in_progress, e.g. 'adding the parser test'." }),
	),
	confidence: Type.Integer({
		minimum: 0,
		maximum: 100,
		description:
			"Self-assessed confidence, 0-100, that this task is (or will be) done correctly. Reassess it as evidence accumulates: a passing test, an inspected output, a reproduced bug each earn a step up. Do not stamp a high score on completion that you have not validated.",
	}),
});

const ParamsSchema = Type.Object({
	tasks: Type.Array(TaskSchema, {
		description: "The complete task list. It replaces the stored one, so omitted tasks are dropped.",
	}),
});

/**
 * pi-core invalidates a session's ctx proxy while still emitting lifecycle
 * events (auto-compaction racing session disposal). Swallow only that known
 * error so genuine replay bugs still surface.
 */
function ifLive<T>(fn: () => T): T | undefined {
	try {
		return fn();
	} catch (e) {
		if (!/stale after session replacement/.test(String(e))) throw e;
		return undefined;
	}
}

export default function todoExtension(pi: ExtensionAPI): void {
	let widget: TodoWidget | undefined;

	pi.registerTool({
		name: "todo",
		label: "Todo",
		description:
			"Track multi-step work as a task list. Send the complete list every time: it replaces the stored one, ids are yours to choose and must stay stable across calls, and a task you omit is dropped. One call can create, reorder, update, and drop tasks at once.",
		promptSnippet: "Track multi-step work as a task list with per-task confidence",
		promptGuidelines: [
			"Use todo for work with 3+ steps or when the user hands you a list of tasks; skip it for trivial single-step and conversational requests.",
			"Every todo call replaces the whole list: resend every task you still want, keep each task's id stable, and omit a task only when you mean to drop it.",
			"Keep exactly one task in_progress: mark it in_progress before starting the work and completed as soon as it is actually done.",
			"Score confidence honestly and raise it as validation happens, not at the end. A task marked completed with low confidence, or one whose confidence jumps on completion, is sent back for rechecking.",
		],
		parameters: ParamsSchema,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const session = sid(ctx);
			const incoming = params.tasks as TaskInput[];
			const invalid = validate(incoming);
			if (invalid) {
				// Keep the stored list in `details` so replay is unaffected by the reject.
				return {
					content: [{ type: "text", text: `Error: ${invalid}` }],
					details: { tasks: [...getTasks(session)] } satisfies TodoDetails,
					isError: true,
				};
			}
			const { tasks, warnings } = applyWrite(getTasks(session), incoming);
			setTasks(session, tasks);

			const { total, completed, inProgress, pending } = counts(tasks);
			const summary = total === 0 ? "List cleared" : `${total} tasks: ${completed} completed, ${inProgress} in progress, ${pending} pending`;
			const details: TodoDetails = { tasks, ...(warnings.length ? { warnings } : {}) };
			return {
				content: [{ type: "text", text: [summary, ...warnings.map((w) => ` ${w}`)].join("\n") }],
				details,
			};
		},

		renderCall(args, theme) {
			return renderCall((args as { tasks?: TaskInput[] }).tasks as never, theme);
		},

		renderResult(result, _opts, theme) {
			return renderResult(result.details as TodoDetails | undefined, theme);
		},
	});

	pi.registerCommand("todos", {
		description: "Show the current todo list",
		handler: async (_args, ctx) => {
			const tasks = getTasks(sid(ctx));
			if (tasks.length === 0) {
				ctx.ui.notify("No todos yet.", "info");
				return;
			}
			const { total, completed } = counts(tasks);
			ctx.ui.notify(`${completed}/${total} completed\n${formatList(tasks)}`, "info");
		},
	});

	pi.registerShortcut(COLLAPSE_KEY as KeyId, {
		description: "Collapse or expand the todo widget",
		handler: (ctx) => {
			if (ctx.hasUI && widget?.isRegistered()) widget.toggleCollapse();
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		const session = ifLive(() => {
			const id = sid(ctx);
			setTasks(id, replay(ctx));
			return id;
		});
		if (session === undefined || !ctx.hasUI) return;
		// The first UI-bearing session claims the widget; children never rebind it.
		if (widget === undefined) {
			widget = new TodoWidget(COLLAPSE_KEY);
			setRenderSession(session);
		}
		if (session !== getRenderSession()) return;
		widget.setUICtx(ctx.ui);
		widget.update();
	});

	const refresh = (ctx: Parameters<typeof sid>[0] & Parameters<typeof replay>[0]) => {
		const foreground = ifLive(() => {
			const id = sid(ctx);
			setTasks(id, replay(ctx));
			return id === getRenderSession();
		});
		if (foreground) widget?.update();
	};

	pi.on("session_compact", async (_event, ctx) => refresh(ctx));
	pi.on("session_tree", async (_event, ctx) => refresh(ctx));

	pi.on("session_shutdown", async (_event, ctx) => {
		// An unknown/stale sid resolves to "" and is treated as the foreground.
		const session = ifLive(() => sid(ctx)) ?? "";
		evictSession(session);
		if (session === "" || session === getRenderSession()) {
			widget?.dispose();
			widget = undefined;
			setRenderSession("");
		}
	});

	pi.on("message_start", async (event, ctx) => {
		if (event.message.role !== "user") return;
		const foreground = ifLive(() => sid(ctx) === getRenderSession());
		if (foreground) widget?.hideCompleted();
	});

	pi.on("tool_execution_end", async (event) => {
		if (event.toolName === "todo" && !event.isError) widget?.update();
	});
}
