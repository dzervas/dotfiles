// Build-time injection must stop on upstream drift, preserve existing built-ins,
// and work with read-only Nix-store inputs without enabling third-party code.
import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { runInNewContext } from "node:vm";
import test from "node:test";
import { inject, register, stageCli } from "../inject.js";

const main = 'import { Extension } from "./sdk/main"\nexport const builtins = Extension.compose(\n  existing,\n)\n';
const renderer = 'const eager = (setup) => setup\nexport const builtins = Extension.compose(\n  existing,\n)\n';

test("registers each entry without replacing existing built-ins", () => {
  assert.match(register(main, "main"), /main: \(\) => import\("\.\/sandbox\/main\.js"\)/);
  assert.match(register(renderer, "renderer"), /renderer: eager\(sandboxRenderer\)/);
  assert.ok(register(main, "main").endsWith("  existing,\n)\n"));
  assert.throws(() => register(register(main, "main"), "main"), /already registered/);
});

test("fails closed when upstream registration points or renderer helpers change", () => {
  assert.throws(() => register("different API", "main"), /exactly one/);
  assert.throws(() => register(main + main, "main"), /exactly one/);
  assert.throws(() => register(main, "renderer"), /helper changed/);
});

test("CLI staging is stable per build but changes for another same-version build", () => {
  const source = 'const stage = `${version}-${process.arch}`.replace(/[^a-zA-Z0-9._-]/g, "-")\nstage';
  const evaluate = (cli, arch = "x64") => runInNewContext(stageCli(source, cli), {
    version: "2.1.1", process: { arch },
  });
  assert.equal(evaluate("/nix/store/build-a-opencode"), evaluate("/nix/store/build-a-opencode"));
  assert.notEqual(evaluate("/nix/store/build-a-opencode"), evaluate("/nix/store/build-b-opencode"));
  assert.notEqual(evaluate("/nix/store/build-a-opencode"), evaluate("/nix/store/build-a-opencode", "arm64"));
  assert.throws(() => stageCli("changed upstream", "/nix/store/build-a"), /exactly one CLI staging key/);
  assert.throws(() => stageCli(source + source, "/nix/store/build-a"), /exactly one CLI staging key/);
});

test("copies the implementation, substitutes the store launcher and handles read-only input", async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-inject-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const source = join(root, "source");
  const target = join(source, "packages/gui-extensions/src");
  const extension = join(root, "extension");
  await mkdir(target, { recursive: true });
  await mkdir(extension);
  await writeFile(join(target, "main.ts"), main);
  await writeFile(join(target, "renderer.ts"), renderer);
  await writeFile(join(extension, "main.js"), 'const launcher = "@launcher@";\n');
  await chmod(join(extension, "main.js"), 0o444);
  const cliSource = join(source, "packages/desktop/src/main/service/desktop-cli.ts");
  const staging = 'const stage = `${version}-${process.arch}`.replace(/[^a-zA-Z0-9._-]/g, "-")\nstage\n';
  await mkdir(dirname(cliSource), { recursive: true });
  await writeFile(cliSource, staging);
  await inject(source, extension, "/nix/store/sandbox with spaces", "/nix/store/fixed-opencode");
  const context = { version: "2.1.1", process: { arch: "x64" } };
  assert.notEqual(runInNewContext(await readFile(cliSource, "utf8"), { ...context }),
    runInNewContext(staging, { ...context }), "A rebuilt CLI must not reuse the old same-version cache entry");
  assert.equal(await readFile(join(target, "sandbox/main.js"), "utf8"),
    'const launcher = "/nix/store/sandbox with spaces";\n');
  assert.match(await readFile(join(target, "renderer.ts"), "utf8"), /sandboxRenderer/);
});

test("checks both registries before modifying either", async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-drift-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const target = join(root, "packages/gui-extensions/src");
  await mkdir(target, { recursive: true });
  await writeFile(join(target, "main.ts"), main);
  await writeFile(join(target, "renderer.ts"), "changed upstream");
  await assert.rejects(inject(root, "/does-not-exist", "/unused"), /exactly one/);
  assert.equal(await readFile(join(target, "main.ts"), "utf8"), main);
});
