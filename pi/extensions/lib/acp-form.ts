import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

// Semantic forms travel over Pi's existing RPC editor request/response channel.
// The ACP launcher opts in; other RPC clients keep their normal editor behavior.
export const ACP_FORM_TITLE = "__pi_acp_form_v1__";

export interface FormField {
	type: "string";
	title?: string;
	description?: string;
	minLength?: number;
	oneOf?: { const: string; title: string; description?: string }[];
}

export interface AcpForm {
	message: string;
	requestedSchema: {
		type: "object";
		properties: Record<string, FormField>;
		required: string[];
	};
}

export function supportsAcpForms(ctx: Pick<ExtensionContext, "mode">): boolean {
	return ctx.mode === "rpc" && process.env.PI_ACP_FORMS === "1";
}

export function parseFormResponse(form: AcpForm, value: string): Record<string, string> {
	const content: unknown = JSON.parse(value);
	if (!content || typeof content !== "object" || Array.isArray(content)) {
		throw new Error("Invalid ACP form response");
	}
	const answers: Record<string, string> = {};
	for (const [key, field] of Object.entries(form.requestedSchema.properties)) {
		const answer: unknown = Object.hasOwn(content, key)
			? (content as Record<string, unknown>)[key]
			: undefined;
		if (answer === undefined && !form.requestedSchema.required.includes(key)) continue;
		if (typeof answer !== "string" ||
			(field.minLength !== undefined && answer.length < field.minLength) ||
			(field.oneOf && !field.oneOf.some((option) => option.const === answer))) {
			throw new Error(`Invalid ACP form answer: ${key}`);
		}
		answers[key] = answer;
	}
	return answers;
}

export async function requestAcpForm(
	ctx: Pick<ExtensionContext, "mode" | "ui">,
	form: AcpForm,
): Promise<Record<string, string> | undefined> {
	if (!supportsAcpForms(ctx)) throw new Error("ACP forms are not available in this client");
	const value = await ctx.ui.editor(ACP_FORM_TITLE, JSON.stringify(form));
	return value === undefined ? undefined : parseFormResponse(form, value);
}
