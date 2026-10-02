import assert from "node:assert/strict";
import test from "node:test";
import fleetSession from "./fleet-session.ts";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

test("fleet reports Pi-owned start and rename events over OSC, only in TUI mode", (t) => {
	const handlers = new Map<string, (_: unknown, ctx: ExtensionContext) => void>();
	const output: string[] = [];
	t.mock.method(process.stdout, "write", (text: string) => { output.push(text); return true; });
	fleetSession({
		on: (event: string, handler: (_: unknown, ctx: ExtensionContext) => void) => handlers.set(event, handler),
		getSessionName: () => "Importer",
	} as unknown as ExtensionAPI);
	const ctx = { mode: "tui", cwd: "/project", sessionManager: { getSessionFile: () => "/sessions/a.jsonl" } } as unknown as ExtensionContext;
	for (const event of ["session_start", "session_info_changed"]) handlers.get(event)!({}, ctx);
	assert.equal(output.length, 2);
	const payload = output[0].match(/^\u001b\]777;pi-session;([A-Za-z0-9+/=]+)\u0007$/)![1];
	assert.deepEqual(JSON.parse(Buffer.from(payload, "base64").toString()), { file: "/sessions/a.jsonl", cwd: "/project", name: "Importer" });
	handlers.get("session_start")!({}, { ...ctx, mode: "headless" } as ExtensionContext);
	assert.equal(output.length, 2);
});
