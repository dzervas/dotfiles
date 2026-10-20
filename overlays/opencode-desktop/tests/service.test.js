// Desktop's shared-service discovery must be tested against the actual built
// CLI: extension-only tests missed the prod/latest registration-file mismatch.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const binary = process.env.OPENCODE_TEST_CLI;

test("packaged CLI registers where Desktop's default discovery looks", {
  skip: binary ? false : "requires OPENCODE_TEST_CLI; enabled in the Nix check phase",
  timeout: 30_000,
}, async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-service-"));
  const state = join(root, "state");
  const child = spawn(binary, ["serve", "--service", "--hostname", "127.0.0.1", "--port", "0"], {
    cwd: root,
    env: {
      HOME: root,
      XDG_CONFIG_HOME: join(root, "config"),
      XDG_DATA_HOME: join(root, "data"),
      XDG_STATE_HOME: state,
      XDG_CACHE_HOME: join(root, "cache"),
      // Keep this regression independent of external model-catalog networking.
      OPENCODE_DISABLE_MODELS_FETCH: "1",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const exited = new Promise((resolve) => child.once("exit", resolve));
  t.after(async () => {
    if (child.pid && child.exitCode === null && child.signalCode === null) {
      child.kill("SIGTERM");
      const force = setTimeout(() => child.kill("SIGKILL"), 2_000);
      try { await exited; } finally { clearTimeout(force); }
    }
    await rm(root, { recursive: true, force: true });
  });
  child.stderr.resume();
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Background service never reached readiness")), 20_000);
    let output = "";
    const finish = (error) => {
      clearTimeout(timeout);
      if (error) reject(error);
      else resolve();
    };
    child.once("error", finish);
    child.once("exit", (code) => finish(new Error(`Background service exited before readiness (${code})`)));
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      output = (output + chunk).slice(-4_096);
      if (output.includes("server listening on http://127.0.0.1:")) finish();
    });
  });
  // Inspect filenames only: registration contents contain an ephemeral password.
  const registrations = (await readdir(join(state, "opencode"))).filter((name) => /^service.*\.json$/.test(name));
  assert.ok(registrations.includes("service.json"),
    `Desktop expects service.json; CLI registered ${registrations.join(", ")}`);
});
