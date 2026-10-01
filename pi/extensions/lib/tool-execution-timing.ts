type RenderContext = {
	toolCallId: string;
	state: Record<string, unknown>;
	executionStarted: boolean;
};

/** Pi's execution-start event precedes permission checks; time the actual execute instead. */
export class ToolExecutionTiming {
	private readonly pending = new Map<string, number>();

	constructor(private readonly now: () => number = Date.now) {}

	start(toolCallId: string): void {
		this.pending.set(toolCallId, this.now());
	}

	context<T extends RenderContext>(context: T): T {
		const startedAt = this.pending.get(context.toolCallId);
		if (startedAt !== undefined) {
			context.state.startedAt = startedAt;
			this.pending.delete(context.toolCallId);
		}
		return { ...context, executionStarted: typeof context.state.startedAt === "number" };
	}

	clear(): void {
		this.pending.clear();
	}
}
