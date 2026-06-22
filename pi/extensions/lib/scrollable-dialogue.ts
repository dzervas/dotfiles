import { highlightCode, type Theme } from "@earendil-works/pi-coding-agent";
import {
	Editor,
	type EditorTheme,
	Key,
	matchesKey,
	type TUI,
	truncateToWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

export interface DialogueOption {
	value: string;
	label: string;
	description?: string;
	// When true, pressing Tab on this option opens a message editor and the
	// entered text is returned alongside the option value.
	allowMessage?: boolean;
}

export interface DialogueResult {
	value: string;
	message?: string;
}

export interface ScrollableDialogueOptions {
	title?: string;
	// Body text shown in a viewport. When `language` is set it is
	// syntax-highlighted via highlightCode; otherwise it is shown as-is.
	// Long lines are wrapped; the viewport only scrolls when the wrapped body
	// would exceed the available terminal height.
	body: string;
	language?: string;
	reason?: string;
	options: DialogueOption[];
	// Hard cap on visible body rows. Defaults to "fit the terminal height".
	maxBodyLines?: number;
	messagePrompt?: string;
}

// A self-contained component for ctx.ui.custom: a syntax-highlighted, line-wrapped
// body above a keyboard-navigable option list. The body viewport is sized to the
// terminal height so short commands render in full; only bodies taller than the
// screen scroll (PgUp/PgDn). Pressing Tab on an option flagged `allowMessage`
// swaps the list for a message editor.
export class ScrollableDialogue {
	private readonly sourceLines: string[];
	private scroll = 0;
	private selected = 0;
	private inputMode = false;
	private readonly editor: Editor;
	private cachedLines?: string[];
	private cachedWidth?: number;
	// Wrapped body lines, cached per width since wrapping is width-dependent.
	private wrapCache?: { width: number; lines: string[] };
	// Last computed viewport, used by handleInput for page sizing / clamping.
	private viewport = { total: 0, visible: 0 };

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly opts: ScrollableDialogueOptions,
		private readonly done: (result: DialogueResult | null) => void,
	) {
		this.sourceLines = opts.language
			? highlightCode(opts.body, opts.language)
			: opts.body.split("\n");
		while (this.sourceLines.at(-1)?.trim() === "") this.sourceLines.pop();

		const editorTheme: EditorTheme = {
			borderColor: (s) => theme.fg("accent", s),
			selectList: {
				selectedPrefix: (t) => theme.fg("accent", t),
				selectedText: (t) => theme.fg("accent", t),
				description: (t) => theme.fg("muted", t),
				scrollInfo: (t) => theme.fg("dim", t),
				noMatch: (t) => theme.fg("warning", t),
			},
		};
		this.editor = new Editor(tui, editorTheme);
		this.editor.focused = true;
		this.editor.onSubmit = (value) => {
			this.done({ value: this.opts.options[this.selected].value, message: value.trim() || undefined });
		};
	}

	private refresh() {
		this.cachedLines = undefined;
		this.tui.requestRender();
	}

	// Wrap each highlighted source line to the body width (reserving 1 col for
	// the leading indent), preserving ANSI colour codes. Cached per width.
	private wrappedLines(bodyWidth: number): string[] {
		if (this.wrapCache?.width === bodyWidth) return this.wrapCache.lines;
		const lines: string[] = [];
		for (const line of this.sourceLines) {
			const wrapped = wrapTextWithAnsi(line, bodyWidth);
			if (wrapped.length === 0) lines.push("");
			else lines.push(...wrapped);
		}
		this.wrapCache = { width: bodyWidth, lines };
		return lines;
	}

	private maxScroll() {
		return Math.max(0, this.viewport.total - this.viewport.visible);
	}

	handleInput(data: string): void {
		if (this.inputMode) {
			if (matchesKey(data, Key.escape)) {
				this.inputMode = false;
				this.editor.setText("");
				this.refresh();
				return;
			}
			this.editor.handleInput(data);
			this.refresh();
			return;
		}

		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.done(null);
			return;
		}

		// Body scrolling (only meaningful when the body overflows the viewport)
		const page = Math.max(1, this.viewport.visible);
		if (matchesKey(data, Key.pageUp)) {
			this.scroll = Math.max(0, this.scroll - page);
			this.refresh();
			return;
		}
		if (matchesKey(data, Key.pageDown)) {
			this.scroll = Math.min(this.maxScroll(), this.scroll + page);
			this.refresh();
			return;
		}

		// Option navigation
		if (matchesKey(data, Key.up)) {
			this.selected = Math.max(0, this.selected - 1);
			this.refresh();
			return;
		}
		if (matchesKey(data, Key.down)) {
			this.selected = Math.min(this.opts.options.length - 1, this.selected + 1);
			this.refresh();
			return;
		}

		// Tab → message editor for options that allow it
		if (matchesKey(data, Key.tab) && this.opts.options[this.selected]?.allowMessage) {
			this.inputMode = true;
			this.editor.setText("");
			this.refresh();
			return;
		}

		if (matchesKey(data, Key.enter)) {
			this.done({ value: this.opts.options[this.selected].value });
		}
	}

	// Chrome rendered below the body: reason, options (or message editor), help.
	private buildFooter(width: number): string[] {
		const th = this.theme;
		const out: string[] = [];
		const add = (s: string) => out.push(truncateToWidth(s, width));

		out.push("");
		if (this.opts.reason) {
			add(th.fg("muted", ` ${this.opts.reason}`));
			out.push("");
		}

		if (this.inputMode) {
			add(th.fg("muted", ` ${this.opts.messagePrompt ?? "Message:"}`));
			for (const line of this.editor.render(width - 2)) add(` ${line}`);
			out.push("");
			add(th.fg("dim", " Enter to send • Esc to go back"));
		} else {
			for (let i = 0; i < this.opts.options.length; i++) {
				const opt = this.opts.options[i];
				const selected = i === this.selected;
				const prefix = selected ? th.fg("accent", "> ") : "  ";
				const color = selected ? "accent" : "text";
				const hint = opt.allowMessage ? th.fg("dim", " (Tab: + message)") : "";
				add(prefix + th.fg(color, opt.label) + (selected ? hint : ""));
				if (opt.description) add(`     ${th.fg("muted", opt.description)}`);
			}
			out.push("");
			const scrollHelp = this.maxScroll() > 0 ? "PgUp/PgDn scroll • " : "";
			add(th.fg("dim", ` ${scrollHelp}↑↓ select • Enter confirm • Tab message • Esc cancel`));
		}
		add(th.fg("accent", "─".repeat(width)));
		return out;
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;

		const th = this.theme;
		const wrapped = this.wrappedLines(width - 1);

		// Header chrome
		const header: string[] = [];
		header.push(truncateToWidth(th.fg("accent", "─".repeat(width)), width));
		if (this.opts.title) {
			header.push(truncateToWidth(th.fg("accent", th.bold(` ${this.opts.title}`)), width));
			header.push("");
		}

		// Footer chrome (built first so the body can claim the remaining height)
		const footer = this.buildFooter(width);

		// Size the body viewport to whatever vertical space is left on screen.
		// Reserve 2 rows for the scroll indicators so toggling them never reflows.
		const termRows = process.stdout.rows && process.stdout.rows > 0 ? process.stdout.rows : 40;
		const cap = this.opts.maxBodyLines ?? Number.POSITIVE_INFINITY;
		const budget = termRows - header.length - footer.length - 2;
		const visible = Math.min(wrapped.length, Math.max(3, budget), cap);

		this.viewport = { total: wrapped.length, visible };
		this.scroll = Math.min(this.scroll, this.maxScroll());

		const windowLines = wrapped.slice(this.scroll, this.scroll + visible);
		const hiddenAbove = this.scroll;
		const hiddenBelow = Math.max(0, wrapped.length - this.scroll - visible);

		const lines: string[] = [...header];
		if (hiddenAbove > 0)
			lines.push(th.fg("dim", `  ↑ ${hiddenAbove} more line${hiddenAbove === 1 ? "" : "s"}`));
		for (const line of windowLines) lines.push(truncateToWidth(` ${line}`, width));
		if (hiddenBelow > 0)
			lines.push(th.fg("dim", `  ↓ ${hiddenBelow} more line${hiddenBelow === 1 ? "" : "s"}`));
		lines.push(...footer);

		this.cachedLines = lines;
		this.cachedWidth = width;
		return lines;
	}

	invalidate(): void {
		this.cachedLines = undefined;
		this.wrapCache = undefined;
		this.editor.invalidate();
	}
}
