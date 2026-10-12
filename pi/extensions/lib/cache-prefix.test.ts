import assert from "node:assert/strict";
import test from "node:test";
import { fingerprint, prefixChange } from "./cache-prefix.ts";

const tool = (name: string, description = "d") => ({ type: "function", function: { name, description, parameters: {} } });
const SYSTEM = "You are pi.\n\n# Learned memory\n\nnote A\n\n# Beads\n\nuse bd";

/** An OpenAI Chat Completions payload the way pi builds it, cache marker on the newest message. */
function openai(messages: string[], options: { system?: string; tools?: unknown[] } = {}) {
	const body = messages.map((content, i) =>
		i === messages.length - 1
			? { role: i % 2 ? "assistant" : "user", content: [{ type: "text", text: content, cache_control: { type: "ephemeral" } }] }
			: { role: i % 2 ? "assistant" : "user", content },
	);
	return {
		model: "m",
		tools: options.tools ?? [tool("read"), tool("bash")],
		messages: [{ role: "system", content: [{ type: "text", text: options.system ?? SYSTEM, cache_control: { type: "ephemeral" } }] }, ...body],
	};
}

const change = (a: unknown, b: unknown) => prefixChange(fingerprint(a)!, fingerprint(b)!);

test("a request that extends the previous one is not a change, despite the moved cache marker", () => {
	assert.equal(change(openai(["hi"]), openai(["hi", "hello", "next"])), undefined);
});

test("tool additions, removals, reorders, and definition edits are named", () => {
	assert.equal(change(openai(["hi"]), openai(["hi"], { tools: [tool("read"), tool("bash"), tool("todo")] })), "tools +todo");
	assert.equal(change(openai(["hi"]), openai(["hi"], { tools: [tool("read")] })), "tools -bash");
	assert.equal(change(openai(["hi"]), openai(["hi"], { tools: [tool("bash"), tool("read")] })), "tools reordered");
	assert.equal(change(openai(["hi"]), openai(["hi"], { tools: [tool("read"), tool("bash", "new")] })), "tool definition changed: bash");
});

test("a system prompt edit names the section it falls in", () => {
	const edited = SYSTEM.replace("note A", "note B");
	assert.equal(change(openai(["hi"]), openai(["hi"], { system: edited })), 'system prompt changed near "# Learned memory"');
});

test("rewritten or dropped messages report where the conversation diverged", () => {
	assert.equal(change(openai(["hi", "hello", "q"]), openai(["hi", "HELLO", "q", "a"])), "message 2 of 3 changed");
	assert.equal(change(openai(["hi", "hello", "q"]), openai(["hi"])), "conversation cut from 3 to 1 messages");
});

test("Anthropic payloads use the top-level system and tool names", () => {
	const anthropic = (system: string, tools: string[]) => ({
		system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
		tools: tools.map((name) => ({ name, input_schema: {} })),
		messages: [{ role: "user", content: "hi" }],
	});
	assert.equal(change(anthropic(SYSTEM, ["read"]), anthropic(SYSTEM, ["read"])), undefined);
	assert.equal(
		change(anthropic(SYSTEM, ["read"]), anthropic(`${SYSTEM}!`, ["read", "edit"])),
		'tools +edit; system prompt changed near "# Beads"',
	);
});

test("payloads without messages are not fingerprinted", () => {
	assert.equal(fingerprint({ input: "x" }), undefined);
	assert.equal(fingerprint(null), undefined);
});
