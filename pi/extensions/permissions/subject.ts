// Normalizes a tool_call event into a PermissionSubject: tool identity
// (builtin/custom/MCP) plus paths for the trivially path-shaped builtin tools.
// Bash commands are analyzed later by the classifier pipeline (classify/).

import { isToolCallEventType, type ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { mcpIdentity } from "./mcp";
import { pushPath } from "./paths";
import type { PermissionSubject, ToolKind } from "./types";

// Extract any meaningful info from the event to create a subject
export function normalize(event: ToolCallEvent): PermissionSubject {
	const mcp = mcpIdentity(event.toolName, event.input);
	let toolKind: ToolKind = "custom";

	// TODO: Access these procedurally
	switch (event.toolName) {
		case "bash":
		case "read":
		case "edit":
		case "write":
		case "grep":
		case "find":
		case "ls":
			toolKind = "builtin";
			break;
		default:
			toolKind = mcp ? "mcp" : "custom";
			break;
	}

	const subject: PermissionSubject = {
		toolName: event.toolName,
		toolKind,
		mcpServer: mcp?.server,
		mcpTool: mcp?.tool,
		rawInput: isToolCallEventType("bash", event)
			? event.input.command
			: JSON.stringify(event.input),
		input: event.input,
		paths: [],
		commands: [],
		findings: [],
	};

	if (isToolCallEventType("read", event)) pushPath(subject.paths, event.input.path, "read");
	else if (isToolCallEventType("edit", event) || isToolCallEventType("write", event))
		pushPath(subject.paths, event.input.path, "write");
	else if (isToolCallEventType("grep", event) || isToolCallEventType("find", event))
		pushPath(
			subject.paths,
			typeof event.input.path === "string" ? event.input.path : ".",
			"search",
		);
	else if (isToolCallEventType("ls", event))
		pushPath(subject.paths, typeof event.input.path === "string" ? event.input.path : ".", "list");

	// memory has no filesystem path any more: it is an atuin kv namespace, so it is guarded by tool name.

	return subject;
}
