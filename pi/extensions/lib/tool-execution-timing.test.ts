import assert from "node:assert/strict";
import test from "node:test";
import { ToolExecutionTiming } from "./tool-execution-timing.ts";

function setup() {
	let now = 0;
	return {
		timing: new ToolExecutionTiming(() => now),
		advance: (ms: number) => { now += ms; },
		card: { toolCallId: "bash-1", state: {} as Record<string, unknown>, executionStarted: true },
	};
}

test("approval wait and denied calls never start the native card timer", () => {
	const { timing, advance, card } = setup();
	assert.equal(timing.context(card).executionStarted, false);
	advance(60000);
	assert.equal(timing.context(card).executionStarted, false);
	assert.equal(card.state.startedAt, undefined);
});

test("execution starts after approval and redraws preserve the actual timestamp", () => {
	const { timing, advance, card } = setup();
	timing.context(card);
	advance(60000);
	timing.start(card.toolCallId);
	assert.equal(timing.context(card).executionStarted, true);
	assert.equal(card.state.startedAt, 60000);
	advance(3000);
	assert.equal(timing.context(card).state.startedAt, 60000);
});

test("a result rendered before renderCall also receives the actual start", () => {
	const { timing, advance, card } = setup();
	advance(42000);
	timing.start(card.toolCallId);
	advance(1000);
	const resultContext = timing.context(card);
	assert.equal(resultContext.state.startedAt, 42000);
	assert.equal(timing.context(card).state.startedAt, 42000);
	// The transferred timestamp is no longer retained outside its card state.
	assert.equal(timing.context({ ...card, state: {} }).executionStarted, false);
});
