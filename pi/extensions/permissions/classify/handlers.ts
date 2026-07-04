// Per-command handlers for the static bash classifier. Each handler receives
// the command's resolved arguments (undefined = statically unresolvable) and
// either records the paths the command touches or asks for confirmation.
//
// This table is where most future growth happens: to support a new command,
// add a handler (or add it to SIMPLE/READ/WRITE below).

import { pushPath } from "../paths";
import type { PathRef, Verdict } from "../types";

// Simple commands don't affect the filesystem via their args.
export const SIMPLE = new Set(["pwd", "echo", "printf", "true", "false", "which", "date"]);
export const READ = new Set([
	"cat",
	"head",
	"tail",
	"less",
	"file",
	// NOTE: sed and sort are NOT in READ/WRITE — they have embedded sub-languages
	// (sed scripts; sort -o output) handled by dedicated handlers below.
	"jq",
	"xxd",
	"nl",
	"nm",
	"readelf",
	"strings",
	"sha256sum",
	"objdump",
	"test",
	"wc",
	"tr",
	"uniq",
]);
export const WRITE = new Set(["touch", "mkdir", "rm"]);

// Handlers that inspect dynamic (statically unresolvable) args per-position,
// so the blanket dynamic-argument check in bash.ts skips them (a dynamic
// search pattern is harmless).
export const HANDLES_DYNAMIC_ARGS = new Set(["find", "rg", "grep"]);

export type HandlerContext = {
	name: string;
	// argText output per argument; undefined = dynamic (substitution/expansion/variable).
	args: (string | undefined)[];
	paths: PathRef[];
	// Record a command-scoped finding (default verdict: "unknown").
	ask: (reason: string, verdict?: Verdict) => void;
};
export type CommandHandler = (ctx: HandlerContext) => void;

function positionals(args: (string | undefined)[]) {
	return args.filter(Boolean).filter((arg) => !arg!.startsWith("-")) as string[];
}

// cd is read-only navigation: it must abide by path permissions, but
// `cd -` (return to previous directory) is dynamic and always confirmed.
const cd: CommandHandler = ({ args, paths, ask }) => {
	const targets = positionals(args);

	if (args.includes("-")) return ask("cd - requires confirmation");

	(targets.length > 0 ? targets : ["~"]).forEach((arg) => pushPath(paths, arg, "read"));
};

// ls without positionals still affects the current directory as a list op.
const ls: CommandHandler = ({ args, paths }) => {
	const targets = positionals(args);
	(targets.length > 0 ? targets : ["."]).forEach((arg) => pushPath(paths, arg, "list"));
};

// sed has an embedded scripting language with execute (e), file read (r/R),
// and file write (w/W) commands. Rather than denylist dangerous constructs
// (fragile against addresses, -e, flag combos), we ALLOWLIST provably-safe
// scripts: only substitution (s///), print (p), delete (d), and quit (q),
// optionally with numeric/$/regex addresses and global/print/ignorecase
// flags. Anything else — including -e/-f indirection — is confirmed.
const sed: CommandHandler = ({ args, paths, ask }) => {
	const flagArgs = args.filter((arg): arg is string => !!arg && arg.startsWith("-"));
	const inPlace = flagArgs.some(
		(arg) => arg === "-i" || arg.startsWith("-i") || arg.startsWith("--in-place"),
	);
	// Any script-bearing flag (-e/--expression/-f/--file) means the script isn't
	// the lone positional; we can't cheaply prove it safe, so confirm.
	if (
		flagArgs.some(
			(arg) =>
				arg === "-e" ||
				arg === "-f" ||
				arg.startsWith("--expression") ||
				arg.startsWith("--file"),
		)
	)
		return ask("sed script via -e/-f requires confirmation");

	const scriptAndFiles = args.filter((arg): arg is string => !!arg && !arg.startsWith("-"));
	const script = scriptAndFiles[0];
	if (!script) return ask("sed needs a script");

	// Allowlist: semicolon/newline-separated simple commands, each optionally
	// address-prefixed. s///[flags], and bare p/d/q (with optional flags).
	const addr = "(?:[0-9]+|\\$|/(?:\\\\.|[^/])*/)?(?:,(?:[0-9]+|\\$|/(?:\\\\.|[^/])*/))?";
	const sub = `s([^\\s\\w])(?:\\\\.|(?!\\1).)*\\1(?:\\\\.|(?!\\1).)*\\1[gpiIme0-9]*`;
	const simple = `${addr}\\s*(?:${sub}|[pdq])`;
	const safeScript = new RegExp(`^\\s*(?:${simple})(?:\\s*;\\s*(?:${simple}))*\\s*;?\\s*$`, "u");
	// Reject the execute flag on s/// explicitly (the allowlist's [...e...] would
	// otherwise let `s/a/b/e` through).
	if (!safeScript.test(script) || /s([^\s\w])(?:\\.|(?!\1).)*\1(?:\\.|(?!\1).)*\1[a-z]*e/u.test(script))
		return ask("sed script is not a simple substitution/print");

	const files = scriptAndFiles.slice(1);
	files.forEach((arg) => pushPath(paths, arg, "read"));
	if (inPlace) files.forEach((arg) => pushPath(paths, arg, "write"));
};

