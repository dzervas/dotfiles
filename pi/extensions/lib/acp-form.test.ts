import assert from "node:assert/strict";
import test from "node:test";
import { ACP_FORM_TITLE, parseFormResponse, requestAcpForm, supportsAcpForms } from "./acp-form.ts";
import { questionnaireAnswers, questionnaireForm, type Question } from "./questionnaire-form.ts";

const questions: Question[] = [
	{
		id: "database", label: "Database", prompt: "Which database?",
		options: [
			{ value: "pg", label: "PostgreSQL", description: "Existing service" },
			{ value: "sqlite", label: "SQLite" },
		],
		allowOther: true,
	},
	{ id: "notes", label: "Notes", prompt: "Anything else?", options: [], allowOther: true },
];

test("questionnaire fields preserve labels/descriptions and offer custom text", () => {
	const form = questionnaireForm(questions);
	assert.deepEqual(form.requestedSchema.required, ["q1", "q2"]);
	assert.deepEqual(form.requestedSchema.properties.q1.oneOf, [
		{ const: "option-1", title: "PostgreSQL", description: "Existing service" },
		{ const: "option-2", title: "SQLite" },
		{ const: "other", title: "Other (write your answer below)" },
	]);
	assert.equal(form.requestedSchema.properties.q1.description, "Which database?");
	assert.equal(form.requestedSchema.properties.q1_other.type, "string");
	assert.equal(form.requestedSchema.properties.q2.oneOf, undefined);
});

test("selected choices retain original values and one-based indexes", () => {
	const form = questionnaireForm(questions);
	const content = parseFormResponse(form, JSON.stringify({ q1: "option-2", q2: "  Fine  " }));
	assert.deepEqual(questionnaireAnswers(questions, content), [
		{ id: "database", value: "sqlite", label: "SQLite", wasCustom: false, index: 2 },
		{ id: "notes", value: "Fine", label: "Fine", wasCustom: true },
	]);
});

test("Other and blank text follow the terminal questionnaire semantics", () => {
	const form = questionnaireForm(questions);
	const content = parseFormResponse(form, JSON.stringify({ q1: "other", q1_other: "  MySQL  ", q2: "" }));
	assert.deepEqual(questionnaireAnswers(questions, content), [
		{ id: "database", value: "MySQL", label: "MySQL", wasCustom: true },
		{ id: "notes", value: "(no response)", label: "(no response)", wasCustom: true },
	]);
});

test("disallowed Other has no custom field and cannot be returned", () => {
	const form = questionnaireForm([{ ...questions[0], allowOther: false }]);
	assert.equal(form.requestedSchema.properties.q1_other, undefined);
	assert.throws(() => parseFormResponse(form, '{"q1":"other"}'), /Invalid ACP form answer/);
	assert.throws(() => questionnaireForm([{ ...questions[1], allowOther: false }]), /no available answers/);
});

test("field keys cannot collide with user-provided IDs or option values", () => {
	const qs = [{ ...questions[0], id: "__proto__", options: [{ value: "other", label: "Literal other" }] }];
	const form = questionnaireForm(qs);
	const result = questionnaireAnswers(qs, parseFormResponse(form, '{"q1":"option-1"}'));
	assert.equal(result[0].value, "other");
	assert.equal(result[0].wasCustom, false);
});

test("rejects malformed, missing, and wrongly typed answers", () => {
	const form = questionnaireForm(questions);
	for (const value of ["null", "[]", "{}", '{"q1":true,"q2":"ok"}', '{"q1":"option-99","q2":"ok"}']) {
		assert.throws(() => parseFormResponse(form, value));
	}
	const requiredText = { message: "Name", requestedSchema: {
		type: "object" as const, properties: { name: { type: "string" as const, minLength: 1 } }, required: ["name"],
	} };
	assert.throws(() => parseFormResponse(requiredText, '{"name":""}'));
});

test("form transport opts in only for RPC and returns structured answers or cancellation", async () => {
	const previous = process.env.PI_ACP_FORMS;
	try {
		delete process.env.PI_ACP_FORMS;
		assert.equal(supportsAcpForms({ mode: "rpc" }), false);
		process.env.PI_ACP_FORMS = "1";
		assert.equal(supportsAcpForms({ mode: "tui" }), false);
		assert.equal(supportsAcpForms({ mode: "rpc" }), true);
		const form = questionnaireForm(questions);
		let request: unknown;
		const ctx = {
			mode: "rpc" as const,
			ui: { editor: async (title: string, prefill: string) => {
				request = { title, prefill: JSON.parse(prefill) };
				return '{"q1":"option-1","q2":"ok"}';
			} },
		} as Parameters<typeof requestAcpForm>[0];
		assert.deepEqual(await requestAcpForm(ctx, form), { q1: "option-1", q2: "ok" });
		assert.deepEqual(request, { title: ACP_FORM_TITLE, prefill: form });
		ctx.ui.editor = async () => undefined;
		assert.equal(await requestAcpForm(ctx, form), undefined);
	} finally {
		if (previous === undefined) delete process.env.PI_ACP_FORMS;
		else process.env.PI_ACP_FORMS = previous;
	}
});
