import { readFileSync } from "node:fs";

/** Marker-delimited Markdown; surrounding blank lines are not part of a prompt. */
export function parsePrompts(source: string): Map<string, string> {
	const text = source.replace(/\r\n/g, "\n");
	const markers = [...text.matchAll(/^=== ext:([\w.-]+) ([\w.-]+) ===$/gm)];
	const prompts = new Map<string, string>();
	for (const [index, marker] of markers.entries()) {
		const key = `ext:${marker[1]} ${marker[2]}`;
		if (prompts.has(key)) throw new Error(`Duplicate prompt marker: ${key}`);
		const body = text.slice(marker.index! + marker[0].length, markers[index + 1]?.index).trim();
		if (!body) throw new Error(`Empty prompt: ${key}`);
		prompts.set(key, body);
	}
	return prompts;
}

// Load once per module runtime, rather than rereading Markdown on every turn.
let catalogue: Map<string, string> | undefined;

/** Read a named prompt and substitute {{name}} tokens once, without evaluating text. */
export function getPrompt(extension: string, marker: string, variables: Record<string, string | number> = {}): string {
	catalogue ??= parsePrompts(readFileSync(new URL("../prompts.md", import.meta.url), "utf8"));
	const key = `ext:${extension} ${marker}`;
	const text = catalogue.get(key);
	if (text === undefined) throw new Error(`Missing prompt: ${key}`);
	return text.replace(/\{\{([\w]+)\}\}/g, (_token, name: string) => {
		if (!Object.hasOwn(variables, name)) throw new Error(`Missing prompt variable ${name}: ${key}`);
		return String(variables[name]);
	});
}
