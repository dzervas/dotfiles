import assert from "node:assert/strict";
import test from "node:test";
import { documentLink, relatedIssues } from "../related.ts";
import type { Issue, ListInput } from "../store.ts";

const issue = (id: string, fields: Partial<Issue> = {}): Issue => ({
	id, title: id, kind: "task", state: "open", tags: [], parent: null, blockers: [], assignee: null, ...fields,
});

function fixture(issues: Issue[]) {
	const lists: ListInput[] = [];
	const gets: string[] = [];
	const store = {
		async list(input: ListInput = {}) {
			lists.push(input);
			assert.ok(input.assignee || input.parent, "never enumerate unrelated space issues");
			const matches = issues.filter((row) => input.assignee ? row.assignee === input.assignee : row.parent === input.parent);
			const offset = input.offset ?? 0;
			// Force pagination even though the caller requests up to 100 rows.
			const page = matches.slice(offset, offset + 1);
			const has_more = offset + page.length < matches.length;
			return { issues: page, has_more, next_offset: has_more ? offset + page.length : null };
		},
		async get({ id, comments }: { id: string; comments?: boolean }) {
			assert.equal(comments, false);
			gets.push(id);
			const row = issues.find((row) => row.id === id);
			assert.ok(row);
			return { ...row, description: "", revision: "r1" };
		},
	};
	return { store, lists, gets };
}

test("current claims bring their epic, siblings and direct blockers, deduplicated", async () => {
	const h = fixture([
		issue("active", { state: "in_progress", assignee: "pi:team", parent: "epic", blockers: ["sibling", "external"] }),
		issue("historical", { state: "closed", assignee: "pi:team", parent: "old-epic" }),
		issue("epic", { kind: "epic" }),
		issue("sibling", { parent: "epic", assignee: "pi:other" }),
		issue("finished-sibling", { parent: "epic", state: "closed" }),
		issue("external", { state: "blocked", blockers: ["transitive"] }),
		issue("unrelated"),
	]);
	const rows = await relatedIssues(h.store, "pi:team", "space.full");
	assert.deepEqual(rows.map((row) => [row.issue.id, row.relations]), [
		["active", ["claimed"]], ["epic", ["epic"]], ["sibling", ["sibling", "blocker"]],
		["finished-sibling", ["sibling"]], ["external", ["blocker"]],
	]);
	assert.deepEqual(h.gets, ["epic", "external"]);
	assert.ok(h.lists.some((input) => input.assignee === "pi:team" && input.offset === 1));
	assert.ok(h.lists.some((input) => input.parent === "epic" && input.offset === 2));
	assert.ok(rows.every((row) => new URL(row.url).searchParams.get("spaceId") === "space.full"));
});

test("claimed epics show children without fetching the epic twice", async () => {
	const h = fixture([
		issue("epic", { kind: "epic", state: "in_progress", assignee: "pi:team" }),
		issue("child", { parent: "epic" }),
	]);
	const rows = await relatedIssues(h.store, "pi:team", "space");
	assert.deepEqual(rows.map((row) => [row.issue.id, row.relations]), [["epic", ["claimed"]], ["child", ["child"]]]);
	assert.deepEqual(h.gets, []);
});

test("no active claims stays empty rather than showing other teams or unassigned work", async () => {
	const h = fixture([issue("other", { assignee: "pi:other" }), issue("old", { assignee: "pi:team", state: "closed" }), issue("unassigned")]);
	assert.deepEqual(await relatedIssues(h.store, "pi:team", "space"), []);
	assert.deepEqual(h.gets, []);
	const before = h.lists.length;
	await assert.rejects(relatedIssues(h.store, "", "space"), /actor/);
	assert.equal(h.lists.length, before);
});

test("document links use Desktop's anytype object route and encode query values", () => {
	const link = documentLink("space.full&other=value", "object/id?name=hello world");
	const url = new URL(link);
	assert.equal(url.protocol, "anytype:");
	assert.equal(url.hostname, "object");
	assert.equal(url.searchParams.get("objectId"), "object/id?name=hello world");
	assert.equal(url.searchParams.get("spaceId"), "space.full&other=value");
	assert.equal(url.searchParams.size, 2);
});
