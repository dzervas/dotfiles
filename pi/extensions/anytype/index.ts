import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type Static, type TSchema } from "typebox";
import { getPrompt } from "../lib/prompts.ts";
import { setParentBeadsActor } from "../todo/beads.ts";
import { createIssueStore, IssueError, kinds, states } from "./store.ts";
import { anytypeStore, loadAnytypeConfig } from "./client.ts";
const nonempty = () => Type.String({ minLength: 1 });
const ids = () => Type.Array(nonempty());
const delta = () => Type.Object({ add: Type.Optional(ids()), remove: Type.Optional(ids()) }, { additionalProperties: false });
const common = {
	title: nonempty(),
	description: Type.String(),
	kind: StringEnum(kinds),
};
const pagination = {
	limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })),
};

export default function anytypeExtension(pi: ExtensionAPI) {
	const config = loadAnytypeConfig();
	if (!config) return;
	let actor: string | undefined;
	pi.on("session_start", (_event, ctx) => {
		actor = setParentBeadsActor(ctx.sessionManager.getSessionId(), ctx.mode, ctx.sessionManager.getHeader()?.parentSession);
	});
	pi.on("session_shutdown", () => { actor = undefined; });

	function result(data: Record<string, unknown>, isError = false) {
		const text = JSON.stringify(data);
		return { content: [{ type: "text" as const, text }], details: data, structuredContent: JSON.parse(text), ...(isError ? { isError: true } : {}) };
	}

	function register<T extends TSchema>(name: string, description: string, parameters: T,
		run: (input: Static<T>, backend: ReturnType<typeof createIssueStore>, operation: string, signal?: AbortSignal) => Promise<Record<string, unknown>>) {
		pi.registerTool({
			name, label: name.replaceAll("_", " "),
			description,
			...(name === "issue_update" ? { promptGuidelines: [getPrompt("anytype", "guidance")] } : {}),
			parameters,
			outputSchema: Type.Record(Type.String(), Type.Unknown()),
			// Even a read can provision the current repository's project on first use.
			annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false },
			async execute(operation, input, signal, _onUpdate, ctx) {
				try {
					const data = await run(input, anytypeStore(pi, config!, ctx, signal), `${ctx.sessionManager.getSessionId()}:${operation}`, signal);
					return result(data);
				} catch (error) {
					if (!(error instanceof IssueError)) throw error;
					const data = { error: error.code, message: error.message, ...error.details };
					return result(data, true);
				}
			},
		});
	}

	register("issue_list", getPrompt("anytype", "issue_list"), Type.Object({
		query: Type.Optional(Type.String()), kind: Type.Optional(common.kind), state: Type.Optional(StringEnum(states)),
		tags: Type.Optional(ids()), exclude_tags: Type.Optional(ids()), parent: Type.Optional(nonempty()),
		assignee: Type.Optional(Type.String({ description: getPrompt("anytype", "assignee") })),
		ready: Type.Optional(Type.Boolean()), ...pagination,
		offset: Type.Optional(Type.Integer({ minimum: 0 })),
	}, { additionalProperties: false }), (input, backend, _operation, signal) => backend.list(input, signal));

	register("issue_get", getPrompt("anytype", "issue_get"), Type.Object({
		id: nonempty(), comments: Type.Optional(Type.Boolean()), before: Type.Optional(nonempty()), ...pagination,
	}, { additionalProperties: false }), (input, backend, _operation, signal) => backend.get({ ...input, comments: input.comments ?? true }, signal));

	register("issue_create", getPrompt("anytype", "issue_create"), Type.Object({
		title: common.title, description: Type.Optional(common.description), kind: Type.Optional(common.kind),
		tags: Type.Optional(ids()), parent: Type.Optional(nonempty()), blockers: Type.Optional(ids()),
	}, { additionalProperties: false }), (input, backend, operation, signal) => backend.create(input, operation, signal));

	register("issue_update", getPrompt("anytype", "issue_update"), Type.Object({
		id: nonempty(), revision: Type.Optional(nonempty()),
		title: Type.Optional(common.title), description: Type.Optional(common.description), kind: Type.Optional(common.kind),
		state: Type.Optional(StringEnum(states)), tags: Type.Optional(delta()),
		parent: Type.Optional(Type.Union([nonempty(), Type.Null()])), blockers: Type.Optional(delta()),
		claim: Type.Optional(Type.Boolean({ description: getPrompt("anytype", "claim") })),
		comment: Type.Optional(nonempty()),
	}, { additionalProperties: false }), (input, backend, operation, signal) => backend.update(input, actor ?? "", operation, signal));
}
