/** Full-list task snapshots, isolated per session and replayed from its branch. */

export type TaskStatus = "pending" | "in_progress" | "completed";

export interface Task {
	subject: string;
	status: TaskStatus;
}

export type TaskInput = Task;

/** Persisted tool-result payload; `replay` reconstructs state from the latest one. */
export interface TodoDetails {
	tasks: Task[];
}

export function validate(incoming: TaskInput[]): string | undefined {
	if (incoming.some((task) => !task.subject.trim())) return "every task needs a non-empty subject";
	if (incoming.filter((task) => task.status === "in_progress").length > 1)
		return "at most one task can be in progress";
	return undefined;
}

/** Strip retired fields when replaying older snapshots. */
export function applyWrite(incoming: readonly TaskInput[]): Task[] {
	return incoming.map(({ subject, status }) => ({ subject, status }));
}

/** Position of the active task, not the number of completed tasks. */
export function activeTaskSuffix(tasks: readonly Task[]): string {
	const active = tasks.findIndex((task) => task.status === "in_progress");
	return active < 0 ? "" : `${active + 1}/${tasks.length}`;
}

export const TODO_CHANGED_EVENT = "todo:changed";

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
		tasks = applyWrite(details.tasks);
	}
	return tasks;
}
