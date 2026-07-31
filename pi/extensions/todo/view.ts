/**
 * Rendering: the above-editor widget, the tool call/result rows, and the
 * `/todos` listing.
 *
 * Widget shape:
 *
 *   ● Todos  1/3
 *   ├ ✓ Study the widget API
 *   ├ ◐ Write the extension · writing the extension
 *   └ ○ Verify replay after compaction
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { Text, type TUI, truncateToWidth } from "@earendil-works/pi-tui";
import {
	CONFIDENCE_ENABLED,
	CONFIDENCE_THRESHOLD,
	counts,
	type Task,
	type TaskStatus,
	type TodoDetails,
	renderTasks,
} from "./state.js";

const WIDGET_KEY = "todo";

/** Content rows (heading included) before the list collapses into "+N more". */
const MAX_ROWS = 13;

const GLYPH: Record<TaskStatus, string> = { pending: "○", in_progress: "◐", completed: "✓" };
const GLYPH_COLOR: Record<TaskStatus, "dim" | "warning" | "success"> = {
	pending: "dim",
	in_progress: "warning",
	completed: "success",
};

/**
 * ` 95%` — green at the confidence threshold, red below it or when flagged.
 * Empty when confidence is disabled or unavailable in replayed data.
 */
function confidenceCell(task: Task, theme: Theme): string {
	if (!CONFIDENCE_ENABLED || task.confidence === undefined) return "";
	const color = !task.flagged && task.confidence >= CONFIDENCE_THRESHOLD ? "success" : "error";
	return theme.fg(color, `${String(task.confidence).padStart(3)}%`);
}

function subjectCell(task: Task, theme: Theme): string {
	if (task.status === "completed") return theme.strikethrough(theme.fg("dim", task.subject));
	if (task.status === "in_progress") {
		const subject = theme.bold(task.subject);
		return task.activeForm ? `${subject} ${theme.fg("dim", `· ${task.activeForm}`)}` : subject;
	}
	return theme.fg("muted", task.subject);
}

function taskLine(task: Task, branch: "├" | "└" | "", theme: Theme): string {
	return [
		theme.fg("dim", branch),
		theme.fg(GLYPH_COLOR[task.status], GLYPH[task.status]),
		confidenceCell(task, theme),
		subjectCell(task, theme),
	]
		.filter((cell) => cell !== "")
		.join(" ");
}


/** Keep the widget bounded: drop completed rows first, then the tail. */
function pickRows(tasks: readonly Task[], budget: number): { rows: readonly Task[]; hidden: number } {
	if (tasks.length <= budget) return { rows: tasks, hidden: 0 };
	const active = tasks.filter((task) => task.status !== "completed");
	const rows = active.slice(0, budget - 1);
	return { rows, hidden: tasks.length - rows.length };
}

export class TodoWidget {
	private uiCtx: ExtensionUIContext | undefined;
	private tui: TUI | undefined;
	private registered = false;
	private collapsed = false;
	private readonly hiddenCompleted = new Set<string>();
	private readonly collapseKey: string;

	constructor(collapseKey: string) {
		this.collapseKey = collapseKey;
	}

	setUICtx(ctx: ExtensionUIContext): void {
		if (ctx === this.uiCtx) return;
		this.uiCtx = ctx;
		this.registered = false;
		this.tui = undefined;
	}

	isRegistered(): boolean {
		return this.registered;
	}

	toggleCollapse(): void {
		this.collapsed = !this.collapsed;
		// Forced redraw: collapsing changes the widget's height.
		this.tui?.requestRender(true);
	}

	/** Hide work already completed confidently when the user starts a new turn. */
	hideCompleted(): void {
		for (const task of renderTasks()) {
			if (this.isConfidentlyCompleted(task)) this.hiddenCompleted.add(task.id);
		}
		this.update();
	}

	private isConfidentlyCompleted(task: Task): boolean {
		return (
			task.status === "completed" &&
			(!CONFIDENCE_ENABLED || (!task.flagged && (task.confidence ?? 0) >= CONFIDENCE_THRESHOLD))
		);
	}

