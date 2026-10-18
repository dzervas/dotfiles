export const PI_SANDBOX_STATE_KEY = Symbol.for("dzervas.pi.sandbox");
export const PI_SANDBOX_STATE_EVENT = "sandbox:state";
type SandboxState = { enabled?: boolean };

/** Sandbox state is published only by the loaded sandbox extension. */
export function isSandboxed(): boolean {
	const globals = globalThis as Record<PropertyKey, unknown>;
	return Boolean(
		(globals.__DZERVAS_PI_SANDBOX__ as SandboxState | undefined)?.enabled ||
		(globals[PI_SANDBOX_STATE_KEY] as SandboxState | undefined)?.enabled,
	);
}
