// Keep process startup/teardown independent of Electron so failures, timeouts and
// partial stdout can be tested without ever launching an unsandboxed fallback.
import { spawn } from "node:child_process";

export function launchServer(command, {
  directory,
  onExit,
  spawnProcess = spawn,
  timeoutMs = 60_000,
  killTimeoutMs = 2_000,
}) {
  const child = spawnProcess(command, [directory], { stdio: ["ignore", "pipe", "pipe"] });
  let settled = false;
  let ended = false;
  let stopping = false;
  let stopPromise;
  let buffer = "";
  let url;
  let password;
  let resolveReady;
  let rejectReady;
  let resolveExit;
  const exited = new Promise((resolve) => { resolveExit = resolve; });
  const ready = new Promise((resolve, reject) => {
    resolveReady = resolve;
    rejectReady = reject;
  });
  // Teardown may happen before the caller gets to await startup.
  void ready.catch(() => { });

  const timeout = setTimeout(() => fail(new Error("Sandbox server startup timed out")), timeoutMs);

  function reject(error) {
    if (settled) return;
    settled = true;
    clearTimeout(timeout);
    rejectReady(error);
  }

  function fail(error) {
    reject(error);
    void stop();
  }

  function finish(code, signal) {
    if (ended) return;
    ended = true;
    clearTimeout(timeout);
    resolveExit();
    reject(new Error(`Sandbox server exited before startup (${signal ?? code ?? "unknown"})`));
    if (!stopping) onExit?.();
  }

  function stop() {
    if (stopPromise) return stopPromise;
    stopping = true;
    reject(new Error("Sandbox server stopped before startup"));
    stopPromise = (async () => {
      if (ended) return;
      // The launcher runs the shared sand function in a dedicated Fish process.
      // bwrap --die-with-parent tears down its namespace when that Fish exits.
      child.kill("SIGTERM");
      const force = setTimeout(() => child.kill("SIGKILL"), killTimeoutMs);
      try {
        await exited;
      } finally {
        clearTimeout(force);
      }
    })();
    return stopPromise;
  }

  child.once("error", (error) => {
    reject(new Error(`Could not start sandbox server: ${error.message}`));
    // A failed spawn has no process to kill and need not emit "exit".
    if (!child.pid) finish(null, null);
    else void stop();
  });
  child.once("exit", finish);
  child.once("close", finish);
  child.stderr.resume();
  child.stdout.setEncoding("utf8");
  child.stdout.on("data", (chunk) => {
    if (settled) return;
    buffer += chunk;
    if (buffer.length > 16_384) {
      fail(new Error("Unexpected sandbox server startup output"));
      return;
    }
    let newline;
    while ((newline = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, newline).trim();
      buffer = buffer.slice(newline + 1);
      if (line.startsWith("server listening on ")) {
        const value = line.slice("server listening on ".length);
        try {
          const endpoint = new URL(value);
          if (endpoint.protocol !== "http:" || endpoint.hostname !== "127.0.0.1" ||
            !endpoint.port || Number(endpoint.port) < 1 || Number(endpoint.port) > 65535 ||
            endpoint.username || endpoint.password || endpoint.pathname !== "/" ||
            endpoint.search || endpoint.hash) throw new Error();
          url = endpoint.origin;
        } catch {
          fail(new Error("Sandbox server reported a non-loopback endpoint"));
          return;
        }
      }
      if (line.startsWith("server password ")) {
        const value = line.slice("server password ".length);
        if (!/^[A-Za-z0-9_-]{43}$/.test(value)) {
          fail(new Error("Sandbox server did not generate an ephemeral password"));
          return;
        }
        password = value;
      }
      if (url && password) {
        settled = true;
        clearTimeout(timeout);
        // Never forward startup output: it includes the server's credential.
        buffer = "";
        resolveReady({ url, password });
        return;
      }
    }
  });

  return { ready, stop };
}
