import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
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

function defaultToolInvoker(pi: ExtensionAPI): ToolInvoker {
	return {
		async invoke(name, args, signal) {
			const invokeTool = (pi as unknown as {
				invokeTool?: (name: string, args: unknown, options?: { signal?: AbortSignal }) => Promise<unknown> | unknown;
			}).invokeTool;
			if (typeof invokeTool !== "function") {
				throw new Error(
					"workflow tool() is unavailable: this Pi version does not expose pi.invokeTool().",
				);
			}
			return invokeTool.call(pi, name, args, { signal });
		},
	};
}

export function createSubagentsWorkflowsExtension(options: ExtensionOptions = {}) {
	return function subagentsWorkflowsExtension(pi: ExtensionAPI) {
		const manager = new WorkflowManager(
			options.runtime ?? new QuickJSWorkflowRuntime(),
			options.toolInvoker ?? defaultToolInvoker(pi),
		);
		let sessionActive = true;

		pi.registerTool({
			name: "subagents_workflow",
			label: "Subagents Workflow",
			description: "Run a JavaScript workflow that coordinates pi-subagents.",
			parameters: Type.Object({
				script: Type.String({ description: "Workflow JavaScript beginning with export const meta." }),
				args: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
				background: Type.Optional(Type.Boolean({ description: "Run in the background (default true)." })),
				concurrency: Type.Optional(Type.Integer({ minimum: 1 })),
				maxAgents: Type.Optional(Type.Integer({ minimum: 1 })),
			}),
			async execute(_id, params, signal, onUpdate, ctx) {
				const workflow = parseWorkflow(params.script);
				const background = params.background ?? true;
				const run = manager.start(workflow, {
					args: params.args,
					concurrency: params.concurrency,
					maxAgents: params.maxAgents,
					cwd: ctx.cwd,
					signal,
					onUpdate: background ? undefined : (message) => onUpdate?.({ content: [{ type: "text", text: message }], details: {} }),
				});
				if (background) {
					void run.done.then((record) => {
						if (!sessionActive) return;
						pi.sendMessage({
							customType: "subagents-workflow",
							content: `Workflow ${record.name} ${record.status}.\n${text(record.result ?? record.error ?? "No result.")}`,
							display: true,
							details: record,
						}, { triggerTurn: true, deliverAs: "followUp" });
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
			name: "subagents_workflow_control",
			label: "Subagents Workflow Control",
			description: "List, inspect, or stop in-memory subagent workflows.",
			parameters: Type.Object({
				action: StringEnum(["list", "status", "stop"] as const),
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
				if (!params.runId) throw new Error("runId is required for status and stop.");
				const record = params.action === "stop"
					? manager.stop(params.runId)
					: manager.status(params.runId);
				if (!record) throw new Error(`Unknown workflow: ${params.runId}`);
				return {
					content: [{ type: "text", text: summary(record) }],
					details: { runs: manager.list(), run: record },
				};
			},
		});

		pi.registerCommand("subagent-workflows", {
			description: "Show subagent workflow status",
			handler: async (args, ctx) => {
				const id = args.trim();
				const message = id
					? (manager.status(id) ? summary(manager.status(id)!) : `Unknown workflow: ${id}`)
					: (manager.list().map(summary).join("\n") || "No workflows.");
				ctx.ui.notify(message, "info");
			},
		});

		pi.on("session_start", () => {
			sessionActive = true;
		});
		pi.on("session_shutdown", () => {
			sessionActive = false;
			manager.stopAll();
		});
	};
}

export default createSubagentsWorkflowsExtension();
