import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getPrompt } from "../lib/prompts.ts";
import { diffNotes, type Note, type Scope } from "./store.ts";

export type MemoryData = ReadonlyMap<Scope, { namespace: string; notes: Note[] }>;

/** Parent-owned baseline; observations may contain only the scope that was written. */
export function createMemoryMonitor(
	pi: Pick<ExtensionAPI, "sendMessage">,
	read: (ctx: ExtensionContext, signal: AbortSignal) => Promise<MemoryData>,
) {
	let owner: ExtensionContext | undefined;
	let sessionId: string | undefined;
	let baseline = new Map<Scope, { namespace: string; notes: Note[] }>();
	let timer: ReturnType<typeof setInterval> | undefined;
	let controller: AbortController | undefined;
	let revision = 0;

	function update(data: MemoryData, notify: boolean) {
		const sections: string[] = [];
		for (const [scope, value] of data) {
			const previous = baseline.get(scope);
			const diff = previous ? diffNotes(previous.notes, value.notes) : "";
			if (notify && diff) sections.push(getPrompt("memory", "changed-section", { scope, namespace: value.namespace, diff }));
			baseline.set(scope, { namespace: value.namespace, notes: value.notes.map((note) => ({ ...note })) });
		}
		// Pi appends at turn-end while running; never start a new turn. isIdle()
		// also becomes false during compaction, so it is not a safe trigger gate.
		if (sections.length && owner) pi.sendMessage({
			customType: "memory-changed",
			content: getPrompt("memory", "changed-notice", { changes: sections.join("\n\n") }),
			display: true,
		}, { triggerTurn: false });
	}

	function stop() {
		if (timer !== undefined) clearInterval(timer);
		timer = undefined;
		controller?.abort();
		controller = undefined;
		owner = undefined;
		sessionId = undefined;
		baseline.clear();
		revision++;
	}

	return {
		start(ctx: ExtensionContext, initial?: MemoryData) {
			stop();
			if (ctx.mode !== "tui") return;
			owner = ctx;
			sessionId = ctx.sessionManager.getSessionId();
			if (initial) update(initial, false);
			timer = setInterval(async () => {
				if (controller) return;
				const pending = new AbortController();
				controller = pending;
				const version = revision;
				try {
					const data = await read(ctx, pending.signal);
					// A write observed during this read supersedes its potentially stale result.
					if (!pending.signal.aborted && revision === version) update(data, true);
				} catch {
					if (!pending.signal.aborted && owner === ctx) ctx.ui.notify("Memory refresh failed; will retry.", "warning");
				} finally {
					if (controller === pending) controller = undefined;
				}
			}, 30_000);
			timer.unref?.();
		},
		observe(id: string, data: MemoryData) {
			if (!owner || sessionId !== id) return;
			revision++;
			update(data, true);
		},
		stop,
	};
}
