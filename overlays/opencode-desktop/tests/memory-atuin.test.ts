// Exercise the real Atuin CLI on an offline, disposable profile. The transport
// mocks cover failures; this catches drift in actual KV arguments and encoding.
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const atuin = process.env.OPENCODE_TEST_ATUIN;

test("actual Atuin shares Pi's KV protocol without any logged-in account", {
  skip: atuin ? false : "requires Atuin executable; enabled by Nix",
  timeout: 30_000,
}, async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-atuin-protocol-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const config = join(root, "config"); const data = join(root, "data");
  await mkdir(config); await mkdir(data);
  await writeFile(join(config, "config.toml"), "auto_sync = false\n[sync]\nrecords = true\n");
  const backend = new URL("../memory/backend.ts", import.meta.url).href;
  const source = `
    import assert from "node:assert/strict";
    import { createAtuinBackend } from ${JSON.stringify(backend)};
    const backend = createAtuinBackend(${JSON.stringify(root)});
    const saved = await backend.mutate("global", "remember", "Synthetic compatibility fixture");
    assert.equal(saved.changed, true);
    assert.equal(saved.data.global.namespace, "pi/global");
    assert.equal(saved.data.global.notes[0].text, "Synthetic compatibility fixture");
    const changed = await backend.mutate("global", "replace", "Updated synthetic fixture", "Synthetic compatibility fixture");
    assert.equal(changed.data.global.notes.length, 1);
    assert.equal(changed.data.global.notes[0].text, "Updated synthetic fixture");
    await backend.mutate("global", "forget", "Updated synthetic fixture");
    assert.equal((await backend.read(["global"])).data.global.notes.length, 0);
    console.log("Fixture passed");
  `;
  const result = await promisify(execFile)(process.execPath, ["--experimental-transform-types", "--input-type=module", "-e", source], {
    env: { HOME: root, PATH: dirname(atuin!), ATUIN_CONFIG_DIR: config, ATUIN_DATA_DIR: data },
    timeout: 20_000,
  });
  assert.equal(result.stdout.trim(), "Fixture passed");
});
