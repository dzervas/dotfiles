import { realpath } from "node:fs/promises";
import { basename, dirname } from "node:path";

export interface ProjectIdentity {
	name: string;
	path: string;
}

/** Use the shared repository root so linked worktrees belong to the same project. */
export async function projectIdentity(cwd: string, git: (args: string[]) => Promise<{ code: number; stdout: string }>): Promise<ProjectIdentity> {
	const result = await git(["rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"]);
	let path = cwd;
	if (result.code === 0) {
		const [root, common] = result.stdout.trimEnd().split("\n");
		path = basename(common) === ".git" ? dirname(common) : root;
	}
	path = await realpath(path);
	return { name: basename(path), path };
}
