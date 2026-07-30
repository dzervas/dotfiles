/**
 * Task state: types, the per-session store, branch replay, and the write
 * reducer that owns the confidence trail.
 *
 * The tool is a full-list replacement (like Claude Code's TodoWrite and
 * jcode's todo): the model resends every task it wants to keep, so ids are
 * model-chosen and only exist to anchor a task to its previous self across
 * writes — which is what makes the confidence history trustworthy.
 */

export type TaskStatus = "pending" | "in_progress" | "completed";

export interface Task {
	id: string;
	subject: string;
	status: TaskStatus;
	activeForm?: string;
	/** Absent only for tasks replayed from a pre-confidence tool version. */
	confidence?: number;
	/** Tool-owned confidence trail. Model-supplied values are ignored. */
	history: number[];
	/** Tool-owned: this task's confidence failed a gate and has not been reassessed. */
	flagged?: boolean;
}

/** Incoming task as the model sends it (the tool owns `history` and `flagged`). */
export interface TaskInput {
	id: string;
	subject: string;
	status: TaskStatus;
	activeForm?: string;
	confidence: number;
}

/** Persisted tool-result payload; `replay` reconstructs state from the latest one. */
export interface TodoDetails {
	tasks: Task[];
	warnings?: string[];
}

/** A completion-confidence rise larger than this is not credible as validation. */
const SPIKE_THRESHOLD = 15;

/** A task claimed complete below this confidence is not credible as done. */
const LOW_COMPLETION_CONFIDENCE = 80;

const GATE_ADVICE =
	"Recheck it with concrete evidence (a test run, an inspected output). If you cannot validate it yourself, delegate the verification to a subagent, or stop and report to the user exactly what is unverified. Then write the list again with a confidence that reflects the validation you actually performed.";

export function validate(incoming: TaskInput[]): string | undefined {
	const seen = new Set<string>();
	for (const task of incoming) {
		if (!task.id.trim()) return "every task needs a non-empty id";
		if (!task.subject.trim()) return `task "${task.id}" needs a non-empty subject`;
		if (seen.has(task.id)) return `duplicate id "${task.id}"`;
		seen.add(task.id);
	}
	return undefined;
}

/**
 * Fold the incoming list into the stored one: carry each task's confidence
 * trail forward, append at most one observation per write (deduped against the
 * last), and flag newly completed tasks whose confidence is not credible.
 *
 * One observation per write is what stops a single completion update from
 * manufacturing an apparent gradual climb: 75 → 100 stays visible as a jump.
 */
export function applyWrite(
	previous: readonly Task[],
	incoming: TaskInput[],
): { tasks: Task[]; warnings: string[] } {
	const prior = new Map(previous.map((task) => [task.id, task]));
	const warnings: string[] = [];
	const tasks = incoming.map((input) => {
		const before = prior.get(input.id);
		const history = before ? [...before.history] : [];
		if (history[history.length - 1] !== input.confidence) history.push(input.confidence);

		const newlyCompleted = input.status === "completed" && before?.status !== "completed";
		let gated = false;
		if (newlyCompleted && input.confidence < LOW_COMPLETION_CONFIDENCE) {
			gated = true;
			warnings.push(
				`#${input.id} is marked completed at confidence ${input.confidence}, which is too low to call it done. ${GATE_ADVICE}`,
			);
		} else if (newlyCompleted && before?.confidence !== undefined && input.confidence - before.confidence > SPIKE_THRESHOLD) {
			gated = true;
			warnings.push(
				`#${input.id} rose ${before.confidence} → ${input.confidence} on completion, too sharply to count as independently validated. ${GATE_ADVICE}`,
			);
		}

		const task: Task = {
			id: input.id,
			subject: input.subject,
			status: input.status,
			confidence: input.confidence,
			history,
		};
		if (input.activeForm) task.activeForm = input.activeForm;
		// A flag clears only once the confidence is reassessed: re-sending the same
		// score does not count as having rechecked the work.
		if (gated || (before?.flagged && input.confidence === before.confidence)) task.flagged = true;
		return task;
	});
	return { tasks, warnings };
}

export function counts(tasks: readonly Task[]): {
	total: number;
	completed: number;
	inProgress: number;
	pending: number;
} {
	return {
		total: tasks.length,
		completed: tasks.filter((task) => task.status === "completed").length,
		inProgress: tasks.filter((task) => task.status === "in_progress").length,
		pending: tasks.filter((task) => task.status === "pending").length,
	};
}

// ---------------------------------------------------------------------------
// Per-session store. Each session gets its own slot so a detached/child
// session can never read or clobber another's list. `renderSession` is the
// foreground pointer for the ctx-less readers (widget, renderCall).
// ---------------------------------------------------------------------------

type SessionCtx = { sessionManager: { getSessionId(): string } };
type BranchCtx = { sessionManager: { getBranch(): Iterable<unknown> } };

const sessions = new Map<string, Task[]>();
let renderSession = "";

export function sid(ctx: SessionCtx): string {
	return ctx.sessionManager.getSessionId() ?? "";
}

export function getTasks(sessionId: string): readonly Task[] {
	return sessions.get(sessionId) ?? [];
}

export function setTasks(sessionId: string, tasks: Task[]): void {
	sessions.set(sessionId, tasks);
}

export function evictSession(sessionId: string): void {
	sessions.delete(sessionId);
}

export function renderTasks(): readonly Task[] {
	return getTasks(renderSession);
}

export function getRenderSession(): string {
	return renderSession;
}

export function setRenderSession(sessionId: string): void {
	renderSession = sessionId;
}

/** Rebuild a session's list from the last `todo` result on the current branch. */
export function replay(ctx: BranchCtx): Task[] {
	let tasks: Task[] = [];
	for (const entry of ctx.sessionManager.getBranch()) {
		const message = (entry as { type?: string; message?: Record<string, unknown> }).message;
		if (!message || message.role !== "toolResult" || message.toolName !== "todo") continue;
		const details = message.details as TodoDetails | undefined;
		if (!Array.isArray(details?.tasks)) continue;
		tasks = details.tasks.map((task) => ({ ...task, history: [...(task.history ?? [])] }));
	}
	return tasks;
}
