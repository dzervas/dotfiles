import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { projectIdentity } from "../project.ts";
import { createIssueStore, IssueError, parseConfig, type IssueConfig } from "../store.ts";

const config: IssueConfig = {
	space: "space", type: "task",
	properties: { kind: "kind", state: "state", tags: "tag", parent: "parent", blockers: "blockers", assignee: "assignee" },
};
const identity = { name: "dotfiles", path: "/home/me/Lab/dotfiles" };
const project = (id: string, name: string, path: string) => ({ id, name, type: "project", properties: { description: path } });
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const failure = (code: string) => (error: unknown) => error instanceof IssueError && error.code === code;

function fixture(projects: ReturnType<typeof project>[] = [], settings = config) {
	const calls: { method: string; path: string; body: any; headers: Headers }[] = [];
	const replay = new Map<string, { id: string }>();
	const issue = { id: "issue-one", type: "task", etag: "r1", properties: {
		name: "Issue", kind: ["task"], state: ["open"], project: ["project-new"],
	} };
	let warnings: unknown[] | undefined;
	const fetcher: typeof fetch = async (url, init) => {
		const call = { method: init!.method!, path: new URL(String(url)).pathname,
			body: init?.body ? JSON.parse(String(init.body)) : undefined, headers: new Headers(init?.headers) };
		calls.push(call);
		if (call.path.endsWith("/search") && call.body.type === (settings.projectType ?? "project")) {
			const filter = call.body.filters[0];
			const matches = projects.filter((p) => (filter.property === "name" ? p.name : p.properties.description) === filter.value);
			return reply({ data: matches.slice(0, 2), warnings });
		}
		if (call.path.endsWith("/objects") && call.body.type === (settings.projectType ?? "project")) {
			const key = call.headers.get("Idempotency-Key")!;
			if (replay.has(key)) return reply(replay.get(key), 201);
			projects.push(project("project-new", call.body.name, call.body.properties.description));
			const result = { id: "project-new" };
			replay.set(key, result);
			return reply(result, 201);
		}
		if (call.path.endsWith("/search")) return reply({ data: [], has_more: false });
		if (call.method === "GET") return reply(issue);
		return reply({ id: "created-issue", etag: "r2" });
	};
	const makeStore = () => createIssueStore(settings, async () => "dummy-key", async () => identity, fetcher);
	return { store: makeStore(), makeStore, projects, calls, issue, setWarnings: (value: unknown[]) => { warnings = value; } };
}

test("first use creates the repo's Project with full path and scopes issue search", async () => {
	const h = fixture();
	await h.store.list();
	assert.deepEqual(h.projects, [project("project-new", "dotfiles", identity.path)]);
	const create = h.calls.find((call) => call.path.endsWith("/objects"))!;
	assert.deepEqual(create.body, { type: "project", name: "dotfiles", template: "none", properties: { description: identity.path } });
	assert.match(create.headers.get("Idempotency-Key")!, /^project:[a-f0-9]{64}$/);
	const issueSearch = h.calls.at(-1)!;
	assert.deepEqual(issueSearch.body.filters[0], { property: "project", condition: "in", value: ["project-new"] });
	await h.store.list();
	assert.equal(h.calls.filter((call) => call.body?.type === "project" && call.path.endsWith("/search")).length, 2, "project resolution is reused within one operation's store");
});

test("same path reuses its Project even after a user renames it", async () => {
	const h = fixture([project("existing", "My renamed project", identity.path)]);
	await h.store.list();
	assert.equal(h.calls.length, 2);
	assert.equal(h.projects.length, 1);
	assert.deepEqual(h.calls[1].body.filters[0].value, ["existing"]);
});

test("a basename clash prefixes the parent directory; a second clash fails explicitly", async () => {
	const h = fixture([project("other", "dotfiles", "/someone/else/dotfiles")]);
	await h.store.list();
	assert.equal(h.projects[1].name, "Lab/dotfiles");
	assert.equal(h.projects[1].properties.description, identity.path);
	const clash = fixture([
		project("other", "dotfiles", "/someone/else/dotfiles"),
		project("third", "Lab/dotfiles", "/another/Lab/dotfiles"),
	]);
	await assert.rejects(clash.store.list(), failure("project_name_collision"));
	assert.equal(clash.projects.length, 2);
	assert.ok(clash.calls.every((call) => call.path.endsWith("/search")));
});

