import assert from "node:assert/strict";
import test from "node:test";
import { mcpIdentity } from "./mcp.ts";

test("recognizes native MCP names without losing tool separators", () => {
	assert.deepEqual(mcpIdentity("mcp__docs__lookup__page", {}), {
		server: "docs", tool: "lookup__page",
	});
	assert.equal(mcpIdentity("bash", {}), undefined);
	assert.equal(mcpIdentity("mcp__docs", {}), undefined);
});

test("resource operations retain the server used by permission rules", () => {
	for (const tool of ["list_mcp_resources", "list_mcp_resource_templates", "read_mcp_resource"])
		assert.deepEqual(mcpIdentity(tool, { server: "docs" }), { server: "docs", tool });
	assert.deepEqual(mcpIdentity("list_mcp_resources", {}), {
		server: undefined, tool: "list_mcp_resources",
	});
});
