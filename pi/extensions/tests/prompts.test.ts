import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import test from "node:test";
import { getPrompt, parsePrompts } from "../lib/prompts.ts";

const root = fileURLToPath(new URL("../", import.meta.url));

test("extracts named Markdown blocks without exposing the preamble or markers", () => {
	const prompts = parsePrompts("# Notes\r\n\r\n=== ext:first system ===\r\n\r\nFirst line\r\n  indented line\r\n\r\n=== ext:second tool.description ===\r\nSecond prompt\r\n");
	assert.deepEqual([...prompts], [
		["ext:first system", "First line\n  indented line"],
		["ext:second tool.description", "Second prompt"],
	]);
});

test("rejects duplicate, empty and missing sections instead of returning the wrong prompt", () => {
	assert.throws(() => parsePrompts("=== ext:test system ===\na\n=== ext:test system ===\nb"), /Duplicate prompt marker/);
	assert.throws(() => parsePrompts("=== ext:test empty ===\n\n"), /Empty prompt/);
	assert.throws(() => getPrompt("does-not-exist", "missing"), /Missing prompt/);
});

test("catalogue callers have real sections, and every section has a caller", () => {
	const catalogue = parsePrompts(readFileSync(join(root, "prompts.md"), "utf8"));
	const called = new Set<string>();
	function scan(directory: string) {
		for (const entry of readdirSync(directory, { withFileTypes: true })) {
			if (entry.name === "tests" || entry.name === "node_modules") continue;
			const path = join(directory, entry.name);
			if (entry.isDirectory()) scan(path);
			else if (entry.name.endsWith(".ts") && !entry.name.endsWith(".test.ts")) {
				const source = readFileSync(path, "utf8");
				for (const call of source.matchAll(/getPrompt\(\s*"([\w.-]+)"\s*,\s*"([\w.-]+)"/g)) {
					const key = `ext:${call[1]} ${call[2]}`;
					assert.ok(catalogue.has(key), `${path} references missing ${key}`);
					called.add(key);
				}
			}
		}
	}
	scan(root);
	const settings = readFileSync(new URL("../../../home/ai.nix", import.meta.url), "utf8");
	for (const call of settings.matchAll(/piExtensionPrompt\s+"([\w.-]+)"\s+"([\w.-]+)"/g)) {
		const key = `ext:${call[1]} ${call[2]}`;
		assert.ok(catalogue.has(key), `home/ai.nix references missing ${key}`);
		called.add(key);
	}
	assert.ok(called.size > 0);
	assert.deepEqual([...catalogue.keys()].sort(), [...called].sort());
});

test("renders numeric values and rejects inherited variables", () => {
	assert.match(getPrompt("context-squash", "compaction-nudge", { usage: 85 }), /85 of the window/);
	assert.throws(() => getPrompt("context-squash", "compaction-nudge", Object.create({ usage: "inherited" })), /Missing prompt variable/);
});

test("renders catalogue variables in one pass, leaving inserted text and JSON literal", () => {
	const catalogue = parsePrompts(readFileSync(join(root, "prompts.md"), "utf8"));
	const entry = [...catalogue].find(([, text]) => /\{\{\w+\}\}/.test(text));
	assert.ok(entry, "catalogue should contain a dynamic prompt");
	const [key, template] = entry;
	const [, extension, marker] = /^ext:([\w.-]+) ([\w.-]+)$/.exec(key)!;
	const variables: Record<string, string> = {};
	for (const token of template.matchAll(/\{\{(\w+)\}\}/g)) variables[token[1]] = '{{unexpanded}} {"literal": true} ${notCode}';
	assert.throws(() => getPrompt(extension, marker), /Missing prompt variable/);
	assert.equal(getPrompt(extension, marker, variables), template.replace(/\{\{(\w+)\}\}/g, (_token, name) => variables[name]));
});
