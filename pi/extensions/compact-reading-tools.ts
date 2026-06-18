import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createFindTool,
	createLsTool,
	type FindToolDetails,
	type LsToolDetails,
} from "@earendil-works/pi-coding-agent";
import { Container, Text } from "@earendil-works/pi-tui";

function hidden() {
	return new Container();
}

function textContent(result: { content: Array<{ type: string; text?: string }> }): string {
	return result.content.find((content) => content.type === "text")?.text ?? "";
}

function nonEmptyLineCount(value: string): number {
	return value.split("\n").filter((line) => line.trim().length > 0).length;
}

function short(value: unknown, fallback = "."): string {
	const text = typeof value === "string" && value.length > 0 ? value : fallback;
	if (text.length <= 80) return text;
	return `${text.slice(0, 37)}…${text.slice(-40)}`;
}

function status(theme: any, isPartial: boolean, isError: boolean): string {
	if (isPartial) return theme.fg("warning", "… ");
	if (isError) return theme.fg("error", "✗ ");
	return theme.fg("success", "✓ ");
}

export default function compactReadingTools(pi: ExtensionAPI) {
	const cwd = process.cwd();

	const find = createFindTool(cwd);
	pi.registerTool({
		name: "find",
		label: find.label,
		description: find.description,
		parameters: find.parameters,
		renderShell: "self",
		execute: (toolCallId, params, signal, onUpdate) =>
			find.execute(toolCallId, params, signal, onUpdate),
		renderCall(args, theme, context) {
			if (!context.isPartial) return hidden();
			const pattern = short(args?.pattern, "<pattern>");
			const where = short(args?.path, ".");
			let line = `${status(theme, true, false)} ${theme.fg("toolTitle", theme.bold("Find"))} ${theme.fg("accent", pattern)} ${theme.fg("dim", `in ${where}`)}`;
			if (args?.limit) line += theme.fg("dim", ` limit=${args.limit}`);
			return new Text(line, 0, 0);
		},
		renderResult(result, _options, theme, context) {
			const args = context.args;
			const pattern = short(args?.pattern, "<pattern>");
			const where = short(args?.path, ".");
			let line = `${status(theme, false, context.isError)} ${theme.fg("toolTitle", theme.bold("Find"))} ${theme.fg("accent", pattern)} ${theme.fg("dim", `in ${where}`)}`;
			if (args?.limit) line += theme.fg("dim", ` limit=${args.limit}`);
			const details = result.details as FindToolDetails | undefined;
			line += theme.fg("dim", ` ${nonEmptyLineCount(textContent(result))} files`);
			if (details?.resultLimitReached)
				line += theme.fg("warning", ` limit=${details.resultLimitReached}`);
			if (details?.truncation?.truncated) line += theme.fg("warning", " truncated");
			return new Text(line, 0, 0);
		},
	});

	const ls = createLsTool(cwd);
	pi.registerTool({
		name: "ls",
		label: ls.label,
		description: ls.description,
		parameters: ls.parameters,
		renderShell: "self",
		execute: (toolCallId, params, signal, onUpdate) =>
			ls.execute(toolCallId, params, signal, onUpdate),
		renderCall(args, theme, context) {
			if (!context.isPartial) return hidden();
			const path = short(args?.path, ".");
			let line = `${status(theme, true, false)} ${theme.fg("toolTitle", theme.bold("List"))} ${theme.fg("accent", path)}`;
			if (args?.limit) line += theme.fg("dim", ` limit=${args.limit}`);
			return new Text(line, 0, 0);
		},
		renderResult(result, _options, theme, context) {
			const args = context.args;
			const path = short(args?.path, ".");
			let line = `${status(theme, false, context.isError)} ${theme.fg("toolTitle", theme.bold("List"))} ${theme.fg("accent", path)}`;
			if (args?.limit) line += theme.fg("dim", ` limit=${args.limit}`);
			const details = result.details as LsToolDetails | undefined;
			line += theme.fg("dim", ` ${nonEmptyLineCount(textContent(result))} entries`);
			if (details?.entryLimitReached)
				line += theme.fg("warning", ` limit=${details.entryLimitReached}`);
			if (details?.truncation?.truncated) line += theme.fg("warning", " truncated");
			return new Text(line, 0, 0);
		},
	});
}
