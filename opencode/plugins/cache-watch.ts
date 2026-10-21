// Records why a turn missed the provider's prompt cache, like Pi's cache-watch.
// Server plugins can't show anything in Desktop without the model seeing it, so
// misses go to the server log and the session's `cacheMisses` metadata.
import { Plugin } from "@opencode/plugin/effect";
import { Effect, Stream } from "effect";
import { type Fingerprint, fingerprint, prefixChange } from "../../pi/extensions/lib/cache-prefix.ts";

// Anthropic's default cache lifetime: a longer idle gap explains a miss.
const TTL_MS = 5 * 60_000;

interface State {
	last?: Fingerprint;
	/** Why the request in flight rewrote the cached prefix, until its step ends. */
	pending?: string;
	requested?: number;
	ended?: number;
	/** Whether the provider reported cache use for the previous step. */
	cached?: boolean;
}

export default Plugin.define({
	id: "dotfiles.cache-watch",
	effect: Effect.fn(function* (ctx) {
		const sessions = new Map<string, State>();
		const state = (sessionID: string) => {
			let session = sessions.get(sessionID);
			if (!session) sessions.set(sessionID, (session = {}));
			return session;
		};

		yield* ctx.session.hook("http.request", (event) =>
			Effect.gen(function* () {
				const session = state(event.sessionID);
				// Compaction rewrites the conversation on purpose. Warming and title
				// requests are not turns: their last message never stays in history.
				if (event.kind === "compaction") session.last = undefined;
				if (event.kind !== "primary") return;
				const payload = yield* Effect.tryPromise(() => event.request.clone().json()).pipe(Effect.orElseSucceed(() => undefined));
				const next = fingerprint(payload);
				if (!next) return;
				session.pending = session.last && prefixChange(session.last, next);
				session.last = next;
				session.requested = Date.now();
			}),
		);

		const stepEnded = Effect.fn(function* (sessionID: string, tokens: { cache: { read: number; write: number } }) {
			const session = state(sessionID);
			const { pending, requested = Date.now(), ended = requested } = session;
			const idle = requested - ended;
			const reason = pending ?? (session.cached && tokens.cache.read === 0
				? idle >= TTL_MS ? `idle for ${Math.round(idle / 60_000)}m, past the cache lifetime` : "the request kept its prefix; the provider or proxy dropped the cache"
				: undefined);
			session.pending = undefined;
			session.ended = Date.now();
			session.cached = tokens.cache.read + tokens.cache.write > 0;
			if (!reason) return;

			yield* Effect.logWarning("prompt cache miss", { sessionID, reason });
			const info = yield* ctx.session.get({ sessionID });
			const misses = Array.isArray(info.metadata?.cacheMisses) ? info.metadata.cacheMisses : [];
			yield* ctx.session.update({
				sessionID,
				metadata: { ...info.metadata, cacheMisses: [...misses, { at: new Date().toISOString(), reason }].slice(-50) },
			});
		});

		yield* ctx.event.subscribe().pipe(
			Stream.runForEach((event) => {
				if (event.type === "session.step.failed") state(event.data.sessionID).pending = undefined;
				if (event.type !== "session.step.ended") return Effect.void;
				return stepEnded(event.data.sessionID, event.data.tokens).pipe(
					Effect.catchCause((cause) => Effect.logWarning("cache-watch failed", { cause })),
				);
			}),
			Effect.forkScoped({ startImmediately: true }),
		);
	}),
});
