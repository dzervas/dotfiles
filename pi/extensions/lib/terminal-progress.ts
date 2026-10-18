const ACTIVE_SEQUENCE = "\x1b]9;4;3\x07";
const CLEAR_SEQUENCE = "\x1b]9;4;0;\x07";
const KEEPALIVE_MS = 1000;

/** Coordinates Ghostty terminal-tab activity across background extensions. */
export class TerminalActivity {
	private readonly activeSources = new Set<string>();
	private interval?: ReturnType<typeof setInterval>;
	private signaledActive = false;

	constructor(private readonly write: (data: string) => void = (data) => process.stdout.write(data)) {}

	setActive(source: string, active: boolean, clearWhenInactive = true): void {
		if (active) {
			this.activeSources.add(source);
			if (this.interval) return;
			this.write(ACTIVE_SEQUENCE);
			this.signaledActive = true;
			this.interval = setInterval(() => this.write(ACTIVE_SEQUENCE), KEEPALIVE_MS);
			return;
		}

		this.activeSources.delete(source);
		if (this.activeSources.size > 0) return;
		if (this.interval) {
			clearInterval(this.interval);
			this.interval = undefined;
		}
		if (clearWhenInactive && this.signaledActive) {
			this.write(CLEAR_SEQUENCE);
			this.signaledActive = false;
		}
	}

	isActive(): boolean {
		return this.activeSources.size > 0;
	}

	refresh(): void {
		if (this.interval) this.write(ACTIVE_SEQUENCE);
	}
}

// Pi loads each extension with its own module cache. Keep the coordinator on
// the process global so background Bash and the title spinner see the same
// activity, including across extension reloads.
const REGISTRY_KEY = Symbol.for("dzervas.pi.terminal-activity");
const globals = globalThis as typeof globalThis & { [REGISTRY_KEY]?: TerminalActivity };
export const terminalActivity = globals[REGISTRY_KEY] ??= new TerminalActivity();
