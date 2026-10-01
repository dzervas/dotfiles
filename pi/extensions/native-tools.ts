import {
	createCodemodeExtension,
	createMcpExtension,
	createToolSearchExtension,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

// SDK subagents don't load CLI built-ins; use the upstream factories in both.
export default function nativeTools(pi: ExtensionAPI): void {
	createMcpExtension()(pi);
	createCodemodeExtension()(pi);
	createToolSearchExtension()(pi);
}
