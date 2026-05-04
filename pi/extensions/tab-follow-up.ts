import { CustomEditor, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

type QueueItem = {
	text: string;
};

const WIDGET_KEY = "tab-follow-up";

function formatCount(count: number) {
	return `${count} queued after-turn message${count === 1 ? "" : "s"}`;
}

function installWidget(ctx: ExtensionContext, queue: QueueItem[]) {
	if (queue.length === 0) {
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		return;
	}

	ctx.ui.setWidget(
		WIDGET_KEY,
		(_tui, theme) => ({
			invalidate() {},
			render(width: number) {
				const title = theme.fg("dim", `↳ ${formatCount(queue.length)} (alt+up/down to edit)`);
				const preview = queue
					.map((item, index) => {
						const oneLine = item.text.replace(/\s+/g, " ").trim();
						return theme.fg("dim", `${index + 1}. ${truncateToWidth(oneLine, Math.max(10, width - 4))}`);
					})
					.slice(0, 3);
				return [title, ...preview];
			},
		}),
		{ placement: "belowEditor" },
	);
}

function queueText(ctx: ExtensionContext, queue: QueueItem[], text: string) {
	queue.push({ text });
	installWidget(ctx, queue);
}

function restoreQueueToEditor(ctx: ExtensionContext, queue: QueueItem[]) {
	if (queue.length === 0) return false;

	const queuedText = queue.map((item) => item.text).join("\n\n");
	queue.length = 0;
	installWidget(ctx, queue);

	const currentText = ctx.ui.getEditorText().trim();
	ctx.ui.setEditorText([queuedText, currentText].filter(Boolean).join("\n\n"));
	return true;
}

export default function tabFollowUp(pi: ExtensionAPI) {
	const queue: QueueItem[] = [];
	let currentCtx: ExtensionContext | undefined;
	let flushScheduled = false;

	function scheduleFlush(delayMs = 0) {
		if (flushScheduled || queue.length === 0) return;
		flushScheduled = true;

		setTimeout(() => {
			flushScheduled = false;
			if (queue.length === 0) return;
			if (!currentCtx) return;
			if (!currentCtx.isIdle()) {
				scheduleFlush(50);
				return;
			}

			const item = queue.shift();
			if (!item) return;
			installWidget(currentCtx, queue);
			pi.sendUserMessage(item.text);
		}, delayMs);
	}

	class TabFollowUpEditor extends CustomEditor {
		handleInput(data: string): void {
			const ctx = currentCtx;
			const text = (this.getExpandedText?.() ?? this.getText()).trim();

			if ((matchesKey(data, "alt+up") || matchesKey(data, "alt+down")) && ctx && queue.length > 0) {
				restoreQueueToEditor(ctx, queue);
				this.tui.requestRender();
				return;
			}

			if (matchesKey(data, "tab") && ctx && !ctx.isIdle() && text.length > 0) {
				this.addToHistory(text);
				this.setText("");
				queueText(ctx, queue, text);
				this.tui.requestRender();
				return;
			}

			super.handleInput(data);
		}
	}

	pi.on("session_start", (_event, ctx) => {
		currentCtx = ctx;
		installWidget(ctx, queue);
		ctx.ui.setEditorComponent((tui, theme, keybindings) => new TabFollowUpEditor(tui, theme, keybindings));
	});

	pi.on("agent_end", () => {
		scheduleFlush();
	});

	pi.on("session_shutdown", (_event, ctx) => {
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		if (currentCtx === ctx) currentCtx = undefined;
	});
}
