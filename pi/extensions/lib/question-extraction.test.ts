import assert from "node:assert/strict";
import test from "node:test";

import { extractMarkedQuestions } from "./question-extraction.ts";

const MESSAGE = `❓ **Q17** — **"Browser local" needs a translation.** Cron must be evaluated server-side. Choose: (a) server-local; (b) capture the browser's IANA zone.

➡️ (a). Same machine, so storing another zone can drift from reality.

❓ **Q18** — **Scheduler mechanics.** Accept a 60s tick, or do you want a coarser tick?

➡️ Accept 60s. It's cheap.`;

test("extracts explicitly marked questions even when recommendations follow them", () => {
	assert.deepEqual(extractMarkedQuestions(MESSAGE), [
		{
			question:
				'Q17 — "Browser local" needs a translation. Cron must be evaluated server-side. Choose: (a) server-local; (b) capture the browser\'s IANA zone.',
			context:
				"Assistant recommendation: (a). Same machine, so storing another zone can drift from reality.",
		},
		{
			question: "Q18 — Scheduler mechanics. Accept a 60s tick, or do you want a coarser tick?",
			context: "Assistant recommendation: Accept 60s. It's cheap.",
		},
	]);
});

test("does not claim unmarked prose contains explicit questions", () => {
	assert.deepEqual(extractMarkedQuestions("Should this use SQLite or Postgres?"), []);
});
