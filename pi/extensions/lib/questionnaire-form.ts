import type { AcpForm } from "./acp-form.ts";

export interface QuestionOption {
	value: string;
	label: string;
	description?: string;
}

export interface Question {
	id: string;
	label: string;
	prompt: string;
	options: QuestionOption[];
	allowOther: boolean;
}

export interface Answer {
	id: string;
	value: string;
	label: string;
	wasCustom: boolean;
	index?: number;
}

export interface QuestionnaireResult {
	questions: Question[];
	answers: Answer[];
	cancelled: boolean;
}

export function questionnaireForm(questions: Question[]): AcpForm {
	const form: AcpForm = {
		message: "Answer the questions below. For a custom answer, select Other and fill in its text field.",
		requestedSchema: { type: "object", properties: {}, required: [] },
	};
	questions.forEach((question, index) => {
		const key = `q${index + 1}`;
		const field = { type: "string" as const, title: question.label, description: question.prompt };
		if (question.options.length === 0) {
			if (!question.allowOther) throw new Error(`Question ${question.id} has no available answers`);
			form.requestedSchema.properties[key] = field;
		} else {
			const oneOf = question.options.map((option, i) => ({
				const: `option-${i + 1}`,
				title: option.label,
				...(option.description ? { description: option.description } : {}),
			}));
			if (question.allowOther) {
				oneOf.push({ const: "other", title: "Other (write your answer below)" });
				form.requestedSchema.properties[`${key}_other`] = {
					type: "string", title: `${question.label}: custom answer`,
					description: "Used only when Other is selected.",
				};
			}
			form.requestedSchema.properties[key] = { ...field, oneOf };
		}
		form.requestedSchema.required.push(key);
	});
	return form;
}

export function questionnaireAnswers(questions: Question[], content: Record<string, string>): Answer[] {
	return questions.map((question, index) => {
		const key = `q${index + 1}`;
		const value = content[key];
		if (question.options.length === 0 || value === "other") {
			const text = (question.options.length === 0 ? value : content[`${key}_other`])?.trim() || "(no response)";
			return { id: question.id, value: text, label: text, wasCustom: true };
		}
		const optionIndex = Number(value.slice("option-".length)) - 1;
		const option = question.options[optionIndex];
		return { id: question.id, value: option.value, label: option.label, wasCustom: false, index: optionIndex + 1 };
	});
}
