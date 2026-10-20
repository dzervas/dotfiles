// Resolve namespaces with real, disposable Git repositories before isolation.
// Subdirectories and linked worktrees must retain exactly Pi's repository scope.
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const git = process.env.OPENCODE_TEST_GIT;

test("trusted namespace discovery handles repository subdirectories and external worktree metadata", {
  skip: git ? false : "requires Git executable; enabled by Nix",
  timeout: 20_000,
}, async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-project-namespace-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const env = { HOME: root, PATH: process.env.PATH, GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: "/dev/null" };
  const run = (...args: string[]) => promisify(execFile)(git!, args, { env });
  const repository = join(root, "repository");
  const subdirectory = join(repository, "src");
  const worktree = join(root, "worktree");
  await mkdir(subdirectory, { recursive: true });
  await run("init", "-q", repository);
  await run("-C", repository, "remote", "add", "origin", "https://example.invalid/team/repository.git");
  await run("-C", repository, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "-qm", "Fixture");
  await run("-C", repository, "worktree", "add", "-qb", "fixture-worktree", worktree);
  for (const directory of [repository, subdirectory, worktree]) {
    const result = await promisify(execFile)(process.execPath, [
      "--no-warnings", "--experimental-transform-types",
      fileURLToPath(new URL("../memory/namespace.ts", import.meta.url)), directory, git!,
    ], { env });
    assert.equal(result.stdout, "pi/team/repository");
  }
});
