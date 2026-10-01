const RESOURCE_TOOLS = new Set([
	"list_mcp_resources",
	"list_mcp_resource_templates",
	"read_mcp_resource",
]);

/** Native MCP names preserve separators inside the tool's name. */
export function mcpIdentity(toolName: string, input: Record<string, unknown>) {
	const match = /^mcp__(.+?)__(.+)$/u.exec(toolName);
	if (match) return { server: match[1], tool: match[2] };
	if (RESOURCE_TOOLS.has(toolName))
		return {
			server: typeof input.server === "string" ? input.server : undefined,
			tool: toolName,
		};
	return undefined;
}
