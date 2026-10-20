// Exercise the main-process IPC contract without Electron, real credentials or
// host subprocesses. Run with node --experimental-vm-modules --test.
import assert from "node:assert/strict";
import * as crypto from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, symlink } from "node:fs/promises";
import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import { SourceTextModule, SyntheticModule } from "node:vm";
import test from "node:test";

const source = await readFile(new URL("../extension/main.js", import.meta.url), "utf8");
const http = { url: "http://127.0.0.1:41321", password: "a".repeat(43) };
const deferred = () => Promise.withResolvers();

async function fixture(t, options = {}) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "opencode-main-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const started = deferred();
  const handles = [];
  const saved = { value: options.saved ?? [], set(value) { this.value = value; } };
  const scope = new AbortController();
  const finalizers = [];
  let methods;
  let picks = 0;
  let changed = 0;
  const modules = {
    "node:crypto": crypto,
    "node:fs/promises": fs,
    "node:os": os,
    "node:path": path,
    "electron": { dialog: { showOpenDialog: async () => {
      picks++;
      return options.selection ?? { canceled: false, filePaths: [directory] };
    } } },
    "./contract.js": { Sandbox: {} },
    "./server.js": { launchServer: (command, input) => {
      const ready = deferred();
      // Mirrors the real launcher's rejection handler during early teardown.
      void ready.promise.catch(() => {});
      const handle = {
        command, input, ready: ready.promise,
        succeed: () => ready.resolve(http),
        stops: 0,
        stop: async () => {
          handle.stops++;
          ready.reject(new Error("stopped"));
          if (options.stopGate) await options.stopGate.promise;
        },
      };
      handles.push(handle);
      started.resolve(handle);
      if (options.autoReady !== false) handle.succeed();
      return handle;
    } },
  };
  const module = new SourceTextModule(source);
  await module.link((name) => {
    const values = modules[name];
    assert.ok(values, `Unexpected import ${name}`);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    });
  });
  await module.evaluate();
  module.namespace.default({
    stores: { projects: saved },
    windows: { get: (id) => id === 1 ? {} : undefined },
    provide: (_token, value) => { methods = value; return { changed: () => changed++ }; },
    scope: { signal: scope.signal, addFinalizer: (fn) => finalizers.push(fn) },
  });
  const close = async () => {
    scope.abort();
    await Promise.all(finalizers.map((fn) => fn()));
  };
  t.after(close);
  return {
    directory, methods, handles, saved, close, started: started.promise,
    picks: () => picks, changed: () => changed,
    caller: { window: 1, signal: scope.signal },
  };
}

test("trusted directory picker launches one server and persists no endpoint or credential", async (t) => {
  const f = await fixture(t);
  const opened = await f.methods.open(undefined, f.caller);
  assert.equal(f.picks(), 1);
  assert.equal(f.handles.length, 1);
  assert.equal(f.handles[0].input.directory, f.directory);
  assert.equal(opened.revision, f.methods.state().revision);
  assert.ok(f.changed() >= 3);
  assert.deepEqual(Object.keys(f.saved.value[0]).sort(), ["directory", "id", "name"]);
  assert.equal(JSON.stringify(f.saved.value).includes(http.password), false);
  assert.equal(f.methods.state().servers[0].state, "ready");
  assert.equal((await f.methods.resolve({ id: opened.id })).url, http.url);
  assert.equal(f.handles.length, 1);
});

test("cancelled native picker does not register or launch a backend", async (t) => {
  const f = await fixture(t, { selection: { canceled: true, filePaths: [] } });
  assert.equal(await f.methods.open(undefined, f.caller), null);
  assert.equal(f.handles.length, 0);
  assert.equal(f.saved.value.length, 0);
});

test("home/root selections are refused before launch", async (t) => {
  for (const directory of [os.homedir(), "/"]) {
    const f = await fixture(t, { selection: { canceled: false, filePaths: [directory] } });
    await assert.rejects(f.methods.open(undefined, f.caller), /Select a project directory/);
    assert.equal(f.handles.length, 0);
  }
});

