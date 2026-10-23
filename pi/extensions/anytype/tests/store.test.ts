import assert from "node:assert/strict";
import { once } from "node:events";
import { createServer } from "node:http";
import test from "node:test";
import { createIssueStore, IssueError, parseConfig, type IssueConfig } from "../store.ts";

const config: IssueConfig = {
	space: "space.full", type: "issue",
	properties: { kind: "issue_kind", state: "status", tags: "tag", parent: "epic", blockers: "blocked_by", assignee: "worker" },
};
const row = (id = "one", properties: Record<string, unknown> = {}) => ({
	id, type: "issue", etag: '"v1"', properties: {
		name: "Example", description: "The specification", issue_kind: ["task"], status: ["open"],
		tag: ["existing"], epic: [], blocked_by: [], worker: "", project: ["project-one"], ...properties,
	},
});
const reply = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
type Call = { path: string; method: string; headers: Headers; body: any };
function fixture(handle: (call: Call) => Response | Promise<Response>) {
	const calls: Call[] = [];
	const fetcher: typeof fetch = async (url, init) => {
		assert.equal(init?.redirect, "error");
		const headers = new Headers(init?.headers);
		assert.equal(headers.get("Authorization"), "Bearer test-key");
		const path = new URL(String(url)).pathname + new URL(String(url)).search;
		const call = { path, method: init!.method!, headers, body: init?.body ? JSON.parse(String(init.body)) : undefined };
		// Existing-project lookup is covered separately in project.test.ts.
		if (call.body?.type === "project") return reply({ data: [{ id: "project-one", name: "repo", properties: { description: "/repo" } }] });
		calls.push(call);
		return handle(call);
	};
	return { store: createIssueStore(config, async () => "test-key\n", async () => ({ name: "repo", path: "/repo" }), fetcher), calls };
}
const failure = (code: string) => (error: unknown) => error instanceof IssueError && error.code === code;

test("configuration requires an explicit existing schema and distinct property keys", () => {
	assert.deepEqual(parseConfig(config), config);
	assert.throws(() => parseConfig({ space: "x", type: "issue" }), /properties/);
	assert.throws(() => parseConfig({ ...config, properties: { ...config.properties, tags: "status" } }), /distinct/);
	assert.throws(() => parseConfig({ ...config, baseUrl: "file:///tmp/test" }), /HTTP/);
});

test("create maps issue fields without creating types or properties", async () => {
	const { store, calls } = fixture(() => reply({ id: "created", etag: '"v2"' }, 201));
	assert.deepEqual(await store.create({ title: "Bug", description: "Steps", kind: "bug", tags: ["new"], blockers: ["other"] }, "create-1"), {
		id: "created", revision: '"v2"',
	});
	assert.equal(calls.length, 1);
	assert.equal(calls[0].path, "/v2/spaces/space.full/objects?create_missing_options=true");
	assert.equal(calls[0].headers.get("Idempotency-Key"), "create-1");
	assert.deepEqual(calls[0].body, { type: "issue", name: "Bug", template: "none", properties: {
		description: "Steps", project: ["project-one"], issue_kind: ["bug"], status: ["open"], tag: ["new"], epic: [], blocked_by: ["other"],
	} });
});

test("get reads properties and paged native discussion without creating it", async () => {
	const { store, calls } = fixture(({ path }) => path.includes("/messages?")
		? reply({ messages: [{ id: "m1", author: "Member", at: "today", text: "raw", blocks_text: "comment" }], has_more: true, next_before: "order1" })
		: reply({ ...row(), discussion: "discussion/id" }));
	const result = await store.get({ id: "one", comments: true, before: "older/order", limit: 10 });
	assert.equal(result.description, "The specification");
	assert.equal(result.revision, '"v1"');
	assert.deepEqual(result.comments, { items: [{ id: "m1", author: "Member", at: "today", text: "comment" }], has_more: true, before: "order1" });
	assert.equal(calls[1].path, "/v2/spaces/space.full/chats/discussion%2Fid/messages?limit=10&before=older%2Forder");
	assert.ok(calls.every((call) => call.method === "GET"));
});

