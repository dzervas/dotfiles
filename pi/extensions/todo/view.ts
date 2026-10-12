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
 * With a claimed bead (see beads.ts) the heading becomes a breadcrumb and a
 * strip summarises the epic's children, one glyph each, plus the next ready one:
 *
 *   ● Beads status in todo widget › Fetch claimed bead  1/3
 *     ✓◐⊘○⊘⊘ 1/6 · next ○ Document beads
 *   ├ ✓ Study the widget API
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
} from "./state.ts";
import { type BeadState, type BeadsSnapshot, beadsSnapshot, unclaimedParents } from "./beads.ts";

const WIDGET_KEY = "todo";

/** Maximum visible rows, including the heading and overflow indicator. */
const MAX_ROWS = 13;

// Nerd Font icons: the Unicode ◐ sits below the baseline of its neighbours.
const GLYPH: Record<TaskStatus, string> = { pending: "\uf10c", in_progress: "\uf192", completed: "\uf058" };
const GLYPH_COLOR: Record<TaskStatus, "dim" | "warning" | "success"> = {
	pending: "dim",
	in_progress: "warning",
	completed: "success",
};

const BEAD_GLYPH: Record<BeadState, string> = {
	closed: GLYPH.completed,
	in_progress: GLYPH.in_progress,
	ready: GLYPH.pending,
	blocked: "\uf05e",
};
const BEAD_COLOR: Record<BeadState, "dim" | "muted" | "warning" | "success"> = {
	closed: "success",
	in_progress: "warning",
	ready: "muted",
	blocked: "dim",
};

const beadGlyph = (state: BeadState, theme: Theme) => theme.fg(BEAD_COLOR[state], BEAD_GLYPH[state]);

/**
 * `● Todos  1/3`, or with a claimed bead `● epic › claimed  1/3`. The dot is
 * lit while a todo is in progress, or while a bead is claimed with no todos.
 */
function headingLine(tasks: readonly Task[], beads: BeadsSnapshot | undefined, theme: Theme): string {
	const { total, completed, inProgress } = counts(tasks);
	const active = inProgress > 0 || (beads !== undefined && total === 0);
	const color = active ? "accent" : "dim";
	const counter = total > 0 ? `  ${theme.fg("dim", `${completed}/${total}`)}` : "";
	if (!beads) return `${theme.fg(color, active ? "●" : "○")} ${theme.fg(color, "Todos")}${counter}`;
	const { claimed, epic } = beads;
	const crumb = epic && epic.id !== claimed.id ? `${theme.fg("muted", epic.title)} ${theme.fg("dim", "›")} ` : "";
	return `${theme.fg(color, active ? "●" : "○")} ${crumb}${theme.bold(claimed.title)}${counter}`;
}

/** `  ✓◐⊘○ 1/4 · next ○ Title`; undefined without an epic. */
function childStrip(beads: BeadsSnapshot | undefined, theme: Theme): string | undefined {
	const children = beads?.children ?? [];
	if (children.length === 0) return undefined;
	const glyphs = children.map((child) => beadGlyph(child.state, theme)).join("");
	const closed = children.filter((child) => child.state === "closed").length;
	const next = children.find((child) => child.state === "ready");
	const nextPart = next
		? ` ${theme.fg("dim", "· next")} ${beadGlyph("ready", theme)} ${theme.fg("muted", next.title)}`
		: "";
	return `  ${glyphs} ${theme.fg("dim", `${closed}/${children.length}`)}${nextPart}`;
}

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

/**
 * Keep the widget short: completed tasks collapse to the most recent one, then
 * the tail is dropped to fit `budget`, which includes the overflow row.
 */
function pickRows(tasks: readonly Task[], budget: number): { rows: readonly Task[]; hidden: readonly Task[] } {
	const lastDone = tasks.findLastIndex((task) => task.status === "completed");
	const visible = tasks.filter((task, index) => task.status !== "completed" || index === lastDone);
	const overflow = visible.length < tasks.length ? 1 : 0;
	const rows = visible.length + overflow <= budget ? visible : visible.slice(0, budget - 1);
	return { rows, hidden: tasks.filter((task) => !rows.includes(task)) };
}

/** `+3 done +1 pending`: what the overflow row stands for, by status. */
function hiddenSummary(hidden: readonly Task[]): string {
	const { completed, inProgress, pending } = counts(hidden);
	return ([
		[completed, "done"],
		[inProgress, "in progress"],
		[pending, "pending"],
	] as const)
		.filter(([count]) => count > 0)
		.map(([count, label]) => `+${count} ${label}`)
		.join(" ");
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
		if (renderTasks().length === 0 && !beadsSnapshot() && unclaimedParents().length === 0) {
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
		const tasks = renderTasks();
		const beads = beadsSnapshot();
		const idle = tasks.length === 0 && !beads;
		const parents = unclaimedParents();
		if (idle && parents.length === 0) return [];

		// Idle repositories show unclaimed roots in the same slot as the heading.
		// Otherwise the heading describes the complete list, before row filtering.
		const heading = truncateToWidth(
			idle ? theme.fg("dim", parents.map((parent) => parent.title).join(", ")) : headingLine(tasks, beads, theme),
			width,
			"…",
		);

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

		const lines = [heading];
		const strip = childStrip(beads, theme);
		if (strip) lines.push(truncateToWidth(strip, width, "…"));
		const { rows, hidden } = pickRows(tasks, MAX_ROWS - lines.length);
		rows.forEach((task, index) => {
			const branch = hidden.length === 0 && index === rows.length - 1 ? "└" : "├";
			lines.push(truncateToWidth(taskLine(task, branch, theme), width, "…"));
		});
		// Underlined so the overflow count does not read as another todo.
		if (hidden.length > 0) lines.push(`${theme.fg("dim", "└")} ${theme.underline(theme.fg("dim", hiddenSummary(hidden)))}`);
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