	private visibleTasks(): readonly Task[] {
		const tasks = renderTasks();
		// Reusing an id for new/incomplete work must make it visible again.
		for (const id of this.hiddenCompleted) {
			const task = tasks.find((candidate) => candidate.id === id);
			if (!task || !this.isConfidentlyCompleted(task)) this.hiddenCompleted.delete(id);
		}
		return tasks.filter((task) => !this.hiddenCompleted.has(task.id));
	}

	update(): void {
		if (!this.uiCtx) return;
		if (renderTasks().length === 0) {
			if (this.registered) {
				this.uiCtx.setWidget(WIDGET_KEY, undefined);
				this.registered = false;
				this.tui = undefined;
			}
			return;
		}
		if (this.registered) {
			this.tui?.requestRender();
			return;
		}
		this.uiCtx.setWidget(
			WIDGET_KEY,
			(tui, theme) => {
				this.tui = tui;
				return {
					render: (width: number) => this.render(theme, width),
					invalidate: () => {
						this.registered = false;
						this.tui = undefined;
					},
				};
			},
			{ placement: "aboveEditor" },
		);
		this.registered = true;
	}

	dispose(): void {
		this.uiCtx?.setWidget(WIDGET_KEY, undefined);
		this.uiCtx = undefined;
		this.tui = undefined;
		this.registered = false;
		this.collapsed = false;
		this.hiddenCompleted.clear();
	}

	private render(theme: Theme, width: number): string[] {
		const allTasks = renderTasks();
		if (allTasks.length === 0) return [];
		const tasks = this.visibleTasks();

		// The heading always describes the complete list; filtering only affects
		// the rows below it.
		const { total, completed, inProgress } = counts(allTasks);
		const color = inProgress > 0 ? "accent" : "dim";
		const heading = `${theme.fg(color, inProgress > 0 ? "●" : "○")} ${theme.fg(color, "Todos")}  ${theme.fg("dim", `${completed}/${total}`)}`;

		if (this.collapsed) {
			return [heading, theme.fg("dim", `└ ${this.collapseKey} to expand`), ""];
		}

		const { rows, hidden } = pickRows(tasks, MAX_ROWS - 1);
		const lines = [heading];
		rows.forEach((task, index) => {
			const branch = hidden === 0 && index === rows.length - 1 ? "└" : "├";
			lines.push(truncateToWidth(taskLine(task, branch, theme), width, "…"));
		});
		if (hidden > 0) lines.push(theme.fg("dim", `└ +${hidden} more`));
		// Trailing spacer: pi puts no gap between the widget and the editor box.
		lines.push("");
		return lines;
	}
}

/** `todo ✎ Write the extension` — names the task the model is working on. */
export function renderCall(tasks: readonly Task[] | undefined, theme: Theme): Text {
	const { total, completed } = counts(tasks ?? []);
	const label = `${completed}/${total} tasks`;
	return new Text(`${theme.fg("toolTitle", theme.bold("todo "))}${theme.fg("dim", label)}`, 0, 0);
}

export function renderResult(details: TodoDetails | undefined, theme: Theme): Text {
	if (!details) return new Text(theme.fg("success", "✓"), 0, 0);
	const lines = [];
	details.tasks.forEach((task, _index) => {
		lines.push(taskLine(task, "", theme));
	});
	if (CONFIDENCE_ENABLED && details.warnings?.length) {
		lines.push(theme.fg("warning", `  ${details.warnings.length} confidence check${details.warnings.length === 1 ? "" : "s"} required`));
	}
	return new Text(lines.join("\n"), 0, 0);
}

/** Plain-text list for the `/todos` command. */
export function formatList(tasks: readonly Task[]): string {
	return tasks
		.map((task) => {
			const form = task.status === "in_progress" && task.activeForm ? ` · ${task.activeForm}` : "";
			const trail = CONFIDENCE_ENABLED && (task.history?.length ?? 0) > 1 ? ` (${task.history?.join("›")})` : "";
			const score = CONFIDENCE_ENABLED && task.confidence !== undefined ? `  ${task.confidence}%${trail}` : "";
			return `  ${GLYPH[task.status]} ${task.subject}${form}${score}`;
		})
		.join("\n");
}
