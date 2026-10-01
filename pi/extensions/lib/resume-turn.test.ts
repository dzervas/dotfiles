import assert from "node:assert/strict";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerResumeContextStripper, RESUME_CUSTOM_TYPE } from "./resume-turn.ts";

function session() {
	const handlers = new Map<string, Function[]>();
	const api = {
		on(name: string, handler: Function) {
			handlers.set(name, [...(handlers.get(name) ?? []), handler]);
		},
	} as unknown as ExtensionAPI;
	return { api, handlers };
}

test("each SDK session strips resume messages while repeated registration is deduplicated", () => {
	const parent = session();
	const child = session();
	for (const current of [parent, child]) {
		registerResumeContextStripper(current.api);
		registerResumeContextStripper(current.api);
		assert.equal(current.handlers.get("context")?.length, 1);
		const user = { role: "user", content: "Existing task" };
		const event = { messages: [user,
			{ role: "custom", customType: RESUME_CUSTOM_TYPE },
			{ role: "assistant", stopReason: "error" },
		] };
		assert.deepEqual(current.handlers.get("context")![0](event), { messages: [user] });
	}
});

test("shutdown permits the same API to register in a replacement runtime", () => {
	const current = session();
	registerResumeContextStripper(current.api);
	current.handlers.get("session_shutdown")![0]();
	current.handlers.clear();
	registerResumeContextStripper(current.api);
	assert.equal(current.handlers.get("context")?.length, 1);
});
