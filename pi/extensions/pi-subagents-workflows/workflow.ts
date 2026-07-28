import Ajv from "ajv";
import { getSubagentsService } from "@gotgenes/pi-subagents";
import type { ParsedWorkflow, WorkflowRuntime } from "./runtime";

export type WorkflowStatus = "running" | "completed" | "failed" | "stopped";

export interface ToolInvoker {
	invoke(name: string, args: unknown, signal: AbortSignal): Promise<unknown>;
}

export interface WorkflowStartOptions {
	args?: Record<string, unknown>;
	concurrency?: number;
	maxAgents?: number;
	cwd: string;
	onUpdate?: (text: string) => void;
	signal?: AbortSignal;
}

export interface WorkflowRecord {
	id: string;
	name: string;
	description: string;
	status: WorkflowStatus;
	phase?: string;
	logs: string[];
	agentCount: number;
	result?: unknown;
	error?: string;
}

export interface StartedWorkflow extends WorkflowRecord {
	done: Promise<WorkflowRecord>;
}

type AgentOptions = {
	agentType?: string;
	model?: string;
	thinking?: string;
	label?: string;
	maxTurns?: number;
	schema?: object | boolean;
	schemaRetries?: number;
};

const terminalAgentStatuses = new Set(["completed", "steered", "stopped", "aborted", "error"]);
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

class Limiter {
	private active = 0;
	private readonly pending: Array<() => void> = [];

	constructor(private readonly limit: number) {}

	async run<T>(task: () => Promise<T>): Promise<T> {
		await new Promise<void>((resolve) => {
			if (this.active < this.limit) {
				this.active++;
				resolve();
			} else {
				this.pending.push(() => {
					this.active++;
					resolve();
				});
			}
		});
		try {
			return await task();
		} finally {
			this.active--;
			this.pending.shift()?.();
		}
	}
}

function agentOptions(value: unknown): AgentOptions {
	if (value === undefined) return {};
	if (!value || typeof value !== "object" || Array.isArray(value)) {
		throw new Error("agent options must be an object.");
	}
	return value as AgentOptions;
}