test("get without a discussion returns no comments and never creates a thread", async () => {
	const { store, calls } = fixture(() => reply(row()));
	assert.deepEqual((await store.get({ id: "one", comments: true })).comments, { items: [], has_more: false });
	assert.equal(calls.length, 1);
});

test("foreign objects are refused before mutation", async () => {
	const { store, calls } = fixture(() => reply({ ...row(), type: "page" }));
	await assert.rejects(store.update({ id: "one", claim: true }, "actor", "op"), failure("not_an_issue"));
	assert.equal(calls.length, 1);
});

test("search sends compact projection and structured filters, with no per-issue reads", async () => {
	const { store, calls } = fixture(() => reply({ data: [row()], has_more: true }));
	const result = await store.list({ query: "failure", kind: "bug", state: "open", tags: ["urgent"], exclude_tags: ["human"], parent: "epic1", assignee: "", limit: 10, offset: 20 });
	assert.equal(result.next_offset, 21);
	assert.equal(result.issues[0].title, "Example");
	assert.equal("description" in result.issues[0], false);
	assert.equal(calls.length, 1);
	assert.equal(calls[0].method, "POST");
	assert.equal(calls[0].headers.has("Idempotency-Key"), false);
	assert.deepEqual(calls[0].body, { type: "issue", query: "failure", fields: [...Object.values(config.properties), "project"], filters: [
		{ property: "project", condition: "in", value: ["project-one"] },
		{ property: "issue_kind", condition: "equal", value: "bug" },
		{ property: "status", condition: "equal", value: "open" },
		{ property: "tag", condition: "all_in", value: ["urgent"] },
		{ property: "tag", condition: "not_in", value: ["human"] },
		{ property: "epic", condition: "in", value: ["epic1"] },
		{ property: "worker", condition: "empty" },
	] });
});

test("ready checks blocker state once per ID and preserves underlying pagination", async () => {
	const { store, calls } = fixture(({ path }) => {
		if (path.includes("/search?")) return reply({ data: [row("a", { blocked_by: ["dependency"] }), row("b", { blocked_by: ["dependency"] })], has_more: true });
		return reply(row("dependency", { status: ["blocked"] }));
	});
	const result = await store.list({ ready: true, offset: 5 });
	assert.deepEqual(result.issues, []);
	assert.equal(result.next_offset, 7);
	assert.equal(result.has_more, true);
	assert.equal(calls.length, 2);
	assert.ok(calls[0].body.filters.some((f: any) => f.property === "issue_kind" && f.condition === "not_equal"));
	assert.ok(calls[0].body.filters.some((f: any) => f.property === "worker" && f.condition === "empty"));
	const closed = fixture(({ path }) => path.includes("/search?")
		? reply({ data: [row("a", { blocked_by: ["dependency"] })], has_more: false })
		: reply(row("dependency", { status: ["closed"] })));
	assert.equal((await closed.store.list({ ready: true })).issues.length, 1);
});

test("claim needs no model-supplied revision, but always sends a conditional write", async () => {
	const { store, calls } = fixture(({ method }) => method === "GET" ? reply(row()) : reply({ etag: '"v2"' }));
	assert.deepEqual(await store.update({ id: "one", claim: true }, "pi:team", "op"), { id: "one", revision: '"v2"', updated: true });
	assert.equal(calls[1].headers.get("If-Match"), '"v1"');
	assert.equal(calls[1].headers.get("Idempotency-Key"), "op:edit");
	assert.deepEqual(calls[1].body, { ops: [{ op: "set_properties", set: { worker: "pi:team", status: ["in_progress"] } }] });
});

