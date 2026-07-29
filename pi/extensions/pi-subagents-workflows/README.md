# Pi workflows

A small Pi extension for coordinating `@gotgenes/pi-subagents` from a JavaScript workflow. It registers `workflow` and `workflow_control` plus `/workflows`.

A script must start with static metadata:

```js
export const meta = {
	name: "review",
	description: "Review a change in parallel",
};

phase("research");
const reports = await parallel([
	() => agent("Review the implementation", { agentType: "general-purpose" }),
	() => agent("Look for tests", { model: "haiku" }),
]);
return reports;
```

Available globals are `agent(prompt, options?)`, `parallel(thunks)`, `pipeline(items, ...stages)`, `phase(title)`, `log(message)`, `args`, `cwd`, and `process.cwd()`.

`pipeline` processes each item through its stages sequentially while items run concurrently. Each stage receives `(value, originalItem, index)`. Agent options are `agentType`, `model`, `thinking`, `label`, `maxTurns`, `schema`, and `schemaRetries`. A schema adds a JSON-only instruction, validates with Ajv, and retries with a fresh agent (two retries by default, at most five).

The extension limits agents per workflow (default concurrency 4 and default `maxAgents` 100). Agents are spawned with `foreground: true`, so only the workflow sends its one background completion message.

## Deliberate omissions

This is an in-memory runner: workflow state is not restored after reload or session changes. It has no workflow files, scheduling, durable logs, custom TUI, or direct Pi tool-dispatch implementation. `tool()` is deliberately disabled: workflows must use `agent()`, whose child session loads the parent's extensions, including the permission gate.
