import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire, stripTypeScriptTypes } from "node:module";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";
import test from "node:test";
import sandbox from "../../sandbox.ts";
import { isSandboxed, PI_SANDBOX_STATE_KEY } from "../lib/sandbox-state.ts";

// Run with --experimental-transform-types --experimental-vm-modules.
// Real entry points and detector; no config, parsers, credentials or policy writes.
async function entryPoints() {
	const context = createContext({});
	let gates = 0, disposals = 0;
	const required = new Map<string, any>();
	const permissionsHandlers = new Map<string, Function>();
	const sandboxHandlers = new Map<string, Function>();
	const dependencies: Record<string, Record<string, unknown>> = {
		"node:module": { createRequire: () => (name: string) => {
			assert.equal(name, "pi-subagents/required-child-extensions");
			return { registerRequiredChildExtensions: (options: any) => {
				assert.equal(required.has(options.sessionId), false, "only one owner may register per session");
				required.set(options.sessionId, options);
				return { dispose() { if (required.get(options.sessionId) === options) { required.delete(options.sessionId); disposals++; } } };
			} };
		} },
		"node:os": { homedir: () => "/fixture" },
		"node:path": { join },
		"node:url": { fileURLToPath },
		"./permissions/extension": { default: () => { gates++; } },
		"./permissions/ask": { PERMISSIONS_ASK_BROKER_KEY: Symbol(), PERMISSIONS_ASK_EVENT: "fixture" },
	};
	const state = new SourceTextModule(stripTypeScriptTypes(readFileSync(new URL("../lib/sandbox-state.ts", import.meta.url), "utf8")), { context });
	const load = async (url: URL) => {
		const module = new SourceTextModule(stripTypeScriptTypes(readFileSync(url, "utf8")), {
			context, identifier: url.href, initializeImportMeta: (meta) => { meta.url = url.href; },
		});
		await module.link((name) => {
			if (name.endsWith("/lib/sandbox-state.ts")) return state;
			const exports = dependencies[name]; assert.ok(exports, name);
			return new SyntheticModule(Object.keys(exports), function () {
				for (const [key, value] of Object.entries(exports)) this.setExport(key, value);
			}, { context });
		});
		await module.evaluate();
		return module;
	};
	const permissionModule = await load(new URL("../permissions.ts", import.meta.url));
	const sandboxModule = await load(new URL("../../sandbox.ts", import.meta.url));
	const ctx = { hasUI: false, sessionManager: { getSessionId: () => "parent" } };
	return {
		required, context,
		get gates() { return gates; }, get disposals() { return disposals; },
		loadPermissions: () => permissionModule.namespace.default({ on: (event: string, handler: Function) => permissionsHandlers.set(event, handler) }),
		loadSandbox: () => sandboxModule.namespace.default({ on: (event: string, handler: Function) => sandboxHandlers.set(event, handler), events: { emit() {} } }),
		async start() { await permissionsHandlers.get("session_start")?.({}, ctx); await sandboxHandlers.get("session_start")?.({}, ctx); },
		stop() { permissionsHandlers.get("session_shutdown")?.({}, ctx); sandboxHandlers.get("session_shutdown")?.({}, ctx); },
	};
}

test("only a loaded sandbox extension requires itself in children, regardless of factory order", async () => {
	for (const sandboxFirst of [false, true]) {
		const h = await entryPoints();
		if (sandboxFirst) h.loadSandbox();
		h.loadPermissions();
		if (!sandboxFirst) h.loadSandbox();
		await h.start();
		assert.equal(h.gates, sandboxFirst ? 0 : 1);
		const extensions = h.required.get("parent").extensions;
		assert.equal(extensions.length, 1);
		assert.equal(extensions[0].id, "dotfiles.sandbox");
		assert.equal(extensions[0].path, fileURLToPath(new URL("../../sandbox.ts", import.meta.url)));
		assert.notEqual(h.required.get("parent").requireForAllRunners, true);
		await h.start();
		assert.equal(h.disposals, 1);
		h.stop();
		assert.equal(h.required.size, 0);
		assert.equal(h.disposals, 2);
	}
});

test("ordinary parents never register the sandbox and keep mandatory permission hooks", async () => {
	const h = await entryPoints();
	h.loadPermissions();
	await h.start();
	assert.equal(h.gates, 1);
	assert.equal(h.required.get("parent").requireForAllRunners, true);
	assert.deepEqual(Array.from(h.required.get("parent").extensions, (entry: any) => entry.id), ["dotfiles.permissions", "dotfiles.permission-prompt", "dotfiles.protected-paths"]);
	h.stop();
	assert.equal(h.required.size, 0);
});

