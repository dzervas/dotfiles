/**
 * todo — a task list for the model, rendered as a live widget above the editor
 * and rebuilt from the session branch so it survives `/reload` and compaction.
 *
 * Every call replaces the whole list (the shape Claude Code, Codex, and jcode
 * all converged on), so a single call can create, update, and drop tasks at
 * once.
 */

import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
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
	TODO_CHANGED_EVENT,
} from "./state.js";
import { formatList, renderCall, renderResult, TodoWidget } from "./view.js";

const TaskSchema = Type.Object({
	subject: Type.String({ description: "Short imperative task line, e.g. 'Add the parser test'." }),
	status: StringEnum(["pending", "in_progress", "completed"] as const),
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
			"Track multi-step work as a task list. Send the complete list every time: it replaces the stored one, and omitted tasks are dropped. One call can create, reorder, update, and drop tasks at once.",
		promptSnippet: "Track multi-step work as a task list",
		promptGuidelines: [
			"Use todo for work with 3+ steps or when the user hands you a list of tasks; skip it for trivial single-step and conversational requests.",
			"Every todo call replaces the whole list: resend every task you still want and omit a task only when you mean to drop it.",
			"Keep at most one task in_progress; set each status explicitly, including completed when its work is done.",
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
			const tasks = applyWrite(incoming);
			setTasks(session, tasks);
			if (ctx.mode === "tui") pi.events.emit(TODO_CHANGED_EVENT, undefined);

			const { total, completed, inProgress, pending } = counts(tasks);
			const summary = total === 0 ? "List cleared" : `${total} tasks: ${completed} completed, ${inProgress} in progress, ${pending} pending`;
			const details: TodoDetails = { tasks };
			return {
				content: [{ type: "text", text: summary }],
				details,
			};
		},

		renderCall(args, theme) {
			return renderCall((args as { tasks?: TaskInput[] }).tasks, theme);
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

	pi.on("session_start", async (_event, ctx) => {
		const session = ifLive(() => {
			const id = sid(ctx);
			setTasks(id, replay(ctx));
			return id;
		});
		if (session === undefined || ctx.mode !== "tui") return;
		// Only the interactive session owns the widget and title.
		if (widget === undefined) {
			widget = new TodoWidget();
		}
		setRenderSession(session);
		pi.events.emit(TODO_CHANGED_EVENT, undefined);
		widget.setUICtx(ctx.ui);
		widget.update();
	});

	const refresh = (ctx: Parameters<typeof sid>[0] & Parameters<typeof replay>[0]) => {
		const foreground = ifLive(() => {
			const id = sid(ctx);
			setTasks(id, replay(ctx));
			return id === getRenderSession();
		});
		if (foreground) {
			widget?.update();
			pi.events.emit(TODO_CHANGED_EVENT, undefined);
		}
	};

	pi.on("session_compact", async (_event, ctx) => refresh(ctx));
	pi.on("session_tree", async (_event, ctx) => refresh(ctx));

	pi.on("session_shutdown", async (_event, ctx) => {
		// The closing session may already have an invalid context.
		const session = ifLive(() => sid(ctx)) ?? "";
		evictSession(session);
		if (widget && (session === "" || session === getRenderSession())) {
			widget?.dispose();
			widget = undefined;
			setRenderSession("");
			pi.events.emit(TODO_CHANGED_EVENT, undefined);
		}
	});

	pi.on("tool_execution_end", async (event) => {
		if (event.toolName === "todo" && !event.isError) widget?.update();
	});
}
