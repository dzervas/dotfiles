// Read-only mode: restricts the active tool set and blocks anything that
// writes (or can't be proven not to). Orthogonal to the rule engine — it runs
// before it in the tool_call handler.

import type {
	ExtensionAPI,
	ExtensionContext,
	ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { askPermission } from "./ask";
import { askReasons, type PermissionSubject } from "./types";

const READ_MODE_TOOLS = ["read", "bash", "grep", "find", "ls", "questionnaire"];
const ALLOWED_CUSTOM_TOOLS = new Set(["questionnaire", "todo"]);

type ReadModeState = {
	enabled: boolean;
	previousTools?: string[];
};

export function createReadMode(pi: ExtensionAPI) {
	let enabled = false;
	let previousTools: string[] | undefined;

	function applyToolFilter() {
		pi.setActiveTools(
			READ_MODE_TOOLS.filter((name) => pi.getAllTools().some((tool) => tool.name === name)),
		);
	}

	function updateUi(ctx: ExtensionContext) {
		// TODO: This should be a setFooter
		ctx.ui.setStatus(
			"permissions-read-mode",
			enabled ? ctx.ui.theme.fg("dim", "󰏯 read") : ctx.ui.theme.fg("success", "󰏫 edit"),
		);
	}

	function persist() {
		pi.appendEntry<ReadModeState>("permissions-read-mode", {
			enabled,
			previousTools,
		});
	}

	function restore(ctx: ExtensionContext) {
		let restored: ReadModeState | undefined;

		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === "permissions-read-mode")
				restored = entry.data as ReadModeState | undefined;
		}

		enabled = restored?.enabled ?? false;
		previousTools = restored?.previousTools;

		if (enabled) applyToolFilter();
		updateUi(ctx);
	}

	function set(next: boolean, ctx: ExtensionContext) {
		if (next === enabled) {
			updateUi(ctx);
			ctx.ui.notify(`Read mode already ${next ? "enabled" : "disabled"}`, "info");
			return;
		}

		if (next) {
			previousTools = pi.getActiveTools();
			applyToolFilter();
			enabled = true;
			ctx.ui.notify("Read mode enabled. File mutations are blocked.", "info");
		} else {
			enabled = false;
			if (previousTools && previousTools.length > 0) {
				const available = new Set(pi.getAllTools().map((tool) => tool.name));
				pi.setActiveTools(previousTools.filter((tool) => available.has(tool)));
			}
			ctx.ui.notify("Read mode disabled.", "info");
		}

		updateUi(ctx);
		persist();
	}

	// Turn read mode off without restoring tools or notifying (sandbox override).
	function clear(ctx: ExtensionContext) {
		enabled = false;
		ctx.ui.setStatus("permissions-read-mode", undefined);
	}

	function decide(
		subject: PermissionSubject,
		ctx: ExtensionContext,
	): Promise<ToolCallEventResult | undefined> | undefined {
		if (subject.toolName === "edit" || subject.toolName === "write")
			return askPermission(pi, subject, "Read mode: file mutations are disabled", ctx);

		if (subject.paths.some((entry) => entry.access === "write"))
			return askPermission(pi, subject, "Read mode: write access is disabled", ctx);

		if (subject.findings.length > 0)
			return askPermission(
				pi,
				subject,
				`Read mode: blocked because the command is not safely classifiable (${askReasons(subject).join("; ")})`,
				ctx,
			);

		if (subject.toolKind === "custom" && !ALLOWED_CUSTOM_TOOLS.has(subject.toolName))
			return askPermission(
				pi,
				subject,
				`Read mode: custom tool '${subject.toolName}' is not allowed`,
				ctx,
			);

		if (subject.toolKind === "mcp")
			return askPermission(pi, subject, "Read mode: MCP tools are blocked by default", ctx);

		return undefined;
	}

	return {
		get enabled() {
			return enabled;
		},
		restore,
		set,
		clear,
		decide,
	};
}
