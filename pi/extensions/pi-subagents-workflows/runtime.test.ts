import assert from "node:assert/strict";
import test from "node:test";
import { parseWorkflow, QuickJSWorkflowRuntime } from "./runtime";

test("QuickJS workflow bridges parallel agents concurrently", async () => {
	let active = 0;
	let peak = 0;
	const result = await new QuickJSWorkflowRuntime().execute(
		parseWorkflow(`
export const meta = { name: "test", description: "test" };
const values = await parallel([() => agent("one"), () => agent("two")]);
return { values, cwd: process.cwd(), args };
`),
		{
			args: { ok: true },
			cwd: "/workflow",
			tool: async () => null,
			phase: () => {},
			log: () => {},
			agent: async (prompt) => {
				active++;
				peak = Math.max(peak, active);
				await new Promise((resolve) => setTimeout(resolve, 10));
				active--;
				return prompt;
			},
		},
	);

	assert.equal(peak, 2);
	assert.deepEqual(result, { values: ["one", "two"], cwd: "/workflow", args: { ok: true } });
});
test("pipeline keeps items concurrent and stages sequential", async () => {
	const result = await new QuickJSWorkflowRuntime().execute(
		parseWorkflow(`
export const meta = { name: "pipeline", description: "pipeline" };
return pipeline([1, 2],
	async (value, original, index) => value + original + index,
	async (value) => value * 2,
);
`),
		{
			args: {},
			cwd: "/workflow",
			agent: async () => null,
			tool: async () => null,
			phase: () => {},
			log: () => {},
		},
	);

	assert.deepEqual(result, [4, 10]);
});