function formatError(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

function parseJsonOutput(output: string): unknown {
	const fenced = output.match(/^```(?:json)?\s*\n([\s\S]*?)\n```$/i);
	return JSON.parse((fenced?.[1] ?? output).trim());
}

class WorkflowRun {
	readonly record: WorkflowRecord;
	readonly done: Promise<WorkflowRecord>;
	private readonly limiter: Limiter;
	private readonly agentIds = new Set<string>();
	private stopped = false;
	private readonly controller = new AbortController();

	constructor(
		private readonly workflow: ParsedWorkflow,
		private readonly runtime: WorkflowRuntime,
		private readonly toolInvoker: ToolInvoker,
		private readonly options: Required<Pick<WorkflowStartOptions, "args" | "cwd">> & {
			concurrency: number;
			maxAgents: number;
			onUpdate?: (text: string) => void;
			signal?: AbortSignal;
		},
		id: string,
	) {
		this.record = {
			id,
			name: workflow.meta.name,
			description: workflow.meta.description,
			status: "running",
			logs: [],
			agentCount: 0,
		};
		this.limiter = new Limiter(options.concurrency);
		if (options.signal?.aborted) this.stop();
		else options.signal?.addEventListener("abort", () => this.stop(), { once: true });
		this.done = this.execute();
	}

	stop(): void {
		if (this.record.status !== "running") return;
		this.stopped = true;
		this.record.status = "stopped";
		this.controller.abort();
		for (const id of this.agentIds) getSubagentsService()?.abort(id);
		this.update("stopped");
	}

	private update(text: string): void {
		this.options.onUpdate?.(`${this.record.name}: ${text}`);
	}

	private log(message: string): void {
		this.record.logs.push(message);
		this.update(message);
	}

	private async execute(): Promise<WorkflowRecord> {
		try {
			this.update("running");
			this.record.result = await this.runtime.execute(this.workflow, {
				args: this.options.args,
				cwd: this.options.cwd,
				phase: (title) => {
					this.record.phase = title;
					this.update(`phase: ${title}`);
				},
				log: (message) => this.log(message),
				agent: (prompt, rawOptions) => this.invokeAgent(prompt, agentOptions(rawOptions)),
				tool: (name, args) => this.toolInvoker.invoke(name, args ?? {}, this.controller.signal),
			});
			if (!this.stopped) {
				this.record.status = "completed";
				this.update("completed");
			}
		} catch (error) {
			if (!this.stopped) {
				this.record.status = "failed";
				this.record.error = formatError(error);
				this.update(`failed: ${this.record.error}`);
			}
		}
		return this.record;
	}

	private async invokeAgent(prompt: string, options: AgentOptions): Promise<unknown> {
		const retries = options.schema === undefined
			? 0
			: Math.min(Math.max(Math.floor(options.schemaRetries ?? 2), 0), 5);
		const ajv = new Ajv({ allErrors: true });
		const validate = options.schema === undefined ? undefined : ajv.compile(options.schema);
		let validationError = "";
		for (let attempt = 0; attempt <= retries; attempt++) {
			const retryNote = validationError
				? `\n\nYour previous output was invalid (${validationError}). Return only valid JSON matching the schema.`
				: "";
			const result = await this.limiter.run(() => this.spawnAgent(prompt + retryNote, options));
			if (!validate) return result;
			try {
				const parsed = parseJsonOutput(result);
				if (validate(parsed)) return parsed;
				validationError = ajv.errorsText(validate.errors);
			} catch (error) {
				validationError = `invalid JSON: ${formatError(error)}`;
			}
			this.log(`agent output did not match schema (${validationError})`);
		}
		throw new Error(`Agent schema validation failed after ${retries + 1} attempt(s): ${validationError}`);
	}

	private async spawnAgent(prompt: string, options: AgentOptions): Promise<string> {
		if (this.stopped) throw new Error("Workflow stopped.");
		if (this.record.agentCount >= this.options.maxAgents) {
			throw new Error(`Workflow reached its maxAgents limit (${this.options.maxAgents}).`);
		}
		const service = getSubagentsService();
		if (!service) throw new Error("@gotgenes/pi-subagents is not active in this session.");

		this.record.agentCount++;
		const schemaInstruction = options.schema === undefined
			? ""
			: `\n\nReturn only a JSON value matching this JSON Schema:\n${JSON.stringify(options.schema)}`;
		const id = service.spawn(options.agentType ?? "general-purpose", prompt + schemaInstruction, {
			description: options.label ?? prompt.slice(0, 80),
			model: options.model,
			thinkingLevel: options.thinking,
			maxTurns: options.maxTurns,
			foreground: true,
		});
		this.agentIds.add(id);
		this.update(`agent ${this.record.agentCount} running`);

		while (true) {
			const record = service.getRecord(id);
			if (!record) throw new Error(`Subagent ${id} disappeared.`);
			if (terminalAgentStatuses.has(record.status)) {
				this.agentIds.delete(id);
				if (record.status === "completed" || record.status === "steered") {
					this.update(`agent ${this.record.agentCount} completed`);
					return record.result ?? "";
				}
				throw new Error(record.error ?? `Subagent ${id} ended with status ${record.status}.`);
			}
			await sleep(100);
		}
	}
}

/** Small in-memory workflow manager. State intentionally lasts only for this Pi session. */
export class WorkflowManager {
	private nextId = 1;
	private readonly runs = new Map<string, WorkflowRun>();

	constructor(
		private readonly runtime: WorkflowRuntime,
		private readonly toolInvoker: ToolInvoker,
	) {}

	start(workflow: ParsedWorkflow, options: WorkflowStartOptions): StartedWorkflow {
		const concurrency = Math.max(1, Math.floor(options.concurrency ?? 4));
		const maxAgents = Math.max(1, Math.floor(options.maxAgents ?? 100));
		const id = `workflow-${this.nextId++}`;
		const run = new WorkflowRun(workflow, this.runtime, this.toolInvoker, {
			args: options.args ?? {},
			cwd: options.cwd,
			concurrency,
			maxAgents,
			onUpdate: options.onUpdate,
			signal: options.signal,
		}, id);
		this.runs.set(id, run);
		return { ...run.record, done: run.done };
	}

	list(): WorkflowRecord[] {
		return [...this.runs.values()].map((run) => run.record);
	}

	status(id: string): WorkflowRecord | undefined {
		return this.runs.get(id)?.record;
	}

	stop(id: string): WorkflowRecord | undefined {
		const run = this.runs.get(id);
		run?.stop();
		return run?.record;
	}

	stopAll(): void {
		for (const run of this.runs.values()) run.stop();
	}
}
