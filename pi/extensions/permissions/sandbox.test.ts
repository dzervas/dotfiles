import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";
import test from "node:test";

// Exercise the real extension wiring with the rule engine stubbed: no config/auth reads.
async function harness(initiallySandboxed = false) {
	const context = createContext({ __DZERVAS_PI_SANDBOX__: { enabled: initiallySandboxed } });
	const source = stripTypeScriptTypes(readFileSync(new URL("./extension.ts", import.meta.url), "utf8"));
	const dependencies: Record<string, Record<string, unknown>> = {
		"./ask": { askPermission: () => ({ block: true }) },
		"./classify": { classify: (subject: unknown) => subject },
		"./config": { loadConfig: () => ({}) },
		"./decide": { decide: () => ({ action: "deny", reason: "Fixture rule" }) },
		"./read-mode": { createReadMode: () => ({ clear() {}, restore() {}, enabled: false }) },
		"./self-test": { runSelfTest: () => [] },
		"./subject": { normalize: () => ({ paths: [], findings: [] }) },
	};
	const module = new SourceTextModule(source, { context });
	await module.link((name) => {
		const exports = dependencies[name];
		assert.ok(exports, `Unexpected dependency: ${name}`);
		return new SyntheticModule(Object.keys(exports), function () {
			for (const [key, value] of Object.entries(exports)) this.setExport(key, value);
		}, { context });
	});
	await module.evaluate();
	const events = new Map<string, (state: unknown) => void>();
	const handlers = new Map<string, (event: unknown, ctx: unknown) => Promise<any>>();
	const commands = new Map<string, { handler: (args: string, ctx: unknown) => Promise<void> }>();
	let status = "";
	const ctx = { ui: { theme: { fg: (_: string, text: string) => text },
		setStatus: (_: string, value: string) => { status = value; }, notify() {} } };
	module.namespace.default({ events: { on: (name: string, callback: (state: unknown) => void) => events.set(name, callback) },
		on: (name: string, callback: (event: unknown, ctx: unknown) => Promise<any>) => handlers.set(name, callback),
		registerCommand: (name: string, command: any) => commands.set(name, command),
	});
	return {
		emit: (enabled: boolean) => events.get("sandbox:state")!({ enabled }),
		start: () => handlers.get("session_start")!({}, ctx),
		tool: () => handlers.get("tool_call")!({}, ctx),
		toggle: () => commands.get("yolo")!.handler("", ctx),
		hasYolo: () => commands.has("yolo"), status: () => status,
	};
}

test("sandbox detected before permissions loading defaults to YOLO and registers its toggle", async () => {
	const h = await harness(true);
	assert.ok(h.hasYolo());
	await h.start();
	assert.match(h.status(), /yolo/);
	assert.equal((await h.tool()).block, false);
	await h.toggle();
	h.emit(true); h.emit(true);
	await h.start();
	assert.equal((await h.tool()).block, true, "repeated sandbox events must preserve explicit YOLO off");
});

test("late sandbox detection enables YOLO once; ordinary sessions keep permissions", async () => {
	const h = await harness();
	assert.equal(h.hasYolo(), false);
	assert.equal((await h.tool()).block, true);
	h.emit(true);
	await h.start();
	assert.match(h.status(), /yolo/);
	assert.equal((await h.tool()).block, false);
	await h.toggle();
	h.emit(true);
	assert.equal((await h.tool()).block, true);
	await h.toggle();
	assert.equal((await h.tool()).block, false);
	h.emit(false);
	assert.equal((await h.tool()).block, true, "no bypass without sandbox state");
});
