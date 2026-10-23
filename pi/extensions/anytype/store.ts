// Anytype v2 contract: https://developers.anytype.io/docs/reference/v2/anytype-api
// No Pi imports: another host supplies credentials, repository identity and an actor.
import { createHash } from "node:crypto";
import { basename, dirname } from "node:path";
import type { ProjectIdentity } from "./project.ts";

export const kinds = ["task", "bug", "epic"] as const;
export const states = ["open", "in_progress", "blocked", "closed"] as const;
type Kind = typeof kinds[number];
type State = typeof states[number];
const fields = ["kind", "state", "tags", "parent", "blockers", "assignee"] as const;
type Field = typeof fields[number];

export interface IssueConfig {
	baseUrl?: string;
	space: string;
	type: string;
	projectType?: string; // Defaults to the existing Project type's key: project.
	// kind/state: select; tags: multi_select; parent/blockers/project: objects;
	// assignee: text (session/team identity, not an Anytype member).
	properties: Record<Field, string> & { project?: string };
}

export function parseConfig(value: unknown): IssueConfig {
	const config = value as IssueConfig | null;
	if (!config || typeof config.space !== "string" || !config.space.trim() ||
		typeof config.type !== "string" || !config.type.trim() ||
		fields.some((field) => typeof config.properties?.[field] !== "string" || !config.properties[field].trim())) {
		throw new Error("anytype.json needs space, type, and properties: kind, state, tags, parent, blockers, assignee.");
	}
	if ((config.projectType !== undefined && (typeof config.projectType !== "string" || !config.projectType.trim())) ||
		(config.properties.project !== undefined && (typeof config.properties.project !== "string" || !config.properties.project.trim()))) {
		throw new Error("projectType and properties.project must be nonempty keys when supplied.");
	}
	const keys = [...fields.map((field) => config.properties[field]), config.properties.project ?? "project"];
	if (new Set(keys).size !== keys.length || keys.some((key) => ["name", "description"].includes(key))) {
		throw new Error("Issue property keys must be distinct and cannot replace name or description.");
	}
	if (config.baseUrl !== undefined && (typeof config.baseUrl !== "string" || !/^https?:\/\//.test(config.baseUrl))) {
		throw new Error("Issue baseUrl must be an HTTP(S) URL.");
	}
	return config;
}

interface ObjectRow {
	id: string;
	name?: string;
	type: string;
	properties: Record<string, unknown>;
	etag?: string;
	discussion?: string;
}

export interface Issue {
	id: string;
	title: string;
	kind: Kind;
	state: State;
	tags: string[];
	parent: string | null;
	blockers: string[];
	assignee: string | null;
}

export interface CreateInput {
	title: string;
	description?: string;
	kind?: Kind;
	tags?: string[];
	parent?: string;
	blockers?: string[];
}

type Delta = { add?: string[]; remove?: string[] };
export interface UpdateInput {
	id: string;
	revision?: string;
	title?: string;
	description?: string;
	kind?: Kind;
	state?: State;
	tags?: Delta;
	parent?: string | null;
	blockers?: Delta;
	claim?: boolean;
	comment?: string;
}

export interface ListInput {
	query?: string;
	kind?: Kind;
	state?: State;
	tags?: string[];
	exclude_tags?: string[];
	parent?: string;
	assignee?: string;
	ready?: boolean;
	limit?: number;
	offset?: number;
}

export class IssueError extends Error {
	constructor(readonly code: string, message: string, readonly details: Record<string, unknown> = {}) {
		super(message);
	}
}

const list = (value: unknown): string[] => Array.isArray(value) ? value as string[] : typeof value === "string" && value ? [value] : [];
const first = (value: unknown): string | undefined => list(value)[0];
const segment = encodeURIComponent;

export function createIssueStore(config: IssueConfig, token: () => Promise<string>, identify: () => Promise<ProjectIdentity>, fetcher: typeof fetch = fetch) {
	const base = `${(config.baseUrl ?? "http://127.0.0.1:31009").replace(/\/$/, "")}/v2/spaces/${segment(config.space)}`;
	const keys = { ...config.properties, project: config.properties.project ?? "project" };
	let project: Promise<ProjectIdentity & { id: string }> | undefined;

	async function request<T>(path: string, signal?: AbortSignal, body?: unknown, method = "GET", headers: Record<string, string> = {}): Promise<T> {
		const credential = (await token()).trim();
		if (!credential) throw new IssueError("missing_credentials", "Anytype API key is empty.");
		const readOnly = method === "GET" || path.startsWith("/search?");
		let response: Response;
		try {
			response = await fetcher(`${base}${path}`, {
				method, redirect: "error",
				headers: { Authorization: `Bearer ${credential}`, "Content-Type": "application/json", ...headers },
				body: body === undefined ? undefined : JSON.stringify(body),
				signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(15000)]) : AbortSignal.timeout(15000),
			});
		} catch {
			throw new IssueError(readOnly ? "connection_failed" : "write_outcome_unknown", readOnly
				? "Could not complete the Anytype read."
				: "Anytype write did not complete. Re-read before retrying; it may have succeeded.");
		}
		let data: T & { code?: string; message?: string; etag?: string };
		try {
			data = await response.json();
		} catch {
			if (!response.ok) throw new IssueError(`http_${response.status}`, `Anytype returned HTTP ${response.status}. Check that API v2 is available.`, { status: response.status });
			throw new IssueError(readOnly ? "invalid_response" : "write_outcome_unknown", "Invalid Anytype response. Re-read before retrying a write.");
		}
		if (!response.ok) throw new IssueError(data.code ?? `http_${response.status}`, data.message ?? `Anytype returned HTTP ${response.status}.`, {
			status: response.status, ...(data.etag ? { revision: data.etag } : {}),
		});
		return data;
	}

	async function resolveProject(signal?: AbortSignal) {
		const identity = await identify();
		const type = config.projectType ?? "project";
		async function find(property: string, value: string) {
			const page = await request<{ data: ObjectRow[]; warnings?: unknown[] }>("/search?limit=2", signal, {
				type, fields: ["description"], filters: [{ property, condition: "equal", value }],
			}, "POST");
			if (page.warnings?.length) throw new IssueError("project_lookup_incomplete", "Anytype project search is incomplete; refusing to create a possible duplicate.");
			return page.data;
		}
		const existing = await find("description", identity.path);
		if (existing.length > 1) throw new IssueError("ambiguous_project", `Multiple projects describe ${identity.path}; keep one project for this path.`);
		if (existing.length) return { ...identity, id: existing[0].id, name: existing[0].name ?? String(existing[0].properties.name ?? identity.name) };
		const names = [identity.name, `${basename(dirname(identity.path))}/${identity.name}`];
		for (const name of names) {
			const collisions = await find("name", name);
			const samePath = collisions.filter((row) => row.properties.description === identity.path);
			if (samePath.length > 1) throw new IssueError("ambiguous_project", `Multiple projects describe ${identity.path}.`);
			if (samePath.length) return { ...identity, id: samePath[0].id, name };
			if (collisions.length) continue;
			// Shared across sessions/processes: concurrent first use of one path
			// replays the same create instead of minting duplicate projects.
			const key = createHash("sha256").update(JSON.stringify([config.space, type, identity.path])).digest("hex");
			const created = await request<{ id: string }>("/objects", signal, {
				type, name, template: "none", properties: { description: identity.path },
			}, "POST", { "Idempotency-Key": `project:${key}` });
			return { ...identity, id: created.id, name };
		}
		throw new IssueError("project_name_collision", `Both ${names.join(" and ")} belong to other paths; rename one project before retrying.`);
	}

	const currentProject = (signal?: AbortSignal) => project ??= resolveProject(signal);

	function summary(row: ObjectRow): Issue {
		const p = row.properties;
		const kind = first(p[keys.kind]) as Kind;
		const state = first(p[keys.state]) as State;
		if (!kinds.includes(kind) || !states.includes(state)) {
			throw new IssueError("invalid_issue", `Issue ${row.id} needs a valid kind and state option.`);
		}
		return {
			id: row.id, title: row.name ?? String(p.name ?? ""), kind, state,
			tags: list(p[keys.tags]), parent: first(p[keys.parent]) ?? null,
			blockers: list(p[keys.blockers]), assignee: first(p[keys.assignee]) ?? null,
		};
	}

	async function read(id: string, signal?: AbortSignal) {
		const project = await currentProject(signal);
		const row = await request<ObjectRow>(`/objects/${segment(id)}?include=properties`, signal);
		if (row.type !== config.type) throw new IssueError("not_an_issue", `${id} is not an object of type ${config.type}.`);
		if (!list(row.properties[keys.project]).includes(project.id)) throw new IssueError("wrong_project", `${id} does not belong to project ${project.name}.`);
		return row;
	}

	async function get(input: { id: string; comments?: boolean; before?: string; limit?: number }, signal?: AbortSignal) {
		const row = await read(input.id, signal);
		let comments;
		if (input.comments && row.discussion) {
			const query = new URLSearchParams({ limit: String(input.limit ?? 25) });
			if (input.before) query.set("before", input.before);
			const page = await request<{ messages: { id: string; author: string; at: string; text: string; blocks_text?: string }[]; has_more: boolean; next_before?: string }>(
				`/chats/${segment(row.discussion)}/messages?${query}`, signal);
			comments = {
				items: page.messages.map((m) => ({ id: m.id, author: m.author, at: m.at, text: m.blocks_text ?? m.text })),
				has_more: page.has_more, before: page.next_before,
			};
		} else if (input.comments) comments = { items: [], has_more: false };
		return { ...summary(row), description: String(row.properties.description ?? ""), revision: row.etag, ...(comments ? { comments } : {}) };
	}

	async function search(input: ListInput = {}, signal?: AbortSignal) {
		const project = await currentProject(signal);
		const filters: Record<string, unknown>[] = [{ property: keys.project, condition: "in", value: [project.id] }];
		const add = (field: Field, condition: string, value?: unknown) => filters.push({ property: keys[field], condition, ...(value === undefined ? {} : { value }) });
		if (input.kind) add("kind", "equal", input.kind);
		if (input.state) add("state", "equal", input.state);
		if (input.tags?.length) add("tags", "all_in", input.tags);
		if (input.exclude_tags?.length) add("tags", "not_in", input.exclude_tags);
		if (input.parent) add("parent", "in", [input.parent]);
		if (input.assignee !== undefined) add("assignee", input.assignee ? "equal" : "empty", input.assignee || undefined);
		if (input.ready) {
			add("state", "equal", "open");
			add("assignee", "empty");
			add("kind", "not_equal", "epic");
			add("tags", "not_in", ["human"]);
		}
		const offset = input.offset ?? 0;
		const query = new URLSearchParams({ offset: String(offset), limit: String(input.limit ?? 25) });
		const page = await request<{ data: ObjectRow[]; has_more: boolean; warnings?: unknown[] }>(`/search?${query}`, signal, {
			type: config.type, query: input.query ?? "", fields: Object.values(keys), filters,
		}, "POST");
		let issues = page.data.map(summary);
		if (input.ready) {
			const blockers = new Map<string, Promise<ObjectRow>>();
			const ready: Issue[] = [];
			for (const issue of issues) {
				let blocked = false;
				for (const id of issue.blockers) {
					if (!blockers.has(id)) blockers.set(id, read(id, signal));
					if (summary(await blockers.get(id)!).state !== "closed") blocked = true;
				}
				if (!blocked) ready.push(issue);
			}
			issues = ready;
		}
		// Readiness filters a bounded search page, not an unbounded full-space scan.
		return { issues, has_more: page.has_more, next_offset: page.has_more ? offset + page.data.length : null, ...(page.warnings?.length ? { warnings: page.warnings } : {}) };
	}

	async function create(input: CreateInput, operation: string, signal?: AbortSignal) {
		const project = await currentProject(signal);
		const result = await request<{ id: string; etag: string; warnings?: unknown[] }>("/objects?create_missing_options=true", signal, {
			type: config.type, name: input.title, template: "none",
			properties: {
				description: input.description ?? "", [keys.project]: [project.id], [keys.kind]: [input.kind ?? "task"], [keys.state]: ["open"],
				[keys.tags]: input.tags ?? [], [keys.parent]: input.parent ? [input.parent] : [], [keys.blockers]: input.blockers ?? [],
			},
		}, "POST", { "Idempotency-Key": operation });
		return { id: result.id, revision: result.etag, ...(result.warnings?.length ? { warnings: result.warnings } : {}) };
	}

	async function update(input: UpdateInput, actor: string, operation: string, signal?: AbortSignal) {
		if (!actor) throw new IssueError("missing_actor", "Issue updates require a session actor.");
		if (input.comment !== undefined && (!input.comment.trim() || `${actor}:\n${input.comment}`.length > 8000)) {
			throw new IssueError("invalid_comment", "Comments must be nonempty and fit within 8000 UTF-16 units including the actor prefix.");
		}
		const edits = [input.title, input.description, input.kind, input.state, input.tags, input.parent, input.blockers].some((value) => value !== undefined);
		if (edits && !input.revision) throw new IssueError("revision_required", "Read the issue and pass its revision when editing fields.");
		if (!edits && input.claim === undefined && input.comment === undefined) throw new IssueError("empty_update", "Supply a field change, claim, or comment.");
		if (input.state === "closed" && !input.comment?.trim()) throw new IssueError("close_reason_required", "Closing an issue requires a comment with the reason.");
		const row = await read(input.id, signal);
		const current = summary(row);
		if (input.revision && input.revision !== row.etag) throw new IssueError("etag_mismatch", "Issue changed; read it again before editing.", { revision: row.etag });
		const set: Record<string, unknown> = {};
		if (input.title !== undefined) set.name = input.title;
		if (input.description !== undefined) set.description = input.description;
		if (input.kind !== undefined) set[keys.kind] = [input.kind];
		if (input.state !== undefined) set[keys.state] = [input.state];
		if (input.parent !== undefined) set[keys.parent] = input.parent ? [input.parent] : [];
		if (input.claim !== undefined) {
			if (current.assignee && current.assignee !== actor) throw new IssueError("already_claimed", "Issue belongs to another actor.", { assignee: current.assignee });
			const state = input.claim ? "in_progress" : "open";
			if (input.state && input.state !== state) throw new IssueError("invalid_claim", `claim=${input.claim} requires state ${state}.`);
			if (input.claim && !(current.state === "open" || current.state === "in_progress" && current.assignee === actor)) {
				throw new IssueError("not_claimable", `Cannot claim an issue in state ${current.state}.`);
			}
			if (input.claim ? current.assignee !== actor || current.state !== state : current.assignee === actor) {
				set[keys.assignee] = input.claim ? actor : "";
				set[keys.state] = [state];
			}
		}
		const ops: Record<string, unknown>[] = [];
		if (Object.keys(set).length) ops.push({ op: "set_properties", set });
		// One property can occur only once within an op; separate add/remove ops
		// let a single request change both while preserving unrelated list entries.
		for (const action of ["remove", "add"] as const) {
			const values: Record<string, string[]> = {};
			for (const field of ["tags", "blockers"] as const) {
				if (input[field]?.[action]?.length) values[keys[field]] = input[field][action]!;
			}
			if (Object.keys(values).length) ops.push({ op: "set_properties", [action]: values });
		}
		let revision = row.etag;
		let warnings: unknown[] | undefined;
		if (ops.length) {
			if (!revision) throw new IssueError("missing_revision", "Anytype did not return an etag; refusing an unguarded write.");
			const result = await request<{ etag: string; warnings?: unknown[] }>(`/objects/${segment(input.id)}?create_missing_options=true`, signal,
				{ ops }, "PATCH", { "If-Match": revision, "Idempotency-Key": `${operation}:edit` });
			revision = result.etag;
			warnings = result.warnings;
		}
		let commentId: string | undefined;
		if (input.comment !== undefined) {
			try {
				const discussion = row.discussion ?? (await request<{ id: string }>(`/objects/${segment(input.id)}/discussion`, signal, undefined, "POST", { "Idempotency-Key": `${operation}:discussion` })).id;
				const result = await request<{ id: string }>(`/chats/${segment(discussion)}/messages`, signal,
					{ text: `${actor}:\n${input.comment}` }, "POST", { "Idempotency-Key": `${operation}:comment` });
				commentId = result.id;
			} catch (error) {
				if (!(error instanceof IssueError)) throw error;
				// The metadata edit is already committed; never disguise partial success.
				throw new IssueError("comment_failed", error.message, { id: input.id, updated: ops.length > 0, revision, cause: error.code,
					comment: error.code === "write_outcome_unknown" ? "unknown; inspect comments before retrying" : "not_sent" });
			}
		}
		return { id: input.id, revision, updated: ops.length > 0, ...(commentId ? { comment_id: commentId } : {}), ...(warnings?.length ? { warnings } : {}) };
	}

	return { get, list: search, create, update };
}