// sort reads its inputs, but -o/--output writes a file (attached or spaced),
// and --files0-from reads a list file.
const sort: CommandHandler = ({ args, paths, ask }) => {
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (!arg) continue;
		if (arg === "-o" || arg === "--output") {
			const target = args[index + 1];
			if (!target) return void ask("sort -o needs a target");
			pushPath(paths, target, "write");
			index += 1;
			continue;
		}
		if (arg.startsWith("-o")) {
			pushPath(paths, arg.slice(2), "write");
			continue;
		}
		if (arg.startsWith("--output=")) {
			pushPath(paths, arg.slice("--output=".length), "write");
			continue;
		}
		if (arg.startsWith("--files0-from=")) {
			pushPath(paths, arg.slice("--files0-from=".length), "read");
			continue;
		}
		if (!arg.startsWith("-")) pushPath(paths, arg, "read");
	}
};

const copyMove: CommandHandler = ({ name, args, paths, ask }) => {
	const targets = positionals(args);

	if (targets.length < 2) return ask(`${name} needs source and destination`);

	targets.slice(0, -1).forEach((arg) => pushPath(paths, arg, "read"));
	pushPath(paths, targets.at(-1)!, "write");
};

const find: CommandHandler = ({ args, paths, ask }) => {
	const tokens = args.filter(Boolean) as string[];
	const roots: string[] = [];
	let parsingRoots = true;

	for (let index = 0; index < tokens.length; index += 1) {
		const arg = tokens[index]!;

		// Actions that run a command (-ok/-okdir prompt interactively but still execute).
		if (
			(arg === "-exec" || arg === "-execdir" || arg === "-ok" || arg === "-okdir") &&
			index + 1 < tokens.length
		) {
			const terminatorIndex = tokens.findIndex(
				(token, tokenIndex) =>
					tokenIndex > index && (token === ";" || token === "\\;" || token === "+"),
			);
			const execArgs = tokens.slice(
				index + 1,
				terminatorIndex === -1 ? tokens.length : terminatorIndex,
			);
			const execName = execArgs[0];
			if (!execName) return void ask(`Incomplete ${arg} in find`);
			if (WRITE.has(execName) || execName === "cp" || execName === "mv")
				return void ask(`find ${arg} runs ${execName}`, "unsafe");
			ask(`find ${arg} requires confirmation`);
			return;
		}

		// Actions that write/delete files directly (no external command).
		if (
			arg === "-delete" ||
			arg === "-fls" ||
			arg === "-fprint" ||
			arg === "-fprint0" ||
			arg === "-fprintf"
		)
			return void ask(`find ${arg} mutates the filesystem`, "unsafe");

		if (parsingRoots) {
			if (arg.startsWith("-") || ["!", "(", ")"].includes(arg)) parsingRoots = false;
			else roots.push(arg);
		}
	}

	(roots.length > 0 ? roots : ["."]).forEach((arg) => pushPath(paths, arg, "search"));
};

const search: CommandHandler = ({ name, args, paths, ask }) => {
	let positional = 0;
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (!arg) return void ask(`Dynamic ${name} argument`);
		if (arg === "-f" || arg === "--file") {
			if (!args[index + 1]) return void ask(`Dynamic ${name} pattern file`);
			pushPath(paths, args[index + 1]!, "read");
			index += 1;
			continue;
		}
		if (["-e", "--regexp", "-g", "--glob"].includes(arg)) {
			index += 1;
			continue;
		}
		if (arg.startsWith("--pre")) return void ask(`${name} --pre requires confirmation`, "unsafe");
		if (arg.startsWith("-")) continue;
		if (positional > 0) pushPath(paths, arg, "search");
		positional += 1;
	}
};

export const HANDLERS: Record<string, CommandHandler> = {
	cd,
	ls,
	sed,
	sort,
	cp: copyMove,
	mv: copyMove,
	find,
	rg: search,
	grep: search,
};