test("two racing claims cannot both succeed; conflicts are not automatically retried", async () => {
	let current = row();
	const { store, calls } = fixture(({ method, headers, body }) => {
		if (method === "GET") return reply(current);
		if (headers.get("If-Match") !== current.etag) return reply({ code: "etag_mismatch", message: "Changed", etag: current.etag }, 409);
		current = { ...current, etag: '"v2"', properties: { ...current.properties, ...body.ops[0].set } };
		return reply({ etag: current.etag });
	});
	const results = await Promise.allSettled([
		store.update({ id: "one", claim: true }, "pi:a", "a"),
		store.update({ id: "one", claim: true }, "pi:b", "b"),
	]);
	assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
	assert.equal(results.filter((r) => r.status === "rejected" && failure("etag_mismatch")(r.reason)).length, 1);
	assert.equal(calls.filter((c) => c.method === "PATCH").length, 2);
});

test("same-team claims are no-ops; foreign claims cannot be taken or released", async () => {
	const { store, calls } = fixture(() => reply(row("one", { worker: "pi:team", status: ["in_progress"] })));
	assert.equal((await store.update({ id: "one", claim: true }, "pi:team", "op")).updated, false);
	await assert.rejects(store.update({ id: "one", claim: true }, "pi:other", "op2"), failure("already_claimed"));
	await assert.rejects(store.update({ id: "one", claim: false }, "pi:other", "op3"), failure("already_claimed"));
	assert.ok(calls.every((call) => call.method === "GET"));
});

test("closed issues cannot be claimed; release clears only the current team's assignment", async () => {
	const closed = fixture(() => reply(row("one", { status: ["closed"] })));
	await assert.rejects(closed.store.update({ id: "one", claim: true }, "pi:team", "op"), failure("not_claimable"));
	const h = fixture(({ method }) => method === "GET" ? reply(row("one", { worker: "pi:team", status: ["in_progress"] })) : reply({ etag: '"v2"' }));
	await h.store.update({ id: "one", claim: false }, "pi:team", "op");
	assert.deepEqual(h.calls[1].body.ops[0].set, { worker: "", status: ["open"] });
});

test("field edits require the observed revision, not a silently refreshed one", async () => {
	const { store, calls } = fixture(() => reply(row()));
	await assert.rejects(store.update({ id: "one", description: "new" }, "actor", "op"), failure("revision_required"));
	assert.equal(calls.length, 0);
	await assert.rejects(store.update({ id: "one", description: "new", revision: '"old"' }, "actor", "op"), failure("etag_mismatch"));
	assert.equal(calls.length, 1);
	await assert.rejects(store.update({ id: "one" }, "actor", "op"), failure("empty_update"));
	await assert.rejects(store.update({ id: "one", state: "closed", revision: '"v1"' }, "actor", "op"), failure("close_reason_required"));
});

test("field edits batch scalar and list changes atomically without replacing unrelated tags", async () => {
	const { store, calls } = fixture(({ method }) => method === "GET" ? reply(row()) : reply({ etag: '"v2"' }));
	await store.update({ id: "one", revision: '"v1"', title: "New", parent: null,
		tags: { add: ["urgent"], remove: ["needs-context"] }, blockers: { add: ["two"] },
	}, "actor", "op");
	assert.deepEqual(calls[1].body, { ops: [
		{ op: "set_properties", set: { name: "New", epic: [] } },
		{ op: "set_properties", remove: { tag: ["needs-context"] } },
		{ op: "set_properties", add: { tag: ["urgent"], blocked_by: ["two"] } },
	] });
});

test("comment-only updates use native discussion and stable per-step replay keys", async () => {
	const { store, calls } = fixture(({ method, path }) => method === "GET" ? reply(row())
		: path.endsWith("/discussion") ? reply({ id: "thread" }, 201) : reply({ id: "comment1" }, 201));
	const result = await store.update({ id: "one", comment: "Findings" }, "pi:team", "op");
	assert.equal(result.updated, false);
	assert.equal(result.comment_id, "comment1");
	assert.deepEqual(calls.map((c) => c.method), ["GET", "POST", "POST"]);
	assert.equal(calls[1].headers.get("Idempotency-Key"), "op:discussion");
	assert.equal(calls[2].headers.get("Idempotency-Key"), "op:comment");
	assert.deepEqual(calls[2].body, { text: "pi:team:\nFindings" });
});

