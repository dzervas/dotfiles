import assert from "node:assert/strict";
import test from "node:test";

// Distinct module URLs reproduce independent extension module caches while
// retaining the shared process/globalThis used by Pi's extension loaders.
test("separate extension loads and reloads share live terminal activity", async (t) => {
	const load = (name: string) => {
		const url = new URL("../lib/terminal-progress.ts", import.meta.url);
		url.searchParams.set("loader", name);
		return import(url.href);
	};
	const bash = (await load("background-bash")).terminalActivity;
	const title = (await load("titlebar-spinner")).terminalActivity;
	t.after(() => {
		bash.setActive("sharing-test", false);
		title.setActive("sharing-test", false);
	});
	assert.equal(bash, title, "separate extension loaders must share the tracker");
	t.mock.method(process.stdout, "write", () => true);
	bash.setActive("sharing-test", true);
	assert.equal(title.isActive(), true);
	const reloaded = (await load("reload")).terminalActivity;
	assert.equal(reloaded, bash);
	assert.equal(reloaded.isActive(), true, "reload must retain running activity");
	bash.setActive("sharing-test", false);
	assert.equal(reloaded.isActive(), false);
});
