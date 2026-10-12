import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { setBeadsSnapshot, setUnclaimedParents } from "./beads.ts";
import { evictSession, setRenderSession, setTasks } from "./state.ts";
import { TodoWidget } from "./view.ts";

// Mark semantic colors so the test checks dimming as well as content.
const theme = {
	fg: (color: string, text: string) => `<${color}>${text}</${color}>`,
	bold: (text: string) => text,
} as Theme;

test("the above-editor widget shows dimmed comma-separated roots only while idle", () => {
	let component: Component | undefined;
	let placement: string | undefined;
	const tui = { requestRender() {} } as TUI;
	const ui = {
		setWidget(_key: string, factory: any, options?: { placement: string }) {
			component = factory?.(tui, theme);
			placement = options?.placement;
		},
	} as ExtensionUIContext;
	const widget = new TodoWidget();
	setRenderSession("idle-view-test");
	setTasks("idle-view-test", []);
	setBeadsSnapshot(undefined);
	try {
		widget.setUICtx(ui);
		widget.update();
		assert.equal(component, undefined);

		setUnclaimedParents([{ id: "p-1", title: "First parent" }, { id: "p-2", title: "Second parent" }]);
		widget.update();
		assert.equal(placement, "aboveEditor");
		assert.deepEqual(component!.render(100), ["<dim>First parent, Second parent</dim>", ""]);
		assert.ok(component!.render(12)[0].includes("…"));

		setTasks("idle-view-test", [{ subject: "Do work", status: "in_progress" }]);
		widget.update();
		assert.ok(component!.render(100)[0].includes("Todos"));
		assert.ok(!component!.render(100).join("\n").includes("First parent"));

		setTasks("idle-view-test", []);
		setBeadsSnapshot({ claimed: { id: "p-3", title: "Claimed work", state: "in_progress" }, children: [] });
		widget.update();
		assert.ok(component!.render(100)[0].includes("Claimed work"));
		assert.ok(!component!.render(100).join("\n").includes("First parent"));

		setBeadsSnapshot(undefined);
		widget.update();
		assert.ok(component!.render(100)[0].includes("First parent"));
		setUnclaimedParents([]);
		widget.update();
		assert.equal(component, undefined);
	} finally {
		widget.dispose();
		setBeadsSnapshot(undefined);
		setUnclaimedParents([]);
		evictSession("idle-view-test");
		setRenderSession("");
	}
});
