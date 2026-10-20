// Use native commands, server rows and project navigation rather than replacing
// Desktop's UI or running its normal Open Project action on an unsandboxed server.
import { createComponent, createRoot, lazy, Suspense } from "solid-js";
import { showToast } from "@opencode/ui/toast";
import { Command, MenuItem, Server, createKeyed } from "../sdk";

export default function setup(ctx) {
  if (ctx.build.platform !== "desktop") return;
  const Row = lazy(() => import("./row.jsx"));
  const client = () => {
    const live = ctx.uses.sandbox();
    if (live.status !== "active") throw new Error("Sandbox manager is unavailable");
    return live.value;
  };
  const state = () => {
    const live = ctx.uses.sandbox();
    return live.status === "active" ? live.value.state() : undefined;
  };
  const request = (action) => {
    void Promise.resolve().then(action).catch((error) => {
      if (!ctx.signal.aborted) showToast({
        variant: "error",
        title: "Sandbox request failed",
        description: error instanceof Error ? error.message : String(error),
      });
    });
  };

  const waitFor = (condition) => new Promise((resolve) => {
    createRoot((dispose) => {
      const done = (ready) => {
        ctx.signal.removeEventListener("abort", abort);
        dispose();
        resolve(ready);
      };
      const abort = () => done(false);
      if (ctx.signal.aborted) return done(false);
      ctx.signal.addEventListener("abort", abort, { once: true });
      createKeyed(
        condition,
        () => done(true),
      );
    });
  });

  const open = () => request(async () => {
    const result = await client().open();
    if (!result || !await waitFor(() => (state()?.revision ?? -1) >= result.revision)) return;
    if (!state()?.servers.some((entry) => entry.id === result.id && entry.state === "ready")) return;
    // The upstream picker sees the project, private HOME and read-only runtime
    // mounts, not the rest of the user's host files.
    ctx.layout.project(`sandbox:${result.id}`, "Select the project inside its sandbox");
  });

  const connect = async (id) => {
    const result = await client().resolve({ id });
    if (!await waitFor(() => (state()?.revision ?? -1) >= result.revision)) return false;
    return state()?.servers.some((entry) => entry.id === id && entry.state === "ready") ?? false;
  };
  const openExisting = (id) => request(async () => {
    if (await connect(id)) ctx.layout.project(`sandbox:${id}`, "Select the project inside its sandbox");
  });

  ctx.add(Server, () => {
    const current = state();
    return {
      ready: current !== undefined,
      entries: (current?.servers ?? []).map((entry) => ({
        id: entry.id,
        name: entry.name,
        label: "Sandbox",
        state: entry.state,
        http: entry.http,
        connect: () => connect(entry.id),
        // The client captures this callback once, even while the server is
        // stopped. Main, not the callback's presence, gates automatic starts.
        reconnect: (signal) => client().reconnect({ id: entry.id }, { signal }),
        remove: () => client().forget({ id: entry.id }),
        row: (row) => createComponent(Suspense, {
          get children() {
            return createComponent(Row, {
              row,
              entry: () => state()?.servers.find((item) => item.id === entry.id),
              open: () => openExisting(entry.id),
            });
          },
        }),
      })),
    };
  });
  ctx.add(Command, {
    id: "open",
    title: "Open sandboxed project",
    group: "Server",
    run: open,
  });
  ctx.add(MenuItem, { menu: "server.add", id: "open", title: "Open sandboxed project", run: open });
  ctx.add(MenuItem, {
    menu: "server.row",
    id: "stop",
    title: "Stop sandbox",
    when: (key) => (state()?.servers ?? []).some((entry) =>
      key === `sandbox:${entry.id}` && entry.state !== "stopped"),
    run: (key) => request(() => client().stop({ id: key.slice("sandbox:".length) })),
  });
}
