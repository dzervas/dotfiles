// A real v2 CLI plus a local fake model verifies native plugin loading, model
// context, persistence and instruction discovery without user accounts or APIs.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, writeFile, chmod, rm } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { launchServer } from "../extension/server.js";

const binary = process.env.OPENCODE_TEST_CLI;
const memory = process.env.OPENCODE_TEST_MEMORY;

test("released CLI loads sandbox memory, native local instructions, and frozen snapshots after restart", {
  skip: binary && memory ? false : "requires built CLI and memory package; enabled by Nix",
  timeout: 60_000,
}, async (t) => {
  const root = await mkdtemp(join(tmpdir(), "opencode-memory-integration-"));
  const project = join(root, "project");
  const bin = join(root, "bin");
  const profile = join(root, "atuin-profile");
  await mkdir(join(project, ".pi"), { recursive: true });
  await mkdir(bin); await mkdir(profile);
  await writeFile(join(profile, "config.toml"), "auto_sync = false\n");
  await writeFile(join(project, "AGENTS.md"), "NATIVE_AGENTS_FIXTURE\n");
  await writeFile(join(project, "AGENTS.local.md"), "NATIVE_LOCAL_FIXTURE\n");
  await writeFile(join(project, ".pi/AGENTS.md"), "NATIVE_PI_FIXTURE\n");
  const noteFile = join(root, "notes.json");
  const saveNote = (text: string) => writeFile(noteFile, JSON.stringify({
    [createHash("sha256").update(text).digest("hex").slice(0, 12)]: `2026-01-01\t${text}`,
  }));
  await saveNote("LEARNED_MEMORY_ORIGINAL_FIXTURE");
  // The Atuin protocol fixture keeps this end-to-end test local and account-free.
  // Shared-backend unit tests cover real argument/encoding semantics separately.
  const atuin = join(bin, "atuin");
  await writeFile(atuin, `#!${process.execPath}\nconst fs=require("node:fs"),a=process.argv.slice(2);const v=JSON.parse(fs.readFileSync(${JSON.stringify(noteFile)},"utf8"));const ns=a[a.indexOf("-n")+1];if(ns!=="pi/global")process.exit(0);if(a[1]==="list")console.log(Object.keys(v).join("\\n"));else if(a[1]==="get")console.log(v[a.at(-1)]??"");else process.exit(1);\n`);
  await chmod(atuin, 0o755);
  const requests: string[] = [];
  const model = createServer(async (request, response) => {
    let text = "";
    for await (const chunk of request) text += chunk;
    const body = JSON.parse(text);
    requests.push(JSON.stringify(body.messages));
    const base = { id: "fixture", created: 0, model: "memory-model" };
    if (body.stream) {
      response.writeHead(200, { "Content-Type": "text/event-stream" });
      response.write(`data: ${JSON.stringify({ ...base, object: "chat.completion.chunk", choices: [{ index: 0, delta: { role: "assistant", content: "Fixture completed." }, finish_reason: null }] })}\n\n`);
      response.write(`data: ${JSON.stringify({ ...base, object: "chat.completion.chunk", choices: [{ index: 0, delta: {}, finish_reason: "stop" }], usage: { prompt_tokens: 100, completion_tokens: 5, total_tokens: 105 } })}\n\n`);
      response.end("data: [DONE]\n\n");
    } else {
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ ...base, object: "chat.completion", choices: [{ index: 0, message: { role: "assistant", content: "Fixture completed." }, finish_reason: "stop" }], usage: { prompt_tokens: 100, completion_tokens: 5, total_tokens: 105 } }));
    }
  });
  await new Promise<void>((resolve) => model.listen(0, "127.0.0.1", resolve));
  const modelAddress = model.address() as { port: number };
  const config = {
    plugins: [memory], instructions: ["AGENTS.local.md", ".pi/AGENTS.md"],
    providers: { fixture: { env: ["MEMORY_FIXTURE_API_KEY"], package: "@opencode/ai/providers/openai-compatible", settings: { baseURL: `http://127.0.0.1:${modelAddress.port}/v1` }, models: { "memory-model": { name: "Fixture" } } } },
  };
  const configFile = join(root, "sandbox.json");
  await writeFile(configFile, JSON.stringify(config));
  let handle: ReturnType<typeof launchServer> | undefined;
  let endpoint: { url: string; password: string };
  const start = async () => {
    handle = launchServer("fixture-launcher", {
      directory: project, timeoutMs: 20_000,
      spawnProcess: (_command, _args, options) => spawn(binary!, ["serve", "--hostname", "127.0.0.1", "--port", "0"], {
        ...options, cwd: project,
        env: {
          HOME: root, PATH: `${bin}:${process.env.PATH ?? ""}`,
          XDG_CONFIG_HOME: join(root, "config"), XDG_DATA_HOME: join(root, "data"),
          XDG_STATE_HOME: join(root, "state"), XDG_CACHE_HOME: join(root, "cache"),
          ATUIN_CONFIG_DIR: profile, ATUIN_DATA_DIR: profile,
          OPENCODE_DISABLE_MODELS_FETCH: "1", OPENCODE_CONFIG: configFile,
          MEMORY_FIXTURE_API_KEY: "fixture-not-a-real-key",
        },
      }),
    });
    endpoint = await handle.ready;
  };
  t.after(async () => {
    await handle?.stop();
    await new Promise<void>((resolve) => model.close(() => resolve()));
    await rm(root, { recursive: true, force: true });
  });
  const api = async (path: string, body?: unknown) => {
    const result = await fetch(endpoint.url + path, {
      method: body === undefined ? "GET" : "POST",
      headers: { authorization: `Basic ${Buffer.from(`opencode:${endpoint.password}`).toString("base64")}`, "content-type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(20_000),
    });
    assert.equal(result.ok, true, `${path}: ${result.status} ${result.ok ? "" : await result.text()}`);
    return result.status === 204 ? undefined : result.json();
  };
  const create = async () => (await api("/api/session", {
    location: { directory: project }, model: { providerID: "fixture", id: "memory-model" },
  })).data.id;
  const prompt = async (id: string) => {
    const before = requests.length;
    await api(`/api/session/${id}/prompt`, { text: "Respond with a short acknowledgement. Do not call tools." });
    await api(`/api/experimental/session/${id}/wait`, {});
    const info = (await api(`/api/session/${id}`)).data;
    assert.equal(info.outcome, "succeeded", "Fixture model request must complete successfully");
    return requests.slice(before).find((request) => request.includes("# Learned memory")) ?? "";
  };

  await start();
  // Inventory endpoints do not wait for a cold location to activate plugins.
  // A real prompt does: exercise that native barrier, not an arbitrary sleep.
  const id = await create();
  const first = await prompt(id);
  const inventory = await api("/api/plugin");
  assert.equal(inventory.location.directory, project, "Plugin inventory must use the fixture location");
  const plugins = inventory.data;
  const providerInventory = await api("/api/provider");
  assert.ok(providerInventory.data.some((provider: any) => provider.id === "fixture"), "Fixture config must be loaded");
  const loaded = plugins.find((plugin: any) => plugin.id === "dotfiles.memory");
  assert.equal(loaded?.state.status, "active", JSON.stringify(loaded?.state ?? plugins));
  for (const marker of ["LEARNED_MEMORY_ORIGINAL_FIXTURE", "NATIVE_AGENTS_FIXTURE", "NATIVE_LOCAL_FIXTURE", "NATIVE_PI_FIXTURE", "memory_search"]) {
    assert.ok(first.includes(marker), `Model context is missing ${marker}`);
  }
  await saveNote("LEARNED_MEMORY_UPDATED_FIXTURE");
  await handle!.stop();
  await start();
  const resumed = await prompt(id);
  assert.ok(resumed.includes("LEARNED_MEMORY_ORIGINAL_FIXTURE"));
  assert.ok(!resumed.includes("LEARNED_MEMORY_UPDATED_FIXTURE"));
  const fresh = await prompt(await create());
  assert.ok(fresh.includes("LEARNED_MEMORY_UPDATED_FIXTURE"));
});
