import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { createRequire, register } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import test from "node:test";

// Use Pi's real schemas, while isolating the user's configuration and credentials.
const require = createRequire("/etc/profiles/per-user/dzervas/lib/node_modules/pi-monorepo/package.json");
const typebox = pathToFileURL(require.resolve("typebox")).href;
const { Check } = await import(pathToFileURL(require.resolve("typebox/value")).href);
register(`data:text/javascript,${encodeURIComponent(`
export async function resolve(specifier, context, next) {
  if (specifier === "typebox") return { url: ${JSON.stringify(typebox)}, shortCircuit: true };
  if (specifier === "@earendil-works/pi-ai") return {
    url: "data:text/javascript," + encodeURIComponent('import { Type } from ${JSON.stringify(typebox)}; export const StringEnum = values => Type.Union(values.map(value => Type.Literal(value)));'),
    shortCircuit: true
  };
  if (specifier === "node:os" && context.parentURL?.endsWith("/anytype/client.ts")) return {
    url: "data:text/javascript," + encodeURIComponent('export const homedir = () => process.env.ISSUES_TEST_HOME;'),
    shortCircuit: true
  };
  return next(specifier, context);
}
`)}`, import.meta.url);
const { default: extension } = await import("../index.ts");
const config = {
	space: "space", type: "issue",
	properties: { kind: "kind", state: "status", tags: "tag", parent: "parent", blockers: "blockers", assignee: "worker" },
};

test("Pi adapter is opt-in, registers four compact tools, and resolves credentials only on use", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "pi-anytype-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const environment = process.env;
	process.env = { ISSUES_TEST_HOME: directory };
	t.after(() => { process.env = environment; });
	const tools = new Map<string, any>();
	const handlers = new Map<string, any>();
	let executions = 0;
	const pi = {
		registerTool: (tool: any) => tools.set(tool.name, tool),
		on: (name: string, handler: any) => handlers.set(name, handler),
		async exec(command: string, args: string[]) {
			if (command === "git") return { code: 128, stdout: "" };
			executions++;
			assert.equal(command, "op");
			assert.deepEqual(args, ["read", "op://Private/AnyType Local Key/api"]);
			return { code: 0, stdout: "dummy-key\n" };
		},
	};
	extension(pi as any);
	assert.equal(tools.size, 0);
	await mkdir(join(directory, ".pi", "agent"), { recursive: true });
	await writeFile(join(directory, ".pi", "agent", "anytype.json"), JSON.stringify(config));
	extension(pi as any);
	assert.deepEqual([...tools.keys()], ["issue_list", "issue_get", "issue_create", "issue_update"]);
	assert.equal(executions, 0);
	assert.ok(Check(tools.get("issue_update").parameters, { id: "one", claim: true }));
	assert.ok(Check(tools.get("issue_update").parameters, { id: "one", revision: "r1", state: "closed", comment: "Fixed" }));
	assert.equal(Check(tools.get("issue_update").parameters, { id: "one", state: "invalid" }), false);
	assert.equal(Check(tools.get("issue_list").parameters, { limit: 1000 }), false);
	assert.equal(Check(tools.get("issue_update").parameters, { id: "one", surprise: "value" }), false);
	assert.ok(JSON.stringify(tools.get("issue_update").parameters).length < 2500);

	const requests: { url: string; method: string; body: any; headers: Headers }[] = [];
	t.mock.method(globalThis, "fetch", async (url: string, init: RequestInit) => {
		const body = init.body && JSON.parse(String(init.body));
		if (body?.type === "project") return new Response(JSON.stringify({ data: [{ id: "project-one", name: "repo", properties: { description: directory } }] }));
		requests.push({ url: String(url), method: init.method!, body, headers: new Headers(init.headers) });
		if (init.method === "GET") return new Response(JSON.stringify({
			id: "one", type: "issue", etag: '"r1"', discussion: "thread",
			properties: { name: "Example", description: "Details", kind: ["task"], status: ["open"], worker: "", tag: [], parent: [], blockers: [], project: ["project-one"] },
		}));
		return new Response(JSON.stringify({ etag: '"r2"' }));
	});
	const ctx = { cwd: directory, mode: "tui", sessionManager: { getSessionId: () => "team", getHeader: () => ({}) } };
	handlers.get("session_start")({}, ctx);
	const tool = tools.get("issue_update");
	const result = await tool.execute("call1", { id: "one", claim: true }, undefined, undefined, ctx);
	assert.equal(result.isError, undefined);
	assert.deepEqual(result.structuredContent, { id: "one", revision: '"r2"', updated: true });
	assert.equal(executions, 1, "one credential lookup for the whole multi-request operation");
	assert.equal(requests[1].headers.get("If-Match"), '"r1"');
	assert.equal(requests[1].body.ops[0].set.worker, "pi:team");

	const failure = await tool.execute("call2", { id: "one", description: "new" }, undefined, undefined, ctx);
	assert.equal(failure.isError, true);
	assert.equal(failure.structuredContent.error, "revision_required");
	assert.equal(executions, 1, "validation failures do not read credentials");
	handlers.get("session_shutdown")({}, ctx);
});