test("real required-extension snapshots carry sandbox.ts into fresh children and grandchildren without env state", async (t) => {
	const require = createRequire(join(homedir(), ".pi", "agent", "npm", "package.json"));
	let api: string;
	try { api = require.resolve("pi-subagents/required-child-extensions"); }
	catch { t.skip("requires the configured pi-subagents installation"); return; }
	// Read the actual package's launch snapshot in this integration fixture.
	const registryUrl = new URL("../shared/required-child-extensions.js", pathToFileURL(api)).href;
	const { resolveRequiredChildExtensions } = await import(registryUrl);
	const globals = globalThis as Record<PropertyKey, unknown>;
	const previous = { legacy: globals.__DZERVAS_PI_SANDBOX__, state: globals[PI_SANDBOX_STATE_KEY] };
	delete globals.__DZERVAS_PI_SANDBOX__; delete globals[PI_SANDBOX_STATE_KEY];
	const handlers = new Map<string, Function>();
	t.after(() => {
		handlers.get("session_shutdown")?.();
		if (previous.legacy === undefined) delete globals.__DZERVAS_PI_SANDBOX__; else globals.__DZERVAS_PI_SANDBOX__ = previous.legacy;
		if (previous.state === undefined) delete globals[PI_SANDBOX_STATE_KEY]; else globals[PI_SANDBOX_STATE_KEY] = previous.state;
	});
	assert.equal(isSandboxed(), false);
	sandbox({ on: (name: string, handler: Function) => handlers.set(name, handler), events: { emit() {} } } as any);
	await handlers.get("session_start")!({}, { hasUI: false, sessionManager: { getSessionId: () => "sandbox-fixture-parent" } });
	const [required] = resolveRequiredChildExtensions("sandbox-fixture-parent");
	assert.equal(required.id, "dotfiles.sandbox");
	const detector = new URL("../lib/sandbox-state.ts", import.meta.url).href;
	const leafScript = `import {isSandboxed} from ${JSON.stringify(detector)};
		import sandbox from ${JSON.stringify(pathToFileURL(required.path).href)};
		const before = isSandboxed(); sandbox({on(){},events:{emit(){}}});
		console.log(JSON.stringify({before,after:isSandboxed()}));`;
	const childScript = `
		import {spawnSync} from "node:child_process";
		import {isSandboxed} from ${JSON.stringify(detector)};
		import sandbox from ${JSON.stringify(pathToFileURL(required.path).href)};
		import {resolveRequiredChildExtensions} from ${JSON.stringify(registryUrl)};
		const before=isSandboxed(); const handlers=new Map();
		sandbox({on:(name,fn)=>handlers.set(name,fn),events:{emit(){}}});
		await handlers.get("session_start")({}, {hasUI:false,sessionManager:{getSessionId:()=>"sandbox-fixture-child"}});
		const [next]=resolveRequiredChildExtensions("sandbox-fixture-child");
		if(next.path!==${JSON.stringify(required.path)}) throw Error("sandbox path not inherited");
		const nested=spawnSync(process.execPath,["--experimental-transform-types","--input-type=module","-e",${JSON.stringify(leafScript)}],{env:{},encoding:"utf8"});
		if(nested.status!==0)throw Error(nested.stderr);
		console.log(JSON.stringify({before,after:isSandboxed(),nested:JSON.parse(nested.stdout)}));
		handlers.get("session_shutdown")();`;
	const child = spawnSync(process.execPath, ["--experimental-transform-types", "--input-type=module", "-e", childScript], { env: {}, encoding: "utf8" });
	assert.equal(child.status, 0, child.stderr);
	assert.deepEqual(JSON.parse(child.stdout), { before: false, after: true, nested: { before: false, after: true } });
});

test("unsandboxed headless asks still fail closed without a broker; same-process forwarding still works", async () => {
	const context = createContext({});
	const ask = new SourceTextModule(stripTypeScriptTypes(readFileSync(new URL("../permissions/ask.ts", import.meta.url), "utf8")), { context });
	await ask.link((name) => {
		assert.equal(name, "./config");
		return new SyntheticModule(["saveRule"], function () {
			this.setExport("saveRule", () => { throw Error("fixture must not save rules"); });
		}, { context });
	});
	await ask.evaluate();
	const denied = await ask.namespace.askPermission({}, {}, "Fixture permission", { hasUI: false });
	assert.equal(denied.block, true);
	assert.match(denied.reason, /no UI available/);
	const broker = new SourceTextModule('globalThis[Symbol.for("dzervas.pi.permissions.ask-broker")] = async () => ({value: "allow"});', { context });
	await broker.link(() => { throw Error("unexpected dependency"); });
	await broker.evaluate();
	assert.equal(await ask.namespace.askPermission({}, {}, "Fixture permission", { hasUI: false }), undefined);
});

test("protected paths honor only published sandbox state, including late publisher loading", async () => {
	const context = createContext({});
	const state = new SourceTextModule(stripTypeScriptTypes(readFileSync(new URL("../lib/sandbox-state.ts", import.meta.url), "utf8")), { context });
	const entry = new SourceTextModule(stripTypeScriptTypes(readFileSync(new URL("../protected-paths.ts", import.meta.url), "utf8")), { context });
	await entry.link((name) => { assert.equal(name, "./lib/sandbox-state.ts"); return state; });
	await entry.evaluate();
	let gate: Function | undefined;
	entry.namespace.default({ on: (_event: string, handler: Function) => { gate = handler; } });
	const event = { toolName: "write", input: { path: "/fixture/.git/config" } };
	assert.equal((await gate!(event, { hasUI: false })).block, true);
	context.__DZERVAS_PI_SANDBOX__ = { enabled: true };
	assert.equal(await gate!(event, { hasUI: false }), undefined);
	gate = undefined;
	entry.namespace.default({ on: (_event: string, handler: Function) => { gate = handler; } });
	assert.equal(gate, undefined, "already contained children install no path gate");
});
