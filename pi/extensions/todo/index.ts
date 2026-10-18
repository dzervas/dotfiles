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
import { getPrompt } from "../lib/prompts.ts";
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
import {
	BEADS_GUIDANCE,
	execBd,
	fetchBeads,
	fetchUnclaimedParents,
	GUIDANCE_ENTRY,
	hasBeadsWorkspace,
	recordedGuidance,
	setParentBeadsActor,
	setBeadsSnapshot,
	setUnclaimedParents,
} from "./beads.js";

const TaskSchema = Type.Object({
	subject: Type.String({ description: getPrompt("todo", "parameter-subject") }),
	status: StringEnum(["pending", "in_progress", "completed"] as const),
});

const ParamsSchema = Type.Object({
	tasks: Type.Array(TaskSchema, {
		description: getPrompt("todo", "parameter-tasks"),
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

	// Beads context is fetched only for the interactive session that owns the
	// widget: at its start, after each agent run, and after bash calls running
	// `bd`. `beadsCwd` is that session's directory, unset when there is none.
	let beadsCwd: string | undefined;
	let beadsActor: string | undefined;
	let beadsRefresh = Promise.resolve();
	const bdCalls = new Set<string>();
	const refreshBeads = () => {
		// Serialized so a slow earlier fetch cannot overwrite a newer one.
		beadsRefresh = beadsRefresh.then(async () => {
			const cwd = beadsCwd;
			const actor = beadsActor;
			const snapshot =
				cwd !== undefined && actor && hasBeadsWorkspace(cwd)
					? await fetchBeads((...args) => pi.exec(...args), cwd, actor).catch(() => undefined)
					: undefined;
			const parents =
				!snapshot && cwd !== undefined && hasBeadsWorkspace(cwd)
					? await fetchUnclaimedParents((...args) => pi.exec(...args), cwd).catch(() => [])
					: [];
			if (cwd !== beadsCwd || actor !== beadsActor) return;
			setBeadsSnapshot(snapshot);
			setUnclaimedParents(parents);
			widget?.update();
		});
		return beadsRefresh;
	};
	pi.on("tool_execution_start", async (event) => {
		const command = String(event.args?.command ?? "");
		if (beadsCwd !== undefined && event.toolName === "bash" && /\bbd\b/.test(command)) bdCalls.add(event.toolCallId);
	});
	pi.on("tool_execution_end", async (event) => {
		if (bdCalls.delete(event.toolCallId)) refreshBeads();
	});
	pi.on("agent_end", async () => {
		if (beadsCwd !== undefined) refreshBeads();
	});

	pi.registerTool({
		name: "todo",
		label: "Todo",
		description: getPrompt("todo", "description"),
		promptSnippet: getPrompt("todo", "snippet"),
		promptGuidelines: [
			getPrompt("todo", "guideline-when"),
			getPrompt("todo", "guideline-replace"),
			getPrompt("todo", "guideline-status"),
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
		description: "Show current todos and this parent team's beads; refresh the widget",
		handler: async (_args, ctx) => {
			await refreshBeads();
			const tasks = getTasks(sid(ctx));
			const { total, completed } = counts(tasks);
			const sections = [total === 0 ? "No todos yet." : `${completed}/${total} completed\n${formatList(tasks)}`];
			const cwd = ctx.cwd ?? process.cwd();
			if (hasBeadsWorkspace(cwd)) {
				try {
					if (!beadsActor) throw new Error("parent Beads actor is unavailable");
					const result = await execBd((...args) => pi.exec(...args), cwd, ["list", "--assignee", beadsActor]);
					if (result.code !== 0) {
						ctx.ui.notify(`bd list failed: ${result.stderr || result.stdout || `exit ${result.code}`}`, "error");
					} else {
						sections.push(`Beads owned by ${beadsActor}\n${result.stdout.trimEnd()}`);
					}
				} catch (error) {
					ctx.ui.notify(`bd list failed: ${String(error)}`, "error");
				}
			}
			ctx.ui.notify(sections.join("\n\n"), "info");
		},
	});

	// The beads section is decided once, when a session first starts, and
	// recorded in it: reload, resume, and fork reuse the record, so the system
	// prompt (and its cache) stays fixed even if `bd init` runs mid-session.
	const guidance = new Map<string, string>();
	pi.on("before_agent_start", (event, ctx) => {
		const text = ifLive(() => guidance.get(sid(ctx)));
		return text ? { systemPrompt: `${event.systemPrompt}\n\n${text}` } : undefined;
	});

	pi.on("session_start", async (_event, ctx) => {
		const session = ifLive(() => {
			const id = sid(ctx);
			beadsActor = setParentBeadsActor(id, ctx.mode, ctx.sessionManager.getHeader?.()?.parentSession);
			setTasks(id, replay(ctx));
			let text = recordedGuidance(ctx.sessionManager.getBranch());
			if (text === undefined) {
				text = hasBeadsWorkspace(ctx.cwd ?? process.cwd()) ? BEADS_GUIDANCE : "";
				pi.appendEntry(GUIDANCE_ENTRY, { text });
			}
			guidance.set(id, text);
			return id;
		});
		if (session === undefined || ctx.mode !== "tui") return;
		// Only the interactive session owns the widget and title.
		if (widget === undefined) {
			widget = new TodoWidget();
		}
		setRenderSession(session);
		setBeadsSnapshot(undefined);
		setUnclaimedParents([]);
		pi.events.emit(TODO_CHANGED_EVENT, undefined);
		widget.setUICtx(ctx.ui);
		widget.update();
		beadsCwd = ctx.cwd ?? process.cwd();
		refreshBeads();
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
		guidance.delete(session);
		if (widget && (session === "" || session === getRenderSession())) {
			widget?.dispose();
			widget = undefined;
			beadsCwd = undefined;
			beadsActor = undefined;
			setBeadsSnapshot(undefined);
			setUnclaimedParents([]);
			setRenderSession("");
			pi.events.emit(TODO_CHANGED_EVENT, undefined);
		}
	});

	pi.on("tool_execution_end", async (event) => {
		if (event.toolName === "todo" && !event.isError) widget?.update();
	});
}
