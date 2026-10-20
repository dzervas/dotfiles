// Resolve only the public Pi project namespace before bubblewrap hides parent
// repositories and linked-worktree metadata. No Git metadata needs mounting.
import { execFile } from "node:child_process";
import { memoryNamespace, type Runner } from "../../../pi/extensions/memory/atuin.ts";

const runner: Runner = (_command, args) => new Promise((resolve) => {
  execFile(process.argv[3], args, { timeout: 5_000, maxBuffer: 64 * 1024 }, (error, stdout) => {
    resolve({ code: error ? 1 : 0, stdout });
  });
});
process.stdout.write(await memoryNamespace(runner, "project", process.argv[2]));
