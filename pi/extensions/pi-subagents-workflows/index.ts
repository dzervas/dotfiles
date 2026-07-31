import { getMarkdownTheme, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Markdown } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { parseWorkflow, QuickJSWorkflowRuntime, type WorkflowRuntime } from "./runtime";
import { WorkflowManager, type ToolInvoker, type WorkflowRecord } from "./workflow";

export interface ExtensionOptions {
	runtime?: WorkflowRuntime;
	toolInvoker?: ToolInvoker;
}

function text(value: unknown): string {
	if (typeof value === "string") return value;
	return JSON.stringify(value, null, 2) ?? String(value);
}

function summary(run: WorkflowRecord): string {
	const phase = run.phase ? ` · ${run.phase}` : "";
	const error = run.error ? ` · ${run.error}` : "";
	return `${run.id} ${run.status} · ${run.name} · ${run.agentCount} agents${phase}${error}`;
}

function defaultToolInvoker(): ToolInvoker {
	return {
		async invoke() {
			throw new Error(
				"workflow tool() is disabled because Pi has no documented permission-aware programmatic tool dispatcher. Use agent() to run tools through a subagent session.",
			);
		},
	};
}

export function createSubagentsWorkflowsExtension(options: ExtensionOptions = {}) {
	return function subagentsWorkflowsExtension(pi: ExtensionAPI) {
		const manager = new WorkflowManager(
			options.runtime ?? new QuickJSWorkflowRuntime(),
			options.toolInvoker ?? defaultToolInvoker(),
		);
		let sessionActive = true;
		const waitedRunIds = new Set<string>();
		const pendingNotifications = new Map<string, WorkflowRecord>();

		const notifyWorkflow = (record: WorkflowRecord) => {
			if (!sessionActive || waitedRunIds.has(record.id)) return;
			pi.sendMessage({
				customType: "workflow",
				content: `Workflow ${record.name} ${record.status}.\n${text(record.result ?? record.error ?? "No result.")}`,
				display: true,
				details: record,
			}, { triggerTurn: true, deliverAs: "followUp" });
		};

		const updateWorkflowWidget = (ctx: ExtensionContext) => {
			if (!ctx.hasUI) return;
			const active = manager.list().filter((run) => run.status === "running");
			ctx.ui.setWidget(
				"workflows",
				active.length
					? active.map((run) => {
						const phase = run.phase ? ` · ${run.phase}` : "";
						const agents = `${run.activeAgents} active agent${run.activeAgents === 1 ? "" : "s"}`;
						return ctx.ui.theme.fg("accent", `◌ ${run.name}`) + ctx.ui.theme.fg("muted", `${phase} · ${agents}`);
					})
					: undefined,
			);
		};

		// TODO: Once pi gives access to calling tools programatically, add a `tool()` function to do that
		pi.registerTool({
			name: "workflow",
			label: "Workflow",
			description: "Run a JavaScript workflow that can parallelize subagents",
			parameters: Type.Object({
				script: Type.String({ description: "Self-contained JavaScript workflow. \
Its first statement must be `export const meta = { name, description };`; after that, \
use top-level `await` and `return`. \
Call subagents with `await agent(prompt, options?)` or `parallel([() => agent(...)])`; \
`export default` is unsupported. \
Globals: agent, parallel, pipeline, phase, log, args, cwd, and process.cwd(). \
When the workflow is done you will be notified, regardless of whether the current turn is still active." }),
				args: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
				background: Type.Optional(Type.Boolean({ description: "Run in the background (default true)." })),
				concurrency: Type.Optional(Type.Integer({ minimum: 1 })),
				maxAgents: Type.Optional(Type.Integer({ minimum: 1 })),
			}),
			renderCall(args) {
				return new Markdown(`**workflow**\n\n\`\`\`js\n${args.script}\n\`\`\``, 0, 0, getMarkdownTheme());
			},
			async execute(_id, params, signal, onUpdate, ctx) {
				const workflow = parseWorkflow(params.script);
				const background = params.background ?? true;
				const run = manager.start(workflow, {
					args: params.args,
					concurrency: params.concurrency,
					maxAgents: params.maxAgents,
					cwd: ctx.cwd,
					signal,
					onUpdate: (message) => {
						updateWorkflowWidget(ctx);
						if (!background) onUpdate?.({ content: [{ type: "text", text: message }], details: {} });
					},
				});
				updateWorkflowWidget(ctx);
				if (background) {
					void run.done.then((record) => {
						if (!sessionActive || waitedRunIds.has(record.id)) return;
						if (ctx.isIdle()) notifyWorkflow(record);
						else pendingNotifications.set(record.id, record);
					});
					return {
						content: [{ type: "text", text: `Started workflow ${run.id}: ${workflow.meta.name}.` }],
						details: { id: run.id, name: workflow.meta.name },
					};
				}

				const record = await run.done;
				if (record.status !== "completed") throw new Error(record.error ?? `Workflow ${record.status}.`);
				return {
					content: [{ type: "text", text: text(record.result) }],
					details: record,
				};
			},
		});

		pi.registerTool({
			name: "workflow_control",
			label: "Workflow Control",
			description: "List, inspect, wait for, or stop in-memory workflows.",
			parameters: Type.Object({
				action: StringEnum(["list", "status", "wait", "stop"] as const),
				runId: Type.Optional(Type.String()),
			}),
			async execute(_id, params) {
				if (params.action === "list") {
					const runs = manager.list();
					return {
						content: [{ type: "text", text: runs.length ? runs.map(summary).join("\n") : "No workflows." }],
						details: { runs, run: undefined as WorkflowRecord | undefined },
					};
				}
				if (!params.runId) throw new Error("runId is required for status, wait, and stop.");
				if (params.action === "wait") {
					waitedRunIds.add(params.runId);
					pendingNotifications.delete(params.runId);
				}
				const record = params.action === "stop"
					? manager.stop(params.runId)
					: params.action === "wait"
						? await manager.wait(params.runId)
						: manager.status(params.runId);
				if (!record) throw new Error(`Unknown workflow: ${params.runId}`);
				return {
					content: [{ type: "text", text: summary(record) }],
					details: { runs: manager.list(), run: record },
				};
			},
		});

		pi.registerCommand("workflows", {
			description: "Show workflow status",
			handler: async (args, ctx) => {
				const id = args.trim();
				const message = id
					? (manager.status(id) ? summary(manager.status(id)!) : `Unknown workflow: ${id}`)
					: (manager.list().map(summary).join("\n") || "No workflows.");
				ctx.ui.notify(message, "info");
			},
		});

		pi.on("agent_settled", () => {
			for (const record of pendingNotifications.values()) notifyWorkflow(record);
			pendingNotifications.clear();
		});

		pi.on("session_start", (_event, ctx) => {
			sessionActive = true;
			waitedRunIds.clear();
			pendingNotifications.clear();
			ctx.ui.setWidget("subagents-workflows", undefined);
			ctx.ui.setWidget("workflows", undefined);
		});
		pi.on("session_shutdown", (_event, ctx) => {
			sessionActive = false;
			pendingNotifications.clear();
			manager.stopAll();
			ctx.ui.setWidget("workflows", undefined);
		});
	};
}

export default createSubagentsWorkflowsExtension();
