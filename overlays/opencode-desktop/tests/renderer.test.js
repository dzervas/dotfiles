// Lock down the GUI contribution contract, especially reconnect callbacks
// captured while stopped and the custom row needed to display native actions.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { SourceTextModule, SyntheticModule } from "node:vm";
import test from "node:test";

const source = await readFile(new URL("../extension/renderer.js", import.meta.url), "utf8");

async function fixture(options = {}) {
  const abort = new AbortController();
  const contributions = new Map();
  const watchers = new Set();
  const routes = [];
  const errors = [];
  let state = { revision: 0, servers: [{ id: "saved", name: "Project", directory: "/project", state: "stopped" }] };
  let enabled = false;
  let starts = 0;
  let pickerCalls = 0;
  const publish = (value) => {
    state = value;
    for (const watcher of [...watchers]) {
      if (!watcher.condition()) continue;
      watchers.delete(watcher);
      watcher.run();
    }
  };
  const ready = () => publish({ revision: 1, servers: [{ ...state.servers[0], state: "ready" }] });
  const client = {
    state: () => state,
    resolve: async () => {
      enabled = true;
      starts++;
      if (options.autoPublish !== false) ready();
      return { url: "http://127.0.0.1:41321", password: "fixture", revision: 1 };
    },
    reconnect: async () => {
      if (!enabled) throw new Error("Sandbox is stopped");
      return { url: "http://127.0.0.1:41321", password: "fixture" };
    },
    open: async () => {
      pickerCalls++;
      await client.resolve();
      return { id: "saved", revision: 1 };
    },
    stop: async () => { enabled = false; publish({ revision: 2, servers: [{ ...state.servers[0], state: "stopped" }] }); },
    forget: async () => {},
  };
  const modules = {
    "solid-js": {
      createRoot: (fn) => fn(() => {}),
      createComponent: (fn, props) => fn(props),
      lazy: () => (props) => props,
      Suspense: (props) => props.children,
    },
    "@opencode/ui/toast": { showToast: (value) => errors.push(value) },
    "../sdk": {
      Command: "command", MenuItem: "menu", Server: "server",
      createKeyed: (condition, run) => {
        if (condition()) run();
        else watchers.add({ condition, run });
      },
    },
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
    build: { platform: "desktop" },
    signal: abort.signal,
    uses: { sandbox: () => ({ status: "active", value: client }) },
    layout: { project: (...args) => routes.push(args) },
    add: (kind, value) => contributions.set(kind, [...(contributions.get(kind) ?? []), value]),
  });
  return {
    abort, contributions, routes, errors, ready,
    servers: () => contributions.get("server")[0]().entries,
    starts: () => starts, pickerCalls: () => pickerCalls,
  };
}

const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };

test("restored entries always expose the captured reconnect callback without enabling a backend", async () => {
  const f = await fixture();
  const entry = f.servers()[0];
  assert.equal(typeof entry.reconnect, "function");
  await assert.rejects(entry.reconnect(new AbortController().signal), /stopped/);
  assert.equal(f.starts(), 0);
  await entry.connect();
  assert.equal((await entry.reconnect(new AbortController().signal)).url, "http://127.0.0.1:41321");
});

test("connect waits for the published revision before declaring the server ready", async () => {
  const f = await fixture({ autoPublish: false });
  let complete = false;
  const connected = f.servers()[0].connect().then((value) => { complete = true; return value; });
  await flush();
  assert.equal(complete, false);
  f.ready();
  assert.equal(await connected, true);
});

test("custom native row receives menu parts and reopens its existing sandbox without a host picker", async () => {
  const f = await fixture();
  const row = { Items() {}, Indicator() {}, health() {}, remove() {} };
  const view = f.servers()[0].row(row);
  assert.equal(view.row, row);
  view.open();
  await flush();
  assert.equal(f.pickerCalls(), 0);
  assert.equal(f.routes[0][0], "sandbox:saved");
  const jsx = await readFile(new URL("../extension/row.jsx", import.meta.url), "utf8");
  assert.match(jsx, /<props\.row\.Items\s*\/>/);
  assert.match(jsx, /onClick=\{props\.open\}/);
});

test("stop is a visible custom-row action and captured reconnect still cannot restart it", async () => {
  const f = await fixture();
  const entry = f.servers()[0];
  await entry.connect();
  const stop = f.contributions.get("menu").find((item) => item.id === "stop");
  assert.equal(stop.when("sandbox:saved"), true);
  stop.run("sandbox:saved");
  await flush();
  await assert.rejects(entry.reconnect(new AbortController().signal), /stopped/);
  assert.equal(f.starts(), 1);
  assert.equal(stop.when("sandbox:saved"), false);
});

test("new-project command targets the registered sandbox, not the host server", async () => {
  const f = await fixture();
  f.contributions.get("command")[0].run();
  await flush();
  assert.equal(f.pickerCalls(), 1);
  assert.equal(f.routes[0][0], "sandbox:saved");
  assert.deepEqual(f.errors, []);
});

test("extension shutdown cancels a pending target-server switch", async () => {
  const f = await fixture({ autoPublish: false });
  f.contributions.get("command")[0].run();
  await flush();
  f.abort.abort();
  await flush();
  assert.equal(f.routes.length, 0);
});