test("ambiguous path matches and incomplete search refuse to create duplicates", async () => {
	const duplicate = fixture([project("one", "dotfiles", identity.path), project("two", "other", identity.path)]);
	await assert.rejects(duplicate.store.list(), failure("ambiguous_project"));
	const loading = fixture();
	loading.setWarnings([{ message: "Space still loading" }]);
	await assert.rejects(loading.store.list(), failure("project_lookup_incomplete"));
	assert.equal(loading.projects.length, 0);
});

test("concurrent first use of the same path has the same replay key and one Project", async () => {
	const h = fixture();
	await Promise.all([h.store.list(), h.makeStore().list()]);
	assert.equal(h.projects.length, 1);
	const creates = h.calls.filter((call) => call.path.endsWith("/objects"));
	assert.ok(creates.length > 0);
	assert.equal(new Set(creates.map((call) => call.headers.get("Idempotency-Key"))).size, 1);
});

test("new issues get the project implicitly; reads and writes reject other projects", async () => {
	const h = fixture();
	await h.store.create({ title: "Issue" }, "create");
	const create = h.calls.find((call) => call.body?.type === "task" && call.path.endsWith("/objects"))!;
	assert.deepEqual(create.body.properties.project, ["project-new"]);
	assert.equal((await h.store.get({ id: "issue-one" })).title, "Issue");
	h.issue.properties.project = ["other-project"];
	await assert.rejects(h.store.get({ id: "issue-one" }), failure("wrong_project"));
	await assert.rejects(h.store.update({ id: "issue-one", claim: true }, "actor", "claim"), failure("wrong_project"));
	assert.equal(h.calls.filter((call) => call.method === "PATCH").length, 0);
});

test("existing schema keys can override the Project type and relation", async () => {
	const settings = { ...config, projectType: "code_project", properties: { ...config.properties, project: "repository" } };
	assert.deepEqual(parseConfig(settings), settings);
	assert.throws(() => parseConfig({ ...config, properties: { ...config.properties, project: "kind" } }), /distinct/);
	const h = fixture([], settings);
	await h.store.create({ title: "Issue" }, "create");
	assert.equal(h.calls.find((call) => call.path.endsWith("/objects"))!.body.type, "code_project");
	assert.deepEqual(h.calls.at(-1)!.body.properties.repository, ["project-new"]);
});

test("Git naming uses the repository root, even from a nested directory", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "anytype-project-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const repo = join(directory, "dotfiles");
	const nested = join(repo, "home");
	await mkdir(nested, { recursive: true });
	const result = await projectIdentity(nested, async (args) => {
		assert.deepEqual(args, ["rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"]);
		return { code: 0, stdout: `${repo}\n${repo}/.git\n` };
	});
	assert.deepEqual(result, { name: "dotfiles", path: repo });
});

test("linked worktrees share the main repo; submodules keep their own identity", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "anytype-project-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const repo = join(directory, "dotfiles");
	const tree = join(directory, "feature-worktree");
	const submodule = join(repo, "module");
	await mkdir(submodule, { recursive: true });
	await mkdir(tree);
	assert.deepEqual(await projectIdentity(tree, async () => ({ code: 0, stdout: `${tree}\n${repo}/.git\n` })), { name: "dotfiles", path: repo });
	assert.deepEqual(await projectIdentity(submodule, async () => ({ code: 0, stdout: `${submodule}\n${repo}/.git/modules/module\n` })), { name: "module", path: submodule });
});

test("outside Git the directory is used, with symlinks resolved to the full path", async (t) => {
	const directory = await mkdtemp(join(tmpdir(), "anytype-project-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const actual = join(directory, "notes");
	const alias = join(directory, "alias");
	await mkdir(actual);
	await symlink(actual, alias);
	assert.deepEqual(await projectIdentity(alias, async () => ({ code: 128, stdout: "" })), { name: "notes", path: actual });
});
