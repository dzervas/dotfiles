// Advisory-only local command classifier. It runs the request through pi's
// AI harness (completeSimple against an OpenAI-compatible local endpoint) so we
// reuse pi's provider request/response handling instead of hand-rolling HTTP.
// The result is recorded on subject.llmAdvice for UI display only — the
// decision engine never trusts it.

import { completeSimple, type Model } from "@earendil-works/pi-ai/compat";
import type { Action, LlmClassifierAdvice, PermissionSubject } from "../types";

const DEFAULT_MODEL = "coder-model";
const DEFAULT_BASE_URL = "http://127.0.0.1:1337/v1";

const SYSTEM_PROMPT = `You are a command safety classifier for a shell permissions gate.
You judge ONLY the security risk of running the command as-is, on this machine.

Classify into exactly one action:
- allow: reads, inspection, builds, tests, or edits confined to the project. Loops,
  pipes, subshells, and shell syntax are all fine — they are NOT risky by themselves.
- ask: unclear intent, reaches the network, touches credentials/secrets, writes far
  outside the project, or has surprising side effects.
- deny: clearly destructive or hostile (e.g. rm -rf of important paths, disk wipes,
  fork bombs, exfiltrating secrets, piping remote scripts straight into a shell).

Do NOT consider portability, style, POSIX compliance, or whether syntax works in
every shell. Those are irrelevant to safety.

Respond with ONLY compact JSON, no prose:
{"action":"allow|ask|deny","confidence":0-100,"reason":"short safety reason"}`;

type ParsedAdvice = {
	action?: unknown;
	confidence?: unknown;
	reason?: unknown;
};

function baseUrl(): string {
	return (process.env.PI_PERMISSIONS_CLASSIFIER_BASE_URL?.trim() || DEFAULT_BASE_URL).replace(
		/\/$/u,
		"",
	);
}

function modelId(): string {
	return (process.env.PI_PERMISSIONS_CLASSIFIER_MODEL ?? DEFAULT_MODEL).trim();
}

function isAction(value: unknown): value is Action {
	return value === "allow" || value === "ask" || value === "deny";
}

function extractJson(text: string): ParsedAdvice | undefined {
	const candidate = text.match(/\{[\s\S]*\}/u)?.[0] ?? text;
	try {
		return JSON.parse(candidate) as ParsedAdvice;
	} catch {
		return undefined;
	}
}

function parseAdvice(text: string, model: string): LlmClassifierAdvice | undefined {
	const parsed = extractJson(text);
	if (!parsed || !isAction(parsed.action)) return undefined;

	const confidence = Number(parsed.confidence);
	if (!Number.isFinite(confidence)) return undefined;

	return {
		action: parsed.action,
		confidence: Math.max(0, Math.min(100, Math.round(confidence))),
		reason: typeof parsed.reason === "string" ? parsed.reason.slice(0, 180) : "No reason given",
		model,
	};
}

function classifierModel(id: string): Model<"openai-completions"> {
	return {
		id,
		name: id,
		api: "openai-completions",
		provider: "permissions-local-classifier",
		baseUrl: baseUrl(),
		reasoning: false,
		input: ["text"],
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: 32_000,
		maxTokens: 256,
	};
}

function userPrompt(subject: PermissionSubject): string {
	const commands = subject.commands.length > 0 ? subject.commands : [subject.rawInput];
	// const findings = subject.findings.map((finding) => finding.reason).join("; ") || "none";
	return [
		`Tool: ${subject.toolName}`,
		`Command:\n${subject.rawInput}`,
		`Parsed sub-commands:\n${commands.map((command) => `- ${command}`).join("\n")}`,
		// Heavily biases the model
		// `Static analyzer findings: ${findings}`,
	].join("\n\n");
}

export async function classifyWithLocalLlm(
	subject: PermissionSubject,
	signal?: AbortSignal,
): Promise<void> {
	if (subject.toolName !== "bash") return;

	const id = modelId();
	if (!id) return;

	try {
		const message = await completeSimple(
			classifierModel(id),
			{
				systemPrompt: SYSTEM_PROMPT,
				messages: [{ role: "user", content: userPrompt(subject), timestamp: Date.now() }],
			},
			{
				apiKey: process.env.PI_PERMISSIONS_CLASSIFIER_API_KEY ?? "sk-dummy",
				temperature: 0,
				maxTokens: 256,
				signal,
			},
		);

		if (message.stopReason === "error" || message.stopReason === "aborted") return;

		const text = message.content
			.filter((part): part is { type: "text"; text: string } => part.type === "text")
			.map((part) => part.text)
			.join("")
			.trim();

		const advice = text ? parseAdvice(text, id) : undefined;
		if (advice) subject.llmAdvice = { ...advice, baseUrl: baseUrl() };
	} catch {
		// Advisory only: classifier failures must never affect permission decisions.
	}
}
