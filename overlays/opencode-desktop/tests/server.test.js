// These tests exercise real stream/event ordering with a fake child: no test may
// launch a host backend while checking the sandbox's fail-closed lifecycle.
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";
import { launchServer } from "../extension/server.js";

const password = "a".repeat(43);
const endpoint = { url: "http://127.0.0.1:41321", password };

function fixture(options = {}) {
  const child = new EventEmitter();
  child.pid = 12345;
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  const killed = [];
  const calls = [];
  child.kill = (signal) => {
    killed.push(signal);
    if (!options.ignoreTerm || signal === "SIGKILL") {
      queueMicrotask(() => child.emit("exit", null, signal));
    }
    return true;
  };
  const handle = launchServer("/nix/store/test-sandbox", {
    directory: "/tmp/project with spaces",
    timeoutMs: 1_000,
    killTimeoutMs: 5,
    ...options,
    spawnProcess: (...args) => { calls.push(args); return child; },
  });
  return { child, handle, killed, calls };
}

test("starts exactly one wrapper with an argv-safe directory; waits for both credential and URL", async () => {
  const { child, handle, calls } = fixture();
  assert.deepEqual(calls, [[
    "/nix/store/test-sandbox", ["/tmp/project with spaces"], { stdio: ["ignore", "pipe", "pipe"] },
  ]]);
  child.stdout.write("migration complete\nserver list");
  child.stdout.write("ening on http://127.0.0.1:41321\n");
  let ready = false;
  void handle.ready.then(() => { ready = true; });
  await Promise.resolve();
  assert.equal(ready, false);
  child.stdout.write(`server password ${password.slice(0, 20)}`);
  child.stdout.write(`${password.slice(20)}\n`);
  assert.deepEqual(await handle.ready, endpoint);
  await handle.stop();
});

test("intentional stop is idempotent and does not report a crash", async () => {
  let exits = 0;
  const { child, handle, killed } = fixture({ onExit: () => exits++ });
  child.stdout.write(`server password ${password}\nserver listening on ${endpoint.url}\n`);
  await handle.ready;
  await Promise.all([handle.stop(), handle.stop()]);
  assert.deepEqual(killed, ["SIGTERM"]);
  assert.equal(exits, 0);
});

test("unexpected exit rejects startup without forwarding credential-bearing stderr", async () => {
  let exits = 0;
  const { child, handle, killed } = fixture({ onExit: () => exits++ });
  child.stderr.write(`sensitive provider output ${password}\n`);
  child.emit("exit", 1, null);
  child.emit("close", 1, null);
  await assert.rejects(handle.ready, (error) =>
    error.message.includes("exited before startup") && !error.message.includes(password));
  await handle.stop();
  assert.equal(exits, 1);
  assert.deepEqual(killed, []);
});

test("unexpected exit after readiness is reported once", async () => {
  let exits = 0;
  const { child, handle } = fixture({ onExit: () => exits++ });
  child.stdout.write(`server listening on ${endpoint.url}\nserver password ${password}\n`);
  await handle.ready;
  child.emit("exit", 1, null);
  child.emit("close", 1, null);
  assert.equal(exits, 1);
  await handle.stop();
});

for (const url of ["http://0.0.0.0:4096", "http://localhost:4096", "http://127.0.0.1:0", "https://127.0.0.1:4096"]) {
  test(`refuses unexpected endpoint ${url}`, async () => {
    const { child, handle, killed } = fixture();
    child.stdout.write(`server listening on ${url}\n`);
    await assert.rejects(handle.ready, /non-loopback endpoint/);
    await handle.stop();
    assert.deepEqual(killed, ["SIGTERM"]);
  });
}

test("times out and force-kills a stuck wrapper without another launch", async () => {
  const { handle, killed, calls } = fixture({ timeoutMs: 5, ignoreTerm: true });
  await assert.rejects(handle.ready, /timed out/);
  await handle.stop();
  assert.deepEqual(killed, ["SIGTERM", "SIGKILL"]);
  assert.equal(calls.length, 1);
});

test("bounds startup output", async () => {
  const { child, handle } = fixture();
  child.stdout.write("x".repeat(16_385));
  await assert.rejects(handle.ready, /Unexpected.*output/);
  await handle.stop();
});

test("stopping during startup rejects the waiter", async () => {
  const { handle } = fixture();
  const stopped = handle.stop();
  await assert.rejects(handle.ready, /stopped before startup/);
  await stopped;
});

test("spawn error without a pid settles teardown", async () => {
  const { child, handle } = fixture();
  child.pid = undefined;
  child.emit("error", new Error("ENOENT"));
  await assert.rejects(handle.ready, /Could not start sandbox server/);
  await handle.stop();
});
