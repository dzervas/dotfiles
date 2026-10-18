import assert from "node:assert/strict";
import { register } from "node:module";
import test from "node:test";
import type { MemoryPanelStore } from "../memory/panel.ts";
import type { Note, Scope } from "../memory/store.ts";

// Pi provides these packages at runtime. NODE_PATH can point at Pi's node_modules
// for standalone Node tests. Keep the real SettingsList and key handling; only
// substitute the host's theme with an unstyled, deterministic theme.
register(`data:text/javascript,${encodeURIComponent(`
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
const require = createRequire(${JSON.stringify(import.meta.url)});
export async function resolve(specifier, context, next) {
  if (specifier === "@earendil-works/pi-coding-agent") {
    return { url: "data:text/javascript," + encodeURIComponent(
      'export const getSettingsListTheme = () => ({ label: t => t, value: t => t, description: t => t, cursor: "> ", hint: t => t });'
    ), shortCircuit: true };
  }
  if (specifier === "@earendil-works/pi-tui") {
    return { url: pathToFileURL(require.resolve(specifier)).href, shortCircuit: true };
  }
  return next(specifier, context);
}
`)}`, import.meta.url);
const { showMemoryPanel } = await import("../memory/panel.ts");

const enter = "\r", esc = "\x1b", down = "\x1b[B", right = "\x1b[C", left = "\x1b[D";
const original = { date: "2026-10-18", text: "Use the complete original memory text, including its final words." };

function harness(scripts: string[][], initial: Note[] = [original]) {
	const pages: Record<Scope, Note[]> = { project: [...initial], global: [] };
	const renders: string[] = [];
	const mutations: unknown[][] = [];
	const notifications: [string, string][] = [];
	const editors: unknown[][] = [];
	const inputs: unknown[][] = [];
	const events: any[] = [];
	const choices: (string | undefined)[] = [];
	const answers: (string | undefined)[] = [];
	const reads: Scope[] = [];
	let failSave = false;
	const store: MemoryPanelStore = {
		async read(scope) { reads.push(scope); return { namespace: `pi/${scope}`, notes: pages[scope] }; },
		async mutate(scope, action, text, previous) {
			mutations.push([scope, action, text, previous]);
			if (failSave) throw Error("disk unavailable");
			pages[scope] = pages[scope].filter(n => n.text !== (previous ?? text));
			if (action !== "forget") pages[scope].push({ date: "2026-10-19", text });
			return { notes: pages[scope] };
		},
	};
	const ctx = {
		mode: "tui",
		ui: {
			notify: (message: string, level: string) => notifications.push([message, level]),
			select: async () => choices.shift(),
			editor: async (...args: unknown[]) => { editors.push(args); return answers.shift(); },
			input: async (...args: unknown[]) => { inputs.push(args); return answers.shift(); },
			async custom(factory: any) {
				const keys = scripts.shift();
				assert.ok(keys, "unexpected extra panel");
				let closed = false, result: unknown;
				const component = factory({ requestRender() {} }, { fg: (_: string, s: string) => s }, {}, (value: unknown) => { closed = true; result = value; });
				renders.push(component.render(80).join("\n"));
				for (const key of keys) {
					assert.equal(closed, false);
					component.handleInput(key);
					if (!closed) renders.push(component.render(80).join("\n"));
				}
				assert.ok(closed, "script must close panel");
				return result;
			},
		},
	};
	return {
		ctx, choices, answers, renders, mutations, notifications, editors, inputs, reads, events,
		failSave() { failSave = true; },
		run: () => showMemoryPanel({ events: { emit: (_: string, e: unknown) => events.push(e) } } as any, ctx as any, store),
	};
}

test("Project opens with Add selected; blank Add saves and refreshes the list", async () => {
	const h = harness([[enter], [esc]]);
	h.answers.push("new memory");
	await h.run();
	assert.match(h.renders[0], /\[Project\].*Global/);
	assert.match(h.renders[0], /> Add memory/);
	assert.match(h.renders[0], /2026-10-18/);
	assert.deepEqual(h.inputs, [["Add memory"]]);
	assert.deepEqual(h.mutations, [["project", "remember", "new memory", undefined]]);
	assert.match(h.renders.at(-1)!, /new memory/);
	assert.deepEqual(h.events.map(e => e.waiting), [true, false]);
});

test("Tab and arrows select scope, preserving Global after mutation", async () => {
	const h = harness([[right], [left], ["\t"], [enter], [esc]]);
	h.answers.push("global memory");
	await h.run();
	assert.deepEqual(h.reads, ["project", "global", "project", "global"]);
	assert.equal(h.mutations[0][0], "global");
	assert.match(h.renders.at(-1)!, /Project.*\[Global\]/);
});

test("existing note shows full wrapped preview; Edit is prefilled and cancel does not save", async () => {
	const h = harness([[down, enter], [esc]]);
	h.choices.push("Edit");
	h.answers.push(undefined);
	await h.run();
	assert.match(h.renders[1], /including its final words/);
	assert.deepEqual(h.editors, [["Edit memory", original.text]]);
	assert.deepEqual(h.mutations, []);
});

test("Edit persists replacement and displays it; action cancellation is harmless", async () => {
	const h = harness([[down, enter], [down, enter], [esc]]);
	h.choices.push(undefined, "Edit");
	h.answers.push("updated memory");
	await h.run();
	assert.deepEqual(h.mutations, [["project", "replace", "updated memory", original.text]]);
	assert.match(h.renders.at(-1)!, /updated memory/);
	assert.doesNotMatch(h.renders.at(-1)!, /Use the complete/);
});

test("Forget mutates the selected note and refreshes", async () => {
	const h = harness([[down, enter], [esc]]);
	h.choices.push("Forget");
	await h.run();
	assert.deepEqual(h.mutations, [["project", "forget", original.text, undefined]]);
	assert.doesNotMatch(h.renders.at(-1)!, /2026-10-18/);
});

test("failed save reports error and never displays an unsaved replacement", async () => {
	const h = harness([[down, enter], [esc]]);
	h.choices.push("Edit"); h.answers.push("unsaved"); h.failSave();
	await h.run();
	assert.match(h.renders.at(-1)!, /Use the complete/);
	assert.doesNotMatch(h.renders.at(-1)!, /unsaved/);
	assert.deepEqual(h.notifications, [["Could not save memory: Error: disk unavailable", "error"]]);
	assert.deepEqual(h.reads, ["project", "project"], "reload the active scope after a failed/stale edit");
});

test("real SettingsList scrolls through all notes", async () => {
	const notes = Array.from({ length: 30 }, (_, i) => ({ date: "2026-10-18", text: `memory ${i}` }));
	const h = harness([[...Array(30).fill(down), enter], [esc]], notes);
	h.choices.push("Edit");
	await h.run();
	assert.deepEqual(h.editors, [["Edit memory", "memory 29"]]);
	assert.match(h.renders[30], /31\/31/);
});

test("non-TUI mode does not attempt a terminal panel", async () => {
	const h = harness([]);
	h.ctx.mode = "rpc";
	await h.run();
	assert.deepEqual(h.reads, []);
	assert.deepEqual(h.events, []);
	assert.match(h.notifications[0][0], /requires TUI/);
});
