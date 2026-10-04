/**
 * Rendering: the above-editor widget, the tool call/result rows, and the
 * `/todos` listing.
 *
 * Widget shape:
 *
 *   ● Todos  1/3
 *   ├ ✓ Study the widget API
 *   ├ ◐ Write the extension
 *   └ ○ Verify replay after compaction
 *
 * In fullscreen mode it collapses to the heading while the transcript is
 * scrolled back, and expands again once the transcript follows output.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { Text, type TUI, truncateToWidth } from "@earendil-works/pi-tui";
import {
	counts,
	type Task,
	type TaskStatus,
	type TodoDetails,
	renderTasks,
} from "./state.js";

const WIDGET_KEY = "todo";

/** Maximum visible rows, including the heading and overflow indicator. */
const MAX_ROWS = 13;

const GLYPH: Record<TaskStatus, string> = { pending: "○", in_progress: "◐", completed: "✓" };
const GLYPH_COLOR: Record<TaskStatus, "dim" | "warning" | "success"> = {
	pending: "dim",
	in_progress: "warning",
	completed: "success",
};

function subjectCell(task: Task, theme: Theme): string {
	if (task.status === "completed") return theme.strikethrough(theme.fg("dim", task.subject));
	if (task.status === "in_progress") {
		return theme.bold(task.subject);
	}
	return theme.fg("muted", task.subject);
}

function taskLine(task: Task, branch: "├" | "└" | "", theme: Theme): string {
	return [
		theme.fg("dim", branch),
		theme.fg(GLYPH_COLOR[task.status], GLYPH[task.status]),
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

/** The part of pi-tui's transcript ScrollView the widget reads and nudges. */
interface Transcript {
	readonly isFollowingEnd: boolean;
	scrollBy(lines: number): number;
}

/**
 * The fullscreen transcript, or nothing in regular mode where the terminal owns
 * scrollback. pi-tui exposes it only through the private `getPrimaryScrollView`,
 * so probe for it rather than break on an upgrade that renames it.
 */
function transcriptOf(tui: TUI | undefined): Transcript | undefined {
	if (tui?.mode !== "fullscreen") return undefined;
	return (tui as unknown as { getPrimaryScrollView?: () => Transcript }).getPrimaryScrollView?.();
}

export class TodoWidget {
	private uiCtx: ExtensionUIContext | undefined;
	private tui: TUI | undefined;
	private registered = false;
	/** Rows the previous frame rendered, to keep the transcript anchored on collapse. */
	private lastHeight = 0;
	private collapsed = false;
	setUICtx(ctx: ExtensionUIContext): void {
		if (ctx === this.uiCtx) return;
		this.uiCtx = ctx;
		this.registered = false;
		this.tui = undefined;
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
	}

	private render(theme: Theme, width: number): string[] {
		const allTasks = renderTasks();
		if (allTasks.length === 0) return [];
		const tasks = allTasks;

		// The heading always describes the complete list; filtering only affects
		// the rows below it.
		const { total, completed, inProgress } = counts(allTasks);
		const color = inProgress > 0 ? "accent" : "dim";
		const heading = `${theme.fg(color, inProgress > 0 ? "●" : "○")} ${theme.fg(color, "Todos")}  ${theme.fg("dim", `${completed}/${total}`)}`;

		const transcript = transcriptOf(this.tui);
		const collapse = transcript !== undefined && !transcript.isFollowingEnd;
		if (collapse) {
			const lines = [heading, ""];
			// The freed rows extend the transcript downward. Scrolling back by the
			// same amount keeps the visible lines in place; otherwise a short scroll
			// would clamp to the end, resume following, and expand the list again.
			const freed = this.lastHeight - lines.length;
			if (!this.collapsed && freed > 0) transcript.scrollBy(-freed);
			this.collapsed = true;
			this.lastHeight = lines.length;
			return lines;
		}
		this.collapsed = false;

		const { rows, hidden } = pickRows(tasks, MAX_ROWS - 1);
		const lines = [heading];
		rows.forEach((task, index) => {
			const branch = hidden === 0 && index === rows.length - 1 ? "└" : "├";
			lines.push(truncateToWidth(taskLine(task, branch, theme), width, "…"));
		});
		if (hidden > 0) lines.push(theme.fg("dim", `└ +${hidden} more`));
		// Trailing spacer: pi puts no gap between the widget and the editor box.
		lines.push("");
		this.lastHeight = lines.length;
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
	return new Text(details.tasks.map((task) => taskLine(task, "", theme)).join("\n"), 0, 0);
}

/** Plain-text list for the `/todos` command. */
export function formatList(tasks: readonly Task[]): string {
	return tasks
		.map((task) => {
			return `  ${GLYPH[task.status]} ${task.subject}`;
		})
		.join("\n");
}
