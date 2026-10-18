/**
 * Host for pi-subagents 0.79.1's documented session-liveness/v1 integration
 * (docs/extension-api.md, src/integrations/pi-web-session-liveness.js).
 * Unlike RPC fleet counts this includes retained foreground nested descendants.
 * Install before session_start so the package registers its provider regardless
 * of extension order. No timers, SDK sessions, or artifact inspection live here.
 */
const REGISTRY = Symbol.for("@agegr/pi-web/session-liveness/v1");
export type ChildState = "active" | "idle" | "unknown";
type Provider = { name: string; sessionId: string; sessionFile?: string; isActive(): boolean };
type Host = {
	version: 1;
	register(provider: Provider): () => void;
	// Host-owned read API, not a read of pi-subagents' internal state.
	dotfilesSubagentState(sessionId: string): ChildState;
};

export function createLivenessHost(): Host {
	const providers = new Map<string, Provider>();
	return {
		version: 1,
		register(provider) {
			const key = JSON.stringify([provider.sessionId, provider.name]);
			providers.set(key, provider);
			return () => {
				if (providers.get(key) === provider) providers.delete(key);
			};
		},
		dotfilesSubagentState(sessionId) {
			const provider = providers.get(JSON.stringify([sessionId, "pi-subagents"]));
			if (!provider) return "unknown";
			try {
				const active = provider.isActive();
				return active === true ? "active" : active === false ? "idle" : "unknown";
			} catch {
				return "unknown";
			}
		},
	};
}

export function installSubagentLivenessHost(): (sessionId: string) => ChildState {
	const globals = globalThis as Record<symbol, unknown>;
	// Never replace another host's registry (for example a real pi-web host).
	globals[REGISTRY] ??= createLivenessHost();
	const host = globals[REGISTRY] as Partial<Host>;
	return (sessionId) => host?.version === 1 && typeof host.dotfilesSubagentState === "function"
		? host.dotfilesSubagentState(sessionId)
		: "unknown";
}

export function titleAnimation(waiting: boolean, parentWorking: boolean, children: ChildState) {
	return waiting ? "waiting" : parentWorking || children === "active" ? "working" : "idle";
}

export function restoreBlockReason(state: ChildState): string | undefined {
	if (state === "active") return "stop running subagents before restoring repository state";
	if (state === "unknown") return "subagent state is unknown; refusing to restore repository state";
	return undefined;
}
