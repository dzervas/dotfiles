import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { setParentBeadsActor } from "../todo/beads.ts";

test("parent session identity is stable across reload/resume and distinct for another parent", () => {
	const env: NodeJS.ProcessEnv = { BEADS_ACTOR: "operator" };
	assert.equal(setParentBeadsActor("parent-a", "tui", undefined, env), "pi:parent-a");
	assert.equal(setParentBeadsActor("parent-a", "tui", undefined, env), "pi:parent-a");
	// A user-opened fork is an interactive parent, despite its parentSession header.
	assert.equal(setParentBeadsActor("parent-b", "tui", "parent-a.jsonl", env), "pi:parent-b");
	assert.equal(setParentBeadsActor("rpc-parent", "rpc", undefined, env), "pi:rpc-parent");
});

test("foreground, nested and detached children preserve the parent team actor", () => {
	const env: NodeJS.ProcessEnv = {};
	setParentBeadsActor("root", "tui", undefined, env);
	for (let i = 0; i < 14; i++) {
		assert.equal(setParentBeadsActor(`child-${i}`, "print", "root.jsonl", env), "pi:root");
		assert.equal(setParentBeadsActor(`nested-${i}`, "print", `child-${i}.jsonl`, env), "pi:root");
	}
	// SDK children of an unpersisted root have no parentSession header.
	assert.equal(setParentBeadsActor("unpersisted-child", "print", undefined, env), "pi:root");
	const detached = { ...env, PI_SUBAGENT_CHILD: "1" };
	assert.equal(setParentBeadsActor("detached", "print", undefined, detached), "pi:root");
	assert.equal(env.BEADS_ACTOR, "pi:root");
});

test("headless roots receive an actor; a child without inherited identity cannot invent one", () => {
	const root: NodeJS.ProcessEnv = {};
	assert.equal(setParentBeadsActor("root", "print", undefined, root), "pi:root");
	const detached: NodeJS.ProcessEnv = { PI_SUBAGENT_CHILD: "1" };
	assert.equal(setParentBeadsActor("child", "print", undefined, detached), undefined);
	assert.equal(detached.BEADS_ACTOR, undefined);
});

test("the assigned environment reaches a detached child and its descendants", () => {
	const env: NodeJS.ProcessEnv = {};
	setParentBeadsActor("root", "tui", undefined, env);
	const module = new URL("../todo/beads.ts", import.meta.url).href;
	const script = `
		import { spawnSync } from "node:child_process";
		import { setParentBeadsActor } from ${JSON.stringify(module)};
		const actor = setParentBeadsActor("detached-child", "print");
		const nested = spawnSync(process.execPath, ["-e", "process.stdout.write(process.env.BEADS_ACTOR ?? '')"], { encoding: "utf8" });
		if (nested.status !== 0) process.exit(1);
		console.log(JSON.stringify({ actor, nested: nested.stdout }));
	`;
	const child = spawnSync(process.execPath, ["--experimental-transform-types", "--input-type=module", "-e", script], {
		env: { ...env, PI_SUBAGENT_CHILD: "1" },
		encoding: "utf8",
	});
	assert.equal(child.status, 0, child.stderr);
	assert.deepEqual(JSON.parse(child.stdout), { actor: "pi:root", nested: "pi:root" });
});
