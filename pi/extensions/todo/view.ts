/**
 * Rendering: the above-editor widget, the tool call/result rows, and the
 * `/todos` listing.
 *
 * Widget shape (confidence sits next to the status glyph):
 *
 *   ● Todos  1/3
 *   ├ ✓  95% Study the widget API
 *   ├ ◐  85% Write the extension · writing the extension
 *   └ ○  30% Verify replay after compaction
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { Text, type TUI, truncateToWidth } from "@earendil-works/pi-tui";
import { counts, type Task, type TaskStatus, type TodoDetails, renderTasks } from "./state.js";

const WIDGET_KEY = "todo";

/** Content rows (heading included) before the list collapses into "+N more". */
const MAX_ROWS = 13;

/** At or above this confidence a task counts as solid. */
const GOOD_CONFIDENCE = 90;

const GLYPH: Record<TaskStatus, string> = { pending: "○", in_progress: "◐", completed: "✓" };
const GLYPH_COLOR: Record<TaskStatus, "dim" | "warning" | "success"> = {
	pending: "dim",
	in_progress: "warning",
	completed: "success",
};

/**
 * ` 95%` — error while a gate has it flagged, success when solid, plain
 * otherwise. Empty for tasks replayed from a pre-confidence tool version.
 */
function confidenceCell(task: Task, theme: Theme): string {
	if (task.confidence === undefined) return "";
	const color = task.flagged ? "error" : task.confidence >= GOOD_CONFIDENCE ? "success" : "text";
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
	}

	private render(theme: Theme, width: number): string[] {
		const tasks = renderTasks();
		if (tasks.length === 0) return [];

		const { total, completed, inProgress } = counts(tasks);
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
	if (details.warnings?.length) {
		lines.push(theme.fg("warning", ` ${details.warnings.length} confidence check${details.warnings.length === 1 ? "" : "s"} required`));
	}
	return new Text(lines.join("\n"), 0, 0);
}

/** Plain-text list for the `/todos` command. */
export function formatList(tasks: readonly Task[]): string {
	return tasks
		.map((task) => {
			const form = task.status === "in_progress" && task.activeForm ? ` · ${task.activeForm}` : "";
			const trail = task.history.length > 1 ? ` (${task.history.join("›")})` : "";
			const score = task.confidence === undefined ? "" : `  ${task.confidence}%${trail}`;
			return `  ${GLYPH[task.status]} ${task.subject}${form}${score}`;
		})
		.join("\n");
}
