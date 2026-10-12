/**
 * cache-watch — warn when a request rewrites the cached prompt prefix.
 *
 * Pi's own cache-miss notices (`showCacheMissNotices`) report a miss after the
 * response, from usage. This names the cause before the request goes out: the
 * first part of the prompt (tools, system prompt, or a message) that no longer
 * matches the previous request. The warning is a custom entry, so it renders in
 * the transcript like pi's notices but never reaches the model.
 *
 * Only pi's outgoing payload is visible here; a miss caused further along (a
 * proxy rewriting the request, cache expiry) still gets pi's notice alone.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Container, Spacer, Text } from "@earendil-works/pi-tui";
import { type Fingerprint, fingerprint, prefixChange } from "./lib/cache-prefix.ts";

const ENTRY = "cache-watch";

interface CacheWatchData {
	reason: string;
	/** What happened in the session just before, when known (reload, tree navigation, ...). */
	after?: string;
}

interface SessionState {
	last?: Fingerprint;
	after?: string;
	/** Set while compaction or tree navigation runs; their summary requests are not turns. */
	paused?: boolean;
}

// On globalThis so the last fingerprint survives `/reload`, which re-evaluates
// this module in the same process: a reload is a common reason the prefix moves.
const STATE_KEY = Symbol.for("dzervas.pi.cache-watch");
const store = ((globalThis as Record<symbol, unknown>)[STATE_KEY] ??= new Map()) as Map<string, SessionState>;

export default function cacheWatch(pi: ExtensionAPI): void {
	const state = (ctx: ExtensionContext) => {
		const id = ctx.sessionManager.getSessionId();
		let entry = store.get(id);
		if (!entry) store.set(id, (entry = {}));
		return entry;
	};

	pi.registerEntryRenderer<CacheWatchData>(ENTRY, (entry, _options, theme) => {
		const data = entry.data;
		if (!data) return undefined;
		const after = data.after ? ` (after ${data.after})` : "";
		// Same shape as pi's cache-miss notice: a spacer, then one warning line.
		const notice = new Container();
		notice.addChild(new Spacer(1));
		notice.addChild(new Text(theme.fg("warning", `Cache prefix changed${after}: ${data.reason}`), 1, 0));
		return notice;
	});

	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup" && event.reason !== "new") state(ctx).after = event.reason;
	});
	pi.on("session_before_tree", (_event, ctx) => {
		state(ctx).paused = true;
	});
	pi.on("session_tree", (_event, ctx) => {
		const session = state(ctx);
		session.paused = false;
		session.after = "tree navigation";
	});
	// Compaction rewrites the conversation on purpose: forget the prefix instead
	// of reporting the expected change.
	pi.on("session_before_compact", (_event, ctx) => {
		state(ctx).paused = true;
	});
	pi.on("session_compact", (_event, ctx) => {
		store.set(ctx.sessionManager.getSessionId(), {});
	});
	// A cancelled compaction or navigation never reports back; resume watching
	// once the agent run that followed it ends.
	pi.on("agent_end", (_event, ctx) => {
		state(ctx).paused = false;
	});
	pi.on("session_shutdown", (event, ctx) => {
		// A reload starts the same session again; keep its prefix to compare.
		if (event.reason !== "reload") store.delete(ctx.sessionManager.getSessionId());
	});

	pi.on("before_provider_request", (event, ctx) => {
		if (!ctx.hasUI) return;
		const session = state(ctx);
		if (session.paused) return;
		const next = fingerprint(event.payload);
		if (!next) return;
		const reason = session.last && prefixChange(session.last, next);
		if (reason) pi.appendEntry<CacheWatchData>(ENTRY, { reason, after: session.after });
		session.last = next;
		session.after = undefined;
	});
}
