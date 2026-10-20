// The Desktop adapter must call the installed Fish function, not embed a second
// sandbox implementation. All fixtures are private and contain no credentials.
import assert from "node:assert/strict";
import { constants, accessSync } from "node:fs";
import { access, chmod, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const source = await readFile(new URL("../sandbox.fish", import.meta.url), "utf8");

function binary(name) {
  for (const directory of process.env.PATH.split(":")) {
    const path = join(directory, name);
    try { accessSync(path, constants.X_OK); return path; } catch {}
  }
  throw new Error(`Missing test dependency ${name}`);
}

async function fixture(t, { exitCode = 0, namespaceExitCode = 0, installed = true } = {}) {
  const root = await mkdtemp(join(tmpdir(), "opencode-sand-adapter-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const home = join(root, "home");
  const project = join(home, "projects", "project with spaces");
  const config = join(root, "config");
  const prefix = join(root, "tools");
  const cache = join(root, "cache");
  const output = join(root, "invocation.json");
  await mkdir(project, { recursive: true });
  await mkdir(join(config, "fish/functions"), { recursive: true });
  await mkdir(join(config, "opencode"), { recursive: true });
  await mkdir(join(prefix, "bin"), { recursive: true });
  await symlink(binary("realpath"), join(prefix, "bin/realpath"));
  await symlink(process.env.FISH ?? binary("fish"), join(prefix, "bin/fish"));
  await writeFile(join(prefix, "bin/node"), `#!${process.execPath}\nconsole.log("pi/fixture/project");process.exit(${namespaceExitCode});\n`);
  await chmod(join(prefix, "bin/node"), 0o755);
  if (installed) {
    // Home Manager installs a function declaration, not an executable script.
    await writeFile(join(config, "fish/functions/sand.fish"), `function sand
      ${JSON.stringify(process.execPath)} -e 'require("node:fs").writeFileSync(${JSON.stringify(output)}, JSON.stringify({args:process.argv.slice(1), cwd:process.cwd(), config:process.env.OPENCODE_CONFIG, namespace:process.env.OPENCODE_MEMORY_PROJECT_NAMESPACE,path:process.env.PATH}));process.exit(${exitCode})' -- $argv
    end\n`);
  }
  const escaped = join(root, "unsandboxed");
  await writeFile(join(prefix, "bin/opencode"), `#!${process.execPath}\nrequire("node:fs").writeFileSync(${JSON.stringify(escaped)}, "unexpected host execution");\n`);
  await chmod(join(prefix, "bin/opencode"), 0o755);
  const script = join(root, "sandbox.fish");
  await writeFile(script, source.replace(/@(fish|coreutils|bubblewrap|opencode|atuin|git|node)@/g, prefix)
    .replaceAll("@namespace@", join(root, "namespace.ts"))
    .replaceAll("@sandboxConfig@", join(root, "sandbox.json")));
  const path = `${join(prefix, "bin")}:${process.env.PATH}`;
  const run = (directory = project) => spawnSync(process.env.FISH ?? binary("fish"), ["--no-config", script, directory], {
    env: { HOME: home, USER: "test-user", XDG_CONFIG_HOME: config, XDG_CACHE_HOME: cache, PATH: path }, encoding: "utf8",
  });
  return { home, project, config, cache, prefix, output, escaped, path, run };
}

test("calls installed sand with safe argv and project context, leaving mounts in sand", async (t) => {
  const f = await fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  const invocation = JSON.parse(await readFile(f.output, "utf8"));
  assert.equal(invocation.cwd, f.project);
  assert.equal(invocation.path, f.path, "The caller PATH must not be replaced or prefixed");
  assert.equal(invocation.namespace, "pi/fixture/project");
  assert.match(invocation.config, /\/sandbox\.json$/);
  assert.deepEqual(invocation.args, [
    "-c", 'export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"; exec "$@"', "--", "--",
    "opencode", "serve", "--hostname", "127.0.0.1", "--port", "0",
  ]);
  assert.ok(!source.includes("--unshare-all"), "Namespace policy belongs only in sand");
});

test("sand failure never launches a host fallback", async (t) => {
  const f = await fixture(t, { exitCode: 7 });
  assert.equal(f.run().status, 7);
  await assert.rejects(access(f.escaped));
});

test("missing installed sand fails closed", async (t) => {
  const f = await fixture(t, { installed: false });
  const result = f.run();
  assert.notEqual(result.status, 0);
  await assert.rejects(access(f.output));
  await assert.rejects(access(f.escaped));
});

test("namespace resolver failure cannot start an incorrectly scoped backend", async (t) => {
  const f = await fixture(t, { namespaceExitCode: 7 });
  assert.notEqual(f.run().status, 0);
  await assert.rejects(access(f.output));
  await assert.rejects(access(f.escaped));
});

test("refuses a whole home/root and missing project before invoking sand", async (t) => {
  const f = await fixture(t);
  for (const directory of [f.home, "/", join(f.home, "missing")]) assert.notEqual(f.run(directory).status, 0);
  await assert.rejects(access(f.output));
});
