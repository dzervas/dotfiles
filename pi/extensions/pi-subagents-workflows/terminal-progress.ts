const ACTIVE_SEQUENCE = "\x1b]9;4;3\x07";
const CLEAR_SEQUENCE = "\x1b]9;4;0;\x07";
const KEEPALIVE_MS = 1000;

/** Keeps Ghostty's terminal-tab activity indicator alive while Pi itself is idle. */
export class WorkflowTerminalProgress {
	private interval?: ReturnType<typeof setInterval>;

	constructor(private readonly write: (data: string) => void = (data) => process.stdout.write(data)) {}

	setActive(active: boolean, clearWhenInactive = true): void {
		if (active) {
			if (this.interval) return;
			this.write(ACTIVE_SEQUENCE);
			this.interval = setInterval(() => this.write(ACTIVE_SEQUENCE), KEEPALIVE_MS);
			return;
		}

		if (!this.interval) return;
		clearInterval(this.interval);
		this.interval = undefined;
		if (clearWhenInactive) this.write(CLEAR_SEQUENCE);
	}

	refresh(): void {
		if (this.interval) this.write(ACTIVE_SEQUENCE);
	}
}
