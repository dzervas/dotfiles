import { parse } from "acorn";
import { getQuickJS } from "quickjs-emscripten";

export interface WorkflowMeta {
	name: string;
	description: string;
}

export interface ParsedWorkflow {
	meta: WorkflowMeta;
	body: string;
}

export interface WorkflowHost {
	agent(prompt: string, options?: unknown): Promise<unknown>;
	tool(name: string, args?: unknown): Promise<unknown>;
	phase(title: string): void;
	log(message: string): void;
	args: Record<string, unknown>;
	cwd: string;
}

/** A JavaScript execution environment with no Pi-specific knowledge. */
export interface WorkflowRuntime {
	execute(workflow: ParsedWorkflow, host: WorkflowHost): Promise<unknown>;
}

type MetaProperty = {
	type: string;
	key?: { type: string; name?: string; value?: unknown };
	value?: { type: string; value?: unknown };
};

/** Parse the required metadata declaration and leave the rest as executable body. */
export function parseWorkflow(source: string): ParsedWorkflow {
	if (!source.trimStart().startsWith("export const meta")) {
		throw new Error("A workflow must begin with export const meta = { name, description }.");
	}

	const program = parse(source, {
		ecmaVersion: "latest",
		sourceType: "module",
		allowReturnOutsideFunction: true,
	});
	const declaration = program.body[0] as {
		type?: string;
		declaration?: {
			type?: string;
			declarations?: Array<{
				id?: { name?: string };
				init?: { type?: string; properties?: MetaProperty[] };
			}>;
		};
		end?: number;
	};
	const variable = declaration?.declaration?.declarations?.[0];
	const properties = variable?.init?.properties;
	if (
		declaration?.type !== "ExportNamedDeclaration" ||
		declaration.declaration?.type !== "VariableDeclaration" ||
		variable?.id?.name !== "meta" ||
		variable.init?.type !== "ObjectExpression" ||
		!properties ||
		declaration.end === undefined
	) {
		throw new Error("A workflow must begin with export const meta = { name, description }.");
	}

	const values = new Map<string, unknown>();
	for (const property of properties) {
		if (
			property.type !== "Property" ||
			property.key?.type !== "Identifier" ||
			property.value?.type !== "Literal"
		) {
			throw new Error("Workflow meta must contain literal name and description strings.");
		}
		values.set(property.key.name ?? "", property.value.value);
	}
	const name = values.get("name");
	const description = values.get("description");
	if (typeof name !== "string" || typeof description !== "string") {
		throw new Error("Workflow meta requires string name and description fields.");
	}

	return { meta: { name, description }, body: source.slice(declaration.end) };
}

/** QuickJS WASM implementation using deferred promises for concurrent host calls. */
export class QuickJSWorkflowRuntime implements WorkflowRuntime {
	async execute(workflow: ParsedWorkflow, host: WorkflowHost): Promise<unknown> {
		const quickjs = await getQuickJS();
		const context = quickjs.newContext();
		const { runtime } = context;
		const pendingHostCalls = new Set<Promise<void>>();

		const toValue = (value: unknown) => {
			if (value === undefined) return context.undefined;
			const json = JSON.stringify(value);
			if (json === undefined) return context.undefined;
			return context.unwrapResult(
				context.evalCode(`JSON.parse(${JSON.stringify(json)})`, "workflow-bridge.js"),
			);
		};
		const set = (name: string, value: unknown) => {
			const handle = toValue(value);
			context.setProp(context.global, name, handle);
			if (handle !== context.undefined) handle.dispose();
		};
		const asyncBridge = (
			name: string,
			callback: (...args: unknown[]) => Promise<unknown>,
		) => {
			const fn = context.newFunction(name, (...args) => {
				const deferred = context.newPromise();
				const values = args.map((arg) => context.dump(arg));
				const call = Promise.resolve().then(() => callback(...values)).then(
					(value) => {
						const handle = toValue(value);
						deferred.resolve(handle);
						if (handle !== context.undefined) handle.dispose();
					},
					(error) => {
						const handle = context.newError(error instanceof Error ? error.message : String(error));
						deferred.reject(handle);
						handle.dispose();
					},
				);
				pendingHostCalls.add(call);
				void call.finally(() => pendingHostCalls.delete(call));
				return deferred.handle;
			});
			context.setProp(context.global, name, fn);
			fn.dispose();
		};
		const syncBridge = (name: string, callback: (value: unknown) => void) => {
			const fn = context.newFunction(name, (value) => {
				callback(context.dump(value));
				return context.undefined;
			});
			context.setProp(context.global, name, fn);
			fn.dispose();
		};

		try {
			set("args", host.args);
			set("cwd", host.cwd);
			asyncBridge("agent", (prompt, options) => host.agent(String(prompt), options));
			asyncBridge("tool", (name, args) => host.tool(String(name), args));
			syncBridge("phase", (title) => host.phase(String(title)));
			syncBridge("log", (message) => host.log(String(message)));
			const process = context.newObject();
			const cwd = context.newFunction("cwd", () => context.newString(host.cwd));
			context.setProp(process, "cwd", cwd);
			cwd.dispose();
			context.setProp(context.global, "process", process);
			process.dispose();
			context.unwrapResult(
				context.evalCode(
					`globalThis.parallel = (thunks) => Promise.all(thunks.map((thunk) => thunk()));
					globalThis.pipeline = (items, ...stages) => Promise.all(items.map(async (original, index) => {
						let value = original;
						for (const stage of stages) value = await stage(value, original, index);
						return value;
					}));`,
					"workflow-helpers.js",
				),
			).dispose();

			const promise = context.unwrapResult(
				context.evalCode(`(async () => {${workflow.body}\n})()`, "workflow.js"),
			);
			try {
				let settled: Awaited<ReturnType<typeof context.resolvePromise>> | undefined;
				void context.resolvePromise(promise).then((result) => {
					settled = result;
				});
				while (!settled) {
					context.unwrapResult(runtime.executePendingJobs());
					await new Promise((resolve) => setTimeout(resolve, 1));
				}
				const result = context.unwrapResult(settled);
				try {
					return context.dump(result);
				} finally {
					result.dispose();
				}
			} finally {
				promise.dispose();
			}
		} finally {
			await Promise.allSettled(pendingHostCalls);
			context.dispose();
		}
	}
}
