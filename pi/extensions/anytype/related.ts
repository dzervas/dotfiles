import type { createIssueStore, Issue, ListInput } from "./store.ts";

type Store = Pick<ReturnType<typeof createIssueStore>, "get" | "list">;
type Relation = "claimed" | "epic" | "sibling" | "child" | "blocker";

// Matches Desktop's U.Object.universalRoute / copyLink (anytype-ts).
export function documentLink(space: string, id: string): string {
	return `anytype://object?${new URLSearchParams({ objectId: id, spaceId: space })}`;
}

/** Current team's non-closed claims plus their immediate work context, not the whole space. */
export async function relatedIssues(store: Store, actor: string, space: string, signal?: AbortSignal) {
	if (!actor) throw new Error("Anytype session actor is unavailable.");
	async function list(filter: ListInput) {
		const issues: Issue[] = [];
		let offset = 0;
		while (true) {
			const page = await store.list({ ...filter, limit: 100, offset }, signal);
			issues.push(...page.issues);
			if (page.next_offset === null) return issues;
			offset = page.next_offset;
		}
	}

	const claimed = (await list({ assignee: actor })).filter((issue) => issue.state !== "closed");
	const rows = new Map<string, { issue: Issue; relations: Relation[]; url: string }>();
	function add(issue: Issue, relation: Relation) {
		const row = rows.get(issue.id);
		if (!row) rows.set(issue.id, { issue, relations: [relation], url: documentLink(space, issue.id) });
		else if (!row.relations.includes(relation)) row.relations.push(relation);
	}
	for (const issue of claimed) add(issue, "claimed");
	const epics = new Set(claimed.flatMap((issue) => issue.kind === "epic" ? [issue.id] : issue.parent ? [issue.parent] : []));
	for (const id of epics) {
		if (!rows.has(id)) add(await store.get({ id, comments: false }, signal), "epic");
		const relation = claimed.some((issue) => issue.id === id) ? "child" : "sibling";
		for (const issue of await list({ parent: id })) {
			if (!claimed.some((claim) => claim.id === issue.id)) add(issue, relation);
		}
	}
	for (const issue of claimed) {
		for (const id of issue.blockers) {
			add(rows.get(id)?.issue ?? await store.get({ id, comments: false }, signal), "blocker");
		}
	}
	return [...rows.values()];
}
