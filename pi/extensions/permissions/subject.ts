// Normalizes a tool_call event into a PermissionSubject: tool identity
// (builtin/custom/MCP) plus paths for the trivially path-shaped builtin tools.
// Bash commands are analyzed later by the classifier pipeline (classify/).

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { isToolCallEventType, type ToolCallEvent } from "@earendil-works/pi-coding-agent";
import { pushPath } from "./paths";
import type { PermissionSubject, ToolKind } from "./types";

const MCP_CACHE_PATH = path.join(os.homedir(), ".pi", "agent", "mcp-cache.json");

// MCP tools are registered as `${serverPrefix}_${toolName}` by pi-mcp-adapter,
// where the server prefix is the server name with dashes turned into underscores.
// Read the live server list to recover the originating server via longest-prefix match.
function loadMcpServers(): string[] {
	try {
		const parsed = JSON.parse(fs.readFileSync(MCP_CACHE_PATH, "utf8")) as { servers?: unknown };
		const names = Array.isArray(parsed.servers)
			? parsed.servers.filter((server): server is string => typeof server === "string")
			: typeof parsed.servers === "object" && parsed.servers !== null
				? Object.keys(parsed.servers)
				: [];
		return names
			.map((server) => server.replace(/-/gu, "_"))
			.sort((left, right) => right.length - left.length);
	} catch {
		return [];
	}
}

function parseMcp(toolName: string) {
	const legacy = toolName.split("__");
	if (legacy[0] === "mcp") return { server: legacy[1], tool: legacy[2] };

	for (const server of loadMcpServers()) {
		if (toolName.startsWith(`${server}_`))
			return { server, tool: toolName.slice(server.length + 1) };
	}
	return undefined;
}

// Extract any meaningful info from the event to create a subject
export function normalize(event: ToolCallEvent): PermissionSubject {
	const mcp = parseMcp(event.toolName);
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

	return subject;
}
