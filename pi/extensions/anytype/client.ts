import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createIssueStore, IssueError, parseConfig, type IssueConfig } from "./store.ts";
import { projectIdentity } from "./project.ts";

// Opt in with ~/.pi/agent/anytype.json (schema keys, not credentials):
// { "space": "<full space id>", "type": "issue", "properties": {
//   "kind": "kind", "state": "status", "tags": "tag", "parent": "parent",
//   "blockers": "blockers", "assignee": "assignee", "project": "project" } }
// Project objects use type key project by default (override with projectType).
// Projects are reused by the canonical repo/directory path in Description.
// Use your existing property's stable keys. Expected formats are in store.ts.
// kind options: task/bug/epic; state options: open/in_progress/blocked/closed.
// Descriptions use Anytype's description property; document blocks stay untouched.
// Credentials: ANYTYPE_API_KEY, otherwise op://Private/AnyType Local Key/api.
// That item must contain a key issued by the Desktop instance being used.
// baseUrl is optional and defaults to http://127.0.0.1:31009.
export function loadAnytypeConfig(): IssueConfig | undefined {
	const path = join(homedir(), ".pi", "agent", "anytype.json");
	return existsSync(path) ? parseConfig(JSON.parse(readFileSync(path, "utf8"))) : undefined;
}

export function anytypeStore(pi: ExtensionAPI, config: IssueConfig, ctx: ExtensionContext, signal?: AbortSignal) {
	// Resolve once per operation, not at extension load or for every HTTP request.
	let credential: Promise<string> | undefined;
	return createIssueStore(config, () => credential ??= (async () => {
		if (process.env.ANYTYPE_API_KEY) return process.env.ANYTYPE_API_KEY;
		const result = await pi.exec("op", ["read", "op://Private/AnyType Local Key/api"], { cwd: ctx.cwd, signal, timeout: 15000 });
		if (result.code !== 0) throw new IssueError("missing_credentials", "Could not resolve the Anytype Desktop key. Unlock 1Password or provide ANYTYPE_API_KEY.");
		return result.stdout;
	})(), () => projectIdentity(ctx.cwd, (args) => pi.exec("git", args, { cwd: ctx.cwd, signal, timeout: 5000 })));
}
