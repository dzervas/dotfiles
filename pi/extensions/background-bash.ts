import { StringEnum } from "@earendil-works/pi-ai";
import {
	createBashToolDefinition,
	type BashToolDetails,
	type ExtensionAPI,
	type ExtensionCommandContext,
	type ExtensionContext,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { ScrollableDialogue } from "./lib/scrollable-dialogue";
import { terminalActivity } from "./pi-subagents-workflows/terminal-progress";

const REGISTRY_KEY = Symbol.for("dzervas.pi.background-jobs");

type JobStatus = "running" | "stopping" | "completed" | "failed" | "stopped";

type Job = {
	id: number;
	command: string;
	cwd: string;
	status: JobStatus;
	controller: AbortController;
	output: string;
	details?: BashToolDetails;
	error?: string;
	startedAt: number;
	endedAt?: number;
};

type JobRegistry = {
	nextId: number;
	jobs: Map<number, Job>;
};

type ProcessRegistry = {
	sessions: Map<string, JobRegistry>;
	legacy?: JobRegistry;
};

function getProcessRegistry(): ProcessRegistry {
	const global = globalThis as Record<PropertyKey, unknown>;
	const existing = global[REGISTRY_KEY] as ProcessRegistry | JobRegistry | undefined;
	if (existing && "sessions" in existing && existing.sessions instanceof Map) return existing;

	const registry: ProcessRegistry = {
		sessions: new Map(),
		legacy: existing && "jobs" in existing && existing.jobs instanceof Map ? existing : undefined,
	};
	global[REGISTRY_KEY] = registry;
	return registry;
}

function getSessionRegistry(processRegistry: ProcessRegistry, sessionId: string): JobRegistry {
	const existing = processRegistry.sessions.get(sessionId);
	if (existing) return existing;
	const registry = processRegistry.legacy ?? { nextId: 1, jobs: new Map() };
	processRegistry.legacy = undefined;
	processRegistry.sessions.set(sessionId, registry);
	return registry;
}

function resultText(content: Array<{ type: string; text?: string }>): string {
	return content
		.filter((part) => part.type === "text")
		.map((part) => part.text ?? "")
		.join("\n");
}

function duration(job: Job): string {
	const seconds = ((job.endedAt ?? Date.now()) - job.startedAt) / 1000;
	return `${seconds.toFixed(1)}s`;
}

function commandPreview(command: string): string {
	const singleLine = command.replace(/\s+/gu, " ").trim();
	return singleLine.length > 72 ? `${singleLine.slice(0, 69)}...` : singleLine;
}

function jobLabel(job: Job): string {
	return `${job.status.padEnd(9)} #${job.id}  ${duration(job)}  ${commandPreview(job.command)}`;
}

function formatJobs(registry: JobRegistry): string {
	const jobs = [...registry.jobs.values()].sort((left, right) => right.id - left.id);
	if (jobs.length === 0) return "No background jobs.";
	return jobs.map(jobLabel).join("\n");
}

function requireJob(registry: JobRegistry, id: number | undefined): Job {
	if (typeof id !== "number" || !Number.isInteger(id))
		throw new Error("A valid background job ID is required");
	const job = registry.jobs.get(id);
	if (!job) throw new Error(`Background job #${id} does not exist`);
	return job;
}

function inspectJob(job: Job): string {
	const header = [
		`Job #${job.id} — ${job.status}`,
		`Command: ${job.command}`,
		`Directory: ${job.cwd}`,
		`Duration: ${duration(job)}`,
	];
	if (job.details?.fullOutputPath) header.push(`Full output: ${job.details.fullOutputPath}`);
	const body = job.output || "(no output yet)";
	const error = job.error ? `\n\nError: ${job.error}` : "";
	return `${header.join("\n")}\n\n${body}${error}`;
}

function stopJob(job: Job): string {
	if (job.status !== "running") return `Background job #${job.id} is ${job.status}.`;
	job.status = "stopping";
	job.controller.abort();
	return `Stopping background job #${job.id}.`;
}

function isJobFinished(job: Job): boolean {
	return job.status !== "running" && job.status !== "stopping";
}

function waitForJob(job: Job, timeoutSeconds: number | undefined, signal?: AbortSignal): Promise<boolean> {
	if (isJobFinished(job)) return Promise.resolve(true);
	if (signal?.aborted) return Promise.reject(new Error(`Waiting for background job #${job.id} was cancelled`));

	return new Promise((resolve, reject) => {
		let timeout: ReturnType<typeof setTimeout> | undefined;
		const interval = setInterval(() => {
			if (isJobFinished(job)) finish(true);
		}, 100);
		const onAbort = () => finish(false, new Error(`Waiting for background job #${job.id} was cancelled`));
		const finish = (completed: boolean, error?: Error) => {
			clearInterval(interval);
			if (timeout) clearTimeout(timeout);
			signal?.removeEventListener("abort", onAbort);
			if (error) reject(error);
			else resolve(completed);
		};

		signal?.addEventListener("abort", onAbort, { once: true });
		if (timeoutSeconds !== undefined) {
			timeout = setTimeout(() => finish(false), timeoutSeconds * 1000);
		}
	});
}

function createDelegate(ctx: ExtensionContext) {
	const settings = SettingsManager.create(ctx.cwd, undefined, {
		projectTrusted: ctx.isProjectTrusted(),
	});
	return createBashToolDefinition(ctx.cwd, {
		commandPrefix: settings.getShellCommandPrefix(),
		shellPath: settings.getShellPath(),
	});
}

async function showInspection(ctx: ExtensionCommandContext, job: Job): Promise<void> {
	if (ctx.mode !== "tui") {
		ctx.ui.notify(inspectJob(job), job.status === "failed" ? "error" : "info");
		return;
	}
	await ctx.ui.custom((tui, theme, _keybindings, done) =>
		new ScrollableDialogue(
			tui,
			theme,
			{
				title: `Background job #${job.id}`,
				body: inspectJob(job),
				options: [{ value: "close", label: "Close" }],
			},
			() => done(undefined),
		),
	);
}

async function runPsCommand(ctx: ExtensionCommandContext, registry: JobRegistry): Promise<void> {
	if (ctx.mode !== "tui") {
		ctx.ui.notify(formatJobs(registry), "info");
		return;
	}

	const jobs = [...registry.jobs.values()].sort((left, right) => right.id - left.id);
	if (jobs.length === 0) {
		ctx.ui.notify("No background jobs.", "info");
		return;
	}
	const labels = jobs.map(jobLabel);
	const selected = await ctx.ui.select("Background jobs", labels);
	if (!selected) return;
	const job = jobs[labels.indexOf(selected)];
	if (!job) return;
	const actions = job.status === "running" ? ["Inspect output", "Stop job"] : ["Inspect output"];
	const action = await ctx.ui.select(`Job #${job.id}`, actions);
	if (action === "Inspect output") await showInspection(ctx, job);
	else if (action === "Stop job") ctx.ui.notify(stopJob(job), "info");
}

export default function backgroundBashExtension(pi: ExtensionAPI): void {
	const processRegistry = getProcessRegistry();
	const terminalActivitySource = "background-bash";
	let sessionId: string | undefined;
	let registry: JobRegistry | undefined;
	let uiCtx: ExtensionContext | undefined;
	let terminalEnabled = false;
	let parentIdle = true;
	let refreshInterval: ReturnType<typeof setInterval> | undefined;
	const waitingJobIds = new Set<number>();
	const currentRegistry = (ctx?: ExtensionContext): JobRegistry => {
		if (ctx) {
			const currentSessionId = ctx.sessionManager.getSessionId();
			if (currentSessionId !== sessionId || !registry) {
				const current = getSessionRegistry(processRegistry, currentSessionId);
				sessionId = currentSessionId;
				registry = current;
		}
		}
		if (!registry) throw new Error("Background job registry is not initialized");
		return registry;
	};

	const stopRefreshLoop = () => {
		if (!refreshInterval) return;
		clearInterval(refreshInterval);
		refreshInterval = undefined;
	};

	const refreshActivity = () => {
		const ctx = uiCtx;
		if (!ctx || !registry) return;
		const active = [...registry.jobs.values()].filter(
			(job) => job.status === "running" || job.status === "stopping",
		);
		terminalActivity.setActive(terminalActivitySource, terminalEnabled && active.length > 0, parentIdle);
		if (ctx.hasUI) {
			ctx.ui.setWidget(
				"background-bash",
				active.length
					? active.map((job) =>
						ctx.ui.theme.fg("accent", `◌ bash #${job.id}`) +
						ctx.ui.theme.fg("muted", ` · ${duration(job)} · ${commandPreview(job.command)}`),
					)
					: undefined,
			);
		}
		if (active.length > 0 && !refreshInterval) {
			refreshInterval = setInterval(refreshActivity, 1000);
		} else if (active.length === 0) {
			stopRefreshLoop();
		}
	};

	const notifyJob = (job: Job) => {
		if (!uiCtx || waitingJobIds.has(job.id)) return;
		pi.sendMessage(
			{
				customType: "background-bash",
				content: inspectJob(job),
				display: true,
				details: { id: job.id, status: job.status, command: job.command, cwd: job.cwd },
			},
			{ triggerTurn: true, deliverAs: "steer" },
		);
	};

	const builtin = createBashToolDefinition(process.cwd());
	const parameters = Type.Object({
		...builtin.parameters.properties,
		background: Type.Optional(
			Type.Boolean({ description: "Run in the background and return a job ID immediately" }),
		),
	});

	pi.registerTool({
		...builtin,
		description: `${builtin.description} Set background=true to return immediately with a manageable job ID; completion is delivered automatically.`,
		promptGuidelines: [
			...(builtin.promptGuidelines ?? []),
			"Use bash with background=true for long-running commands. Completion is delivered automatically, so do not poll. Use background_jobs to inspect output, stop a job, or wait only when the task explicitly requires synchronous completion.",
		],
		parameters,
		async execute(toolCallId, params, signal, onUpdate, ctx) {
			const registry = currentRegistry(ctx);
			const delegate = createDelegate(ctx);
			const input = { command: params.command, timeout: params.timeout };
			if (!params.background) return delegate.execute(toolCallId, input, signal, onUpdate, ctx);

			const job: Job = {
				id: registry.nextId++,
				command: params.command,
				cwd: ctx.cwd,
				status: "running",
				controller: new AbortController(),
				output: "",
				startedAt: Date.now(),
			};
			registry.jobs.set(job.id, job);
			refreshActivity();

			void delegate
				.execute(
					toolCallId,
					input,
					job.controller.signal,
					(update) => {
						job.output = resultText(update.content);
						job.details = update.details;
					},
					ctx,
				)
				.then((result) => {
					job.output = resultText(result.content);
					job.details = result.details;
					job.status = "completed";
				})
				.catch((error: unknown) => {
					job.error = error instanceof Error ? error.message : String(error);
					job.status = job.controller.signal.aborted ? "stopped" : "failed";
				})
				.finally(() => {
					job.endedAt = Date.now();
					refreshActivity();
					notifyJob(job);
				});

			return {
				content: [
					{
						type: "text",
						text: `Started background job #${job.id}. Completion will be delivered automatically; use background_jobs to inspect, wait for, or stop it.`,
					},
				],
				details: undefined,
			};
		},
	});

	pi.registerTool({
		name: "background_jobs",
		label: "Background Jobs",
		description: "List, inspect, wait for, or stop background bash jobs started by bash with background=true.",
		promptSnippet: "Manage background bash jobs",
		parameters: Type.Object({
			action: StringEnum(["list", "inspect", "wait", "stop"] as const),
			id: Type.Optional(Type.Integer({ description: "Job ID required for inspect, wait, and stop" })),
			timeout: Type.Optional(Type.Number({ minimum: 0, description: "Maximum seconds to wait" })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const registry = currentRegistry(ctx);
			let text: string;
			if (params.action === "list") text = formatJobs(registry);
			else {
				const job = requireJob(registry, params.id);
				if (params.action === "inspect") text = inspectJob(job);
				else if (params.action === "stop") text = stopJob(job);
				else {
					waitingJobIds.add(job.id);
					try {
						const completed = await waitForJob(job, params.timeout, signal);
						text = completed
							? inspectJob(job)
							: `Timed out waiting for background job #${job.id}.\n\n${inspectJob(job)}`;
					} finally {
						waitingJobIds.delete(job.id);
					}
				}
			}
			refreshActivity();
			return { content: [{ type: "text", text }], details: {} };
		},
	});

	pi.registerCommand("ps", {
		description: "List, inspect, or stop background bash jobs",
		handler: async (_args, ctx) => {
			await runPsCommand(ctx, currentRegistry(ctx));
			refreshActivity();
		},
	});

	pi.on("agent_start", () => {
		parentIdle = false;
	});
	pi.on("agent_settled", () => {
		parentIdle = true;
		refreshActivity();
		terminalActivity.refresh();
	});

	pi.on("session_start", (_event, ctx) => {
		currentRegistry(ctx);
		uiCtx = ctx;
		terminalEnabled = ctx.mode === "tui";
		parentIdle = ctx.isIdle();
		refreshActivity();
	});

	pi.on("session_shutdown", (event, ctx) => {
		uiCtx = undefined;
		terminalEnabled = false;
		stopRefreshLoop();
		waitingJobIds.clear();
		terminalActivity.setActive(terminalActivitySource, false);
		ctx.ui.setWidget("background-bash", undefined);
		if (event.reason === "reload" || !registry) return;
		for (const job of registry.jobs.values()) {
			if (job.status === "running") stopJob(job);
		}
		if (sessionId) processRegistry.sessions.delete(sessionId);
	});
}