test("close plus comment reports committed fields when posting the comment fails", async () => {
	const { store, calls } = fixture(({ method, path }) => {
		if (method === "GET") return reply({ ...row(), discussion: "thread" });
		if (method === "PATCH") return reply({ etag: '"v2"' });
		assert.ok(path.endsWith("/messages"));
		return reply({ code: "forbidden", message: "Comment refused" }, 403);
	});
	await assert.rejects(store.update({ id: "one", revision: '"v1"', state: "closed", comment: "Fixed" }, "actor", "op"), (error) => {
		assert.ok(error instanceof IssueError);
		assert.equal(error.code, "comment_failed");
		assert.deepEqual(error.details, { id: "one", updated: true, revision: '"v2"', cause: "forbidden", comment: "not_sent" });
		return true;
	});
	assert.equal(calls.length, 3);
});

test("lost comment responses report unknown outcome without automatic retry", async () => {
	const { store, calls } = fixture(({ method }) => {
		if (method === "GET") return reply({ ...row(), discussion: "thread" });
		throw new Error("connection lost");
	});
	await assert.rejects(store.update({ id: "one", comment: "Findings" }, "actor", "op"), (error) => {
		assert.ok(error instanceof IssueError);
		assert.equal(error.code, "comment_failed");
		assert.equal(error.details.updated, false);
		assert.match(String(error.details.comment), /unknown/);
		return true;
	});
	assert.equal(calls.length, 2);
});

test("unmatched v2 routes and malformed write receipts remain actionable", async () => {
	const missing = fixture(() => new Response("Not found", { status: 404 }));
	await assert.rejects(missing.store.get({ id: "one" }), failure("http_404"));
	const malformed = fixture(({ method }) => method === "GET" ? reply(row()) : new Response("invalid"));
	await assert.rejects(malformed.store.update({ id: "one", claim: true }, "actor", "op"), failure("write_outcome_unknown"));
});

test("native fetch carries authentication, replay key and revision over HTTP", async (t) => {
	const calls: { method: string; url: string; headers: Record<string, unknown>; body: any }[] = [];
	const server = createServer(async (req, res) => {
		let body = "";
		for await (const chunk of req) body += chunk;
		calls.push({ method: req.method!, url: req.url!, headers: req.headers, body: body ? JSON.parse(body) : undefined });
		res.setHeader("Content-Type", "application/json");
		const result = req.url?.includes("/search?") ? { data: [{ id: "project-one", name: "repo", properties: { description: "/repo" } }] }
			: req.method === "GET" ? row() : { etag: '"v2"' };
		res.end(JSON.stringify(result));
	});
	server.listen(0, "127.0.0.1");
	await once(server, "listening");
	t.after(() => new Promise<void>((resolve) => { server.closeAllConnections(); server.close(() => resolve()); }));
	const address = server.address();
	assert.ok(address && typeof address !== "string");
	const store = createIssueStore({ ...config, baseUrl: `http://127.0.0.1:${address.port}` }, async () => "dummy-key", async () => ({ name: "repo", path: "/repo" }));
	assert.equal((await store.update({ id: "one", claim: true }, "pi:team", "operation")).updated, true);
	assert.equal(calls[0].headers.authorization, "Bearer dummy-key");
	const patch = calls.find((call) => call.method === "PATCH")!;
	assert.equal(patch.headers["if-match"], '"v1"');
	assert.equal(patch.headers["idempotency-key"], "operation:edit");
	assert.equal(patch.body.ops[0].set.worker, "pi:team");
});

test("missing etags, missing actor and oversized comments fail before any write", async () => {
	const { store, calls } = fixture(() => reply({ ...row(), etag: undefined }));
	await assert.rejects(store.update({ id: "one", claim: true }, "actor", "op"), failure("missing_revision"));
	await assert.rejects(store.update({ id: "one", claim: true }, "", "op"), failure("missing_actor"));
	await assert.rejects(store.update({ id: "one", comment: "x".repeat(8000) }, "actor", "op"), failure("invalid_comment"));
	assert.ok(calls.every((call) => call.method === "GET"));
});
