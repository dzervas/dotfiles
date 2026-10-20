// The trusted Desktop main process must choose the host directory and own the
// sandbox lifetime; letting an agent backend do either would bypass isolation.
import { createHash } from "node:crypto";
import { realpath, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, parse } from "node:path";
import { dialog } from "electron";
import { Sandbox } from "./contract.js";
import { launchServer } from "./server.js";

const launcher = "@launcher@";

export default function setup(ctx) {
  const saved = ctx.stores.projects;
  const entries = new Map(saved.value.map((project) => [project.id, {
    ...project, state: "stopped", generation: 0, enabled: false,
  }]));
  let revision = 0;
  let closed = false;
  let provider;

  function push() {
    if (closed) return;
    revision++;
    provider?.changed();
  }

  function save() {
    saved.set([...entries.values()].map(({ id, directory, name }) => ({ id, directory, name })));
  }

  function entryFor(id) {
    const entry = entries.get(id);
    if (!entry) throw new Error("Unknown sandbox");
    if (entry.removing) throw new Error("Sandbox is being removed");
    return entry;
  }

  async function resolve(id, explicit = true) {
    if (closed) throw new Error("Sandbox manager is shutting down");
    const entry = entryFor(id);
    // Desktop opens event streams eagerly. Only a user action may re-enable a
    // deliberately stopped or restored server; automatic reconnect must not.
    if (!explicit && !entry.enabled) throw new Error("Sandbox is stopped; open it to restart");
    if (explicit) entry.enabled = true;
    if (entry.pending) return entry.pending;
    if (entry.state === "ready") return entry.http;

    const generation = ++entry.generation;
    entry.state = "starting";
    push();
    const pending = (async () => {
      try {
        // Refuse a saved path replaced by a symlink since the user selected it.
        if (await realpath(entry.directory) !== entry.directory ||
            !(await stat(entry.directory)).isDirectory()) throw new Error("Project directory changed or disappeared");
        if (closed || generation !== entry.generation || entries.get(id) !== entry) {
          throw new Error("Sandbox start was cancelled");
        }

        const handle = launchServer(launcher, {
          directory: entry.directory,
          onExit: () => {
            if (generation !== entry.generation || closed) return;
            entry.generation++;
            entry.state = "failed";
            entry.http = undefined;
            entry.handle = undefined;
            push();
          },
        });
        entry.handle = handle;
        const http = await handle.ready;
        if (closed || generation !== entry.generation || entries.get(id) !== entry) {
          throw new Error("Sandbox start was cancelled");
        }
        entry.state = "ready";
        entry.http = http;
        push();
        return http;
      } catch (error) {
        if (generation === entry.generation && !closed) {
          entry.state = "failed";
          entry.http = undefined;
          push();
        }
        throw error;
      } finally {
        if (entry.pending === pending) entry.pending = undefined;
      }
    })();
    entry.pending = pending;
    return pending;
  }

  async function stop(entry) {
    entry.enabled = false;
    entry.generation++;
    const handle = entry.handle;
    entry.handle = undefined;
    entry.http = undefined;
    entry.state = "stopped";
    push();
    await handle?.stop();
  }

  provider = ctx.provide(Sandbox, {
    state: () => ({
      revision,
      servers: [...entries.values()].map(({ id, directory, name, state, http }) => ({
        id, directory, name, state, ...(http ? { http } : {}),
      })),
    }),
    open: async (_input, caller) => {
      const window = ctx.windows.get(caller.window);
      if (!window || closed) return null;
      const result = await dialog.showOpenDialog(window, {
        title: "Open sandboxed project",
        properties: ["openDirectory"],
      });
      if (result.canceled || !result.filePaths[0] || caller.signal.aborted || closed) return null;
      const directory = await realpath(result.filePaths[0]);
      if (directory === homedir() || directory === parse(directory).root) {
        throw new Error("Select a project directory, not your home or filesystem root");
      }
      const id = createHash("sha256").update(directory).digest("hex");
      if (!entries.has(id)) {
        entries.set(id, { id, directory, name: basename(directory), state: "stopped", generation: 0, enabled: false });
        save();
        push();
      }
      await resolve(id);
      return { id, revision };
    },
    resolve: async ({ id }) => ({ ...(await resolve(id)), revision }),
    reconnect: ({ id }) => resolve(id, false),
    stop: ({ id }) => stop(entryFor(id)),
    forget: async ({ id }) => {
      const entry = entryFor(id);
      entry.removing = true;
      await stop(entry);
      entries.delete(id);
      save();
      push();
    },
  });

  // App shutdown/reload kills every backend; saved projects restart lazily.
  ctx.scope.addFinalizer(async () => {
    closed = true;
    await Promise.all([...entries.values()].map(stop));
  });
}
