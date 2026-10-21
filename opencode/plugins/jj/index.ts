// VCS provider for colocated jj repos. Git's HEAD stays detached under jj, so the
// built-in git provider reports no current branch and no review base; this one
// reads bookmarks and diffs revisions with jj instead. Discovery and HEAD-change
// refreshes still come from git.
import { execFile } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { Plugin } from "@opencode/plugin";

type Status = "added" | "deleted" | "modified";
interface FileDiff { file: string; patch: string; additions: number; deletions: number; status: Status }

const TRUNK = "coalesce(trunk() ~ root(), present(main), present(master))";

function jj(cwd: string, args: string[], signal: AbortSignal): Promise<string> {
	return new Promise((resolve, reject) => {
		execFile("jj", ["--no-pager", "--color=never", ...args], { cwd, signal, maxBuffer: 64 << 20 }, (error, stdout, stderr) => {
			if (error) reject(new Error(stderr.trim() || error.message));
			else resolve(stdout);
		});
	});
}

function parseDiff(text: string): FileDiff[] {
	return text.split(/^(?=diff --git )/m).filter((chunk) => chunk.startsWith("diff --git ")).map((patch) => {
		const lines = patch.split("\n");
		const target = lines.find((line) => line.startsWith("+++ b/"))?.slice(6) ??
			lines.find((line) => line.startsWith("--- a/"))?.slice(6) ??
			/^diff --git a\/.* b\/(.*)$/.exec(lines[0])![1];
		let additions = 0;
		let deletions = 0;
		for (const line of lines) {
			if (line.startsWith("+") && !line.startsWith("+++")) additions++;
			else if (line.startsWith("-") && !line.startsWith("---")) deletions++;
		}
		const status: Status = lines.some((line) => line.startsWith("new file mode")) ? "added"
			: lines.some((line) => line.startsWith("deleted file mode")) ? "deleted" : "modified";
		return { file: target, patch, additions, deletions, status };
	});
}

export default Plugin.define({
	id: "dotfiles.jj",
	async setup(ctx) {
		const root = ctx.location.project.directory;
		if (!fs.existsSync(path.join(root, ".jj"))) return;

		const trunk = async (signal: AbortSignal) => {
			const names = await jj(root, ["log", "--no-graph", "-r", TRUNK, "-T",
				'local_bookmarks.map(|b| b.name()).join("\\n") ++ "\\n" ++ remote_bookmarks.filter(|b| b.remote() != "git").map(|b| b.name() ++ "@" ++ b.remote()).join("\\n")'], signal);
			return names.split("\n").find(Boolean);
		};

		const diff = async (scope: { directory: string }, range: string[], context: number, signal: AbortSignal) => {
			const relative = path.relative(root, scope.directory);
			const fileset = relative ? [`root:${JSON.stringify(relative)}`] : [];
			return parseDiff(await jj(root, ["diff", "--git", "--context", String(context), ...range, ...fileset], signal));
		};

		await ctx.vcs.transform((editor) => {
			editor.add({
				id: "jj",
				name: "Jujutsu",
				// The nearest bookmark on @ or its parent, else @'s change ID.
				info: async (_scope, { signal }) => {
					const rows = (await jj(root, ["log", "--no-graph", "-r", "@ | @-", "-T",
						'local_bookmarks.map(|b| b.name()).join(",") ++ "\\t" ++ change_id.shortest(8) ++ "\\n"'], signal))
						.split("\n").filter(Boolean).map((row) => row.split("\t"));
					const current = rows.find(([bookmarks]) => bookmarks)?.[0] ?? rows[0]?.[1];
					return { branch: { current, default: await trunk(signal) } };
				},
				base: async (_scope, { signal }) => {
					const name = await trunk(signal);
					return name ? { name, ref: name, source: "default" } : null;
				},
				branches: async (input, { signal }) => {
					const names = (await jj(root, ["bookmark", "list", "--all-remotes", "-T", 'name ++ if(remote, "@" ++ remote) ++ "\\n"'], signal))
						.split("\n").filter((name) => name && !name.endsWith("@git") && (!input.search || name.includes(input.search)));
					return input.limit ? names.slice(0, input.limit) : names;
				},
				status: async (scope, { signal }) =>
					(await diff(scope, ["-r", "@"], 0, signal)).map(({ patch: _, ...status }) => status),
				diff: async (input, { signal }) => {
					if (input.mode === "working") return diff(input, ["-r", "@"], input.context, signal);
					const base = input.base ?? await trunk(signal);
					if (!base) throw new Error("No review base available");
					const to = input.mode === "committed" ? "@-" : "@";
					return diff(input, ["--from", `fork_point((${base}) | ${to})`, "--to", to], input.context, signal);
				},
			});
			editor.default.set("jj");
		});

		// Bookmark moves leave git's HEAD alone, so refresh after agent jj commands.
		await ctx.tool.hook("execute.after", async (event) => {
			const command = (event.input as { command?: unknown } | undefined)?.command;
			if (event.tool === "shell" && typeof command === "string" && /\bjj\b/.test(command)) await ctx.vcs.reload();
		});
	},
});