test("concurrent connection requests share a single start", async (t) => {
  const f = await fixture(t, { autoReady: false });
  const open = f.methods.open(undefined, f.caller);
  const handle = await f.started;
  const id = f.methods.state().servers[0].id;
  const reconnect = f.methods.resolve({ id });
  assert.equal(f.handles.length, 1);
  handle.succeed();
  await Promise.all([open, reconnect]);
  assert.equal(f.methods.state().servers[0].state, "ready");
});

test("stop during startup cannot resurrect the backend", async (t) => {
  const f = await fixture(t, { autoReady: false });
  const open = f.methods.open(undefined, f.caller);
  const rejection = assert.rejects(open, /stopped|cancelled/);
  const handle = await f.started;
  const id = f.methods.state().servers[0].id;
  await f.methods.stop({ id });
  await rejection;
  handle.succeed();
  assert.equal(f.methods.state().servers[0].state, "stopped");
  assert.equal(handle.stops, 1);
});

test("app shutdown terminates backends and prevents another launch", async (t) => {
  const f = await fixture(t);
  const { id } = await f.methods.open(undefined, f.caller);
  await f.close();
  assert.equal(f.handles[0].stops, 1);
  await assert.rejects(f.methods.resolve({ id }), /shutting down/);
});

test("unexpected exit marks failed and reconnect starts a replacement", async (t) => {
  const f = await fixture(t);
  const { id } = await f.methods.open(undefined, f.caller);
  f.handles[0].input.onExit();
  assert.equal(f.methods.state().servers[0].state, "failed");
  assert.equal(f.methods.state().servers[0].http, undefined);
  await f.methods.reconnect({ id });
  assert.equal(f.handles.length, 2);
  assert.equal(f.methods.state().servers[0].state, "ready");
});

test("restored projects stay stopped until opened and reject replaced symlinks", async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), "opencode-restored-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const target = path.join(root, "target");
  const link = path.join(root, "project");
  await mkdir(target);
  await symlink(target, link);
  const f = await fixture(t, { saved: [{ id: "known", name: "Project", directory: link }] });
  assert.equal(f.handles.length, 0);
  assert.equal(f.methods.state().servers[0].state, "stopped");
  await assert.rejects(f.methods.reconnect({ id: "known" }), /stopped/);
  await assert.rejects(f.methods.resolve({ id: "known" }), /changed or disappeared/);
  assert.equal(f.handles.length, 0);
  await assert.rejects(f.methods.resolve({ id: "unknown" }), /Unknown sandbox/);
});

test("intentional stop rejects automatic reconnect until an explicit open", async (t) => {
  const f = await fixture(t);
  const { id } = await f.methods.open(undefined, f.caller);
  await f.methods.stop({ id });
  await assert.rejects(f.methods.reconnect({ id }), /stopped/);
  assert.equal(f.handles.length, 1);
  await f.methods.resolve({ id });
  assert.equal(f.handles.length, 2);
  assert.equal(f.methods.state().servers[0].state, "ready");
});

test("removal blocks reconnect and explicit connect before slow teardown completes", async (t) => {
  const stopGate = deferred();
  const f = await fixture(t, { stopGate });
  const { id } = await f.methods.open(undefined, f.caller);
  const forgotten = f.methods.forget({ id });
  await assert.rejects(f.methods.reconnect({ id }), /being removed/);
  await assert.rejects(f.methods.resolve({ id }), /being removed/);
  assert.equal(f.handles.length, 1);
  stopGate.resolve();
  await forgotten;
  assert.equal(f.methods.state().servers.length, 0);
  assert.equal(f.handles[0].stops, 1);
  await assert.rejects(f.methods.reconnect({ id }), /Unknown sandbox/);
});

test("removing a server stops it and forgets only its registration", async (t) => {
  const f = await fixture(t);
  const { id } = await f.methods.open(undefined, f.caller);
  await f.methods.forget({ id });
  assert.equal(f.handles[0].stops, 1);
  assert.equal(f.saved.value.length, 0);
  assert.equal(f.methods.state().servers.length, 0);
});
