/**
 * Prompt-prefix fingerprints for provider request payloads, and the first
 * place one request's prefix diverges from the previous one.
 *
 * Providers cache a request's prefix in order: tools, then the system prompt,
 * then messages. A new request reuses the cache only while it extends the
 * previous one, so anything that rewrites an earlier part re-bills everything
 * after it. Handles Anthropic Messages payloads (`system`, `tools[].name`) and
 * OpenAI Chat Completions payloads (leading `system`/`developer` message,
 * `tools[].function.name`).
 */

import { createHash } from "node:crypto";

export interface Fingerprint {
	toolNames: string[];
	toolHashes: string[];
	system: string;
	/** One hash per conversation message, after the leading system prompt. */
	messages: string[];
}

const hash = (value: string) => createHash("sha1").update(value).digest("base64").slice(0, 16);

/**
 * Drop what moves between requests without changing the cached content: pi
 * re-anchors `cache_control` on the newest message each request, and that
 * message's string content becomes a one-element text array to carry it.
 */
function normalize(value: unknown): unknown {
	if (Array.isArray(value)) return value.map(normalize);
	if (value === null || typeof value !== "object") return value;
	const out: Record<string, unknown> = {};
	for (const [key, inner] of Object.entries(value)) {
		if (key !== "cache_control") out[key] = normalize(inner);
	}
	const content = out.content;
	if (Array.isArray(content) && content.length === 1) {
		const [part] = content as Record<string, unknown>[];
		if (part?.type === "text" && Object.keys(part).length === 2 && typeof part.text === "string") out.content = part.text;
	}
	return out;
}

function text(content: unknown): string {
	if (typeof content === "string") return content;
	if (Array.isArray(content)) return content.map((part) => (part as { text?: unknown })?.text ?? "").join("\n");
	return "";
}

export function fingerprint(payload: unknown): Fingerprint | undefined {
	if (payload === null || typeof payload !== "object") return undefined;
	const { system, tools, messages } = payload as { system?: unknown; tools?: unknown; messages?: unknown };
	if (!Array.isArray(messages)) return undefined;

	let rest = messages as Record<string, unknown>[];
	let systemText = text(system);
	const first = rest[0];
	if (system === undefined && (first?.role === "system" || first?.role === "developer")) {
		systemText = text(first.content);
		rest = rest.slice(1);
	}

	const toolList = Array.isArray(tools) ? (tools as Record<string, unknown>[]) : [];
	return {
		toolNames: toolList.map((tool) => String((tool.function as { name?: unknown } | undefined)?.name ?? tool.name ?? "?")),
		toolHashes: toolList.map((tool) => hash(JSON.stringify(normalize(tool)))),
		system: systemText,
		messages: rest.map((message) => hash(JSON.stringify(normalize(message)))),
	};
}

/** The heading (`# Title`, `## Title`, or `<tag>`) at or above the first line that differs. */
function changedSection(before: string, after: string): string | undefined {
	const a = before.split("\n");
	const b = after.split("\n");
	let line = 0;
	while (line < a.length && line < b.length && a[line] === b[line]) line++;
	for (let i = Math.min(line, b.length - 1); i >= 0; i--) {
		const candidate = b[i]?.trim() ?? "";
		if (/^#{1,3} \S/.test(candidate) || /^<[A-Za-z_][\w-]*[ >]/.test(candidate)) return candidate.slice(0, 60);
	}
	return undefined;
}

/** Why `next` does not extend `prev`'s cached prefix, or undefined when it does. */
export function prefixChange(prev: Fingerprint, next: Fingerprint): string | undefined {
	const reasons: string[] = [];

	const before = new Set(prev.toolNames);
	const after = new Set(next.toolNames);
	const added = next.toolNames.filter((name) => !before.has(name));
	const removed = prev.toolNames.filter((name) => !after.has(name));
	if (added.length || removed.length) {
		reasons.push(`tools ${[...added.map((name) => `+${name}`), ...removed.map((name) => `-${name}`)].join(" ")}`);
	} else if (prev.toolNames.join("\n") !== next.toolNames.join("\n")) {
		reasons.push("tools reordered");
	} else {
		const changed = next.toolNames.filter((_, i) => prev.toolHashes[i] !== next.toolHashes[i]);
		if (changed.length) reasons.push(`tool definition changed: ${changed.join(", ")}`);
	}

	if (prev.system !== next.system) {
		const section = changedSection(prev.system, next.system);
		reasons.push(section ? `system prompt changed near "${section}"` : "system prompt changed");
	}

	let index = 0;
	while (index < prev.messages.length && index < next.messages.length && prev.messages[index] === next.messages[index]) index++;
	if (index < prev.messages.length) {
		reasons.push(
			index < next.messages.length
				? `message ${index + 1} of ${prev.messages.length} changed`
				: `conversation cut from ${prev.messages.length} to ${next.messages.length} messages`,
		);
	}

	return reasons.length ? reasons.join("; ") : undefined;
}
