import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { Model, OpenAICompletionsCompat } from "@earendil-works/pi-ai";

/**
 * llama-swap model provider.
 *
 * Registers llama-swap as an OpenAI-completions provider (the same API the
 * native llama.cpp provider uses) and discovers model metadata from
 * llama-swap's /v1/models, with local fallbacks for omitted capabilities.
 *
 * Configuration (env vars):
 *   LLAMA_SWAP_URL   - API base URL (default http://127.0.0.1:1337/v1)
 *   LLAMA_SWAP_API_KEY - API key forwarded to llama-swap (optional)
 *   ORNITH_TEMPERATURE - Per-request Ornith sampling override (optional)
 *
 * To expose a model's context length / modalities / thinking support, add a
 * `capabilities` block to the model in your llama-swap config, e.g.:
 *
 *   ornith:
 *     capabilities:
 *       in: [text, image]
 *       out: [text]
 *       context: 262144
 */

const DEFAULT_BASE_URL = process.env.LLAMA_SWAP_URL ?? "http://127.0.0.1:1337/v1";
const ORNITH_TEMPERATURE = parseOptionalNumber(process.env.ORNITH_TEMPERATURE);

// Maps pi thinking levels to values consumed by each model's compatibility
// format. Levels without a native distinction are clamped to the nearest one.
const THINKING_LEVEL_MAP = {
	off: "off",
	minimal: "low",
	low: "low",
	medium: "medium",
	high: "high",
	xhigh: "high",
};

// Qwen3.8 documents exactly three efforts: low, medium and xhigh. There is no
// "high", so pi's high is promoted rather than passed through unchanged.
const QWEN_THINKING_LEVEL_MAP = {
	off: "off",
	minimal: "low",
	low: "low",
	medium: "medium",
	high: "xhigh",
	xhigh: "xhigh",
};

const THINKING_LEVEL_MAPS: Record<string, typeof THINKING_LEVEL_MAP> = {
	qwen3: QWEN_THINKING_LEVEL_MAP,
};

// llama-swap does not report max_output_tokens, and pi's 8192 fallback is far
// below what a reasoning model needs: Qwen3.8 budgets reasoning separately from
// the response and its own SWE evaluations run at 32768. At 8192 the model
// exhausted the budget inside a single thinking block and never emitted a call.
const MODEL_MAX_OUTPUT_TOKENS: Record<string, number> = {
	qwen3: 32768,
};

// llama-swap never reports max_output_tokens, so pi's 8192 fallback applied to
// every local model. Reasoning models routinely exceed that inside one thinking
// block and get truncated with stopReason "length" before emitting a tool call.
const LLAMA_SWAP_MAX_OUTPUT_TOKENS = 32768;

// Unlike chat-template effort hints, llama.cpp's reasoning budget is enforced
// by the sampler: it closes the thinking block before max_tokens is exhausted.
const ORNITH_REASONING_BUDGETS: Record<string, number> = {
	low: 512,
	medium: 1024,
	high: 2048,
};

// Per-model-id compat overrides, matched by substring on the model id.
const MODEL_COMPAT: Record<string, OpenAICompletionsCompat> = {
	ornith: {
		thinkingFormat: "chat-template",
		chatTemplateKwargs: {
			enable_thinking: { $var: "thinking.enabled" },
			reasoning_effort: { $var: "thinking.effort" },
			preserve_thinking: true,
		},
	},
	// Qwen3.8 natively reads all three keys from its own chat template, so the
	// effort hint is a real control here rather than an inert argument.
	qwen3: {
		thinkingFormat: "chat-template",
		chatTemplateKwargs: {
			enable_thinking: { $var: "thinking.enabled" },
			reasoning_effort: { $var: "thinking.effort" },
			preserve_thinking: true,
		},
	},
};

// Fallback heuristic for thinking support when a model has no `capabilities`
// block. llama-swap currently omits configured capabilities from /v1/models.
const THINKING_HINTS = ["ornith", "qwen", "deepseek", "thought", "thinking", "qwq"];

interface LlamaSwapCapabilities {
	in?: string[];
	out?: string[];
	vision?: boolean;
	tools?: boolean;
	context?: number;
	context_length?: number;
	max_context?: number;
	max_context_length?: number;
	max_output_tokens?: number;
	thinking?: boolean;
	reasoning?: boolean;
}

interface LlamaSwapModel {
	id: string;
	object?: string;
	name?: string;
	description?: string;
	architecture?: {
		input_modalities?: string[];
		output_modalities?: string[];
	};
	capabilities?: LlamaSwapCapabilities;
	context_length?: number;
	max_output_tokens?: number;
	metadata?: Record<string, unknown>;
}

function nameSupportsThinking(id: string, name?: string): boolean {
	const haystack = `${id} ${name ?? ""}`.toLowerCase();
	return THINKING_HINTS.some((hint) => haystack.includes(hint));
}

function resolveContext(entry: LlamaSwapModel): number | undefined {
	const caps = entry.capabilities;
	return entry.context_length ?? caps?.context ?? caps?.context_length ?? caps?.max_context ?? caps?.max_context_length;
}

export default function (pi: ExtensionAPI) {
	const baseUrl = DEFAULT_BASE_URL.replace(/\/+$/, "");
	const apiKey = process.env.LLAMA_SWAP_API_KEY;
	const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : undefined;

	// Exact id, not a substring: these budgets were tuned against the 35B-A3B and
	// never demonstrably fixed its looping, so they must not leak onto ornith9.
	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== "llama-swap" || ctx.model.id.toLowerCase() !== "ornith") return;
		if (!isRecord(event.payload)) return;

		const payload = ORNITH_TEMPERATURE === undefined
			? event.payload
			: { ...event.payload, temperature: ORNITH_TEMPERATURE };
		const kwargs = isRecord(payload.chat_template_kwargs) ? payload.chat_template_kwargs : undefined;
		if (kwargs?.enable_thinking === false) return payload === event.payload ? undefined : payload;

		const effort = typeof kwargs?.reasoning_effort === "string" ? kwargs.reasoning_effort : "medium";
		const budget = ORNITH_REASONING_BUDGETS[effort] ?? ORNITH_REASONING_BUDGETS.medium;

		return { ...payload, thinking_budget_tokens: budget };
	});

	pi.registerProvider("llama-swap", {
		name: "llama-swap",
		baseUrl,
		...(apiKey ? { apiKey, authHeader: true } : {}),
		api: "openai-completions",
		async refreshModels({ signal }) {
			const response = await fetch(`${baseUrl}/models`, { signal, headers });
			if (!response.ok) {
				throw new Error(`llama-swap /models returned HTTP ${response.status}`);
			}
			const payload = (await response.json()) as { data?: LlamaSwapModel[] };
			const entries = payload.data ?? [];

			return entries.map((entry): Model<"openai-completions"> => {
				const caps = entry.capabilities;
				const inMods = entry.architecture?.input_modalities ?? caps?.in ?? [];
				const input: ("text" | "image")[] =
					inMods.includes("image") || caps?.vision === true ? ["text", "image"] : ["text"];

				const capsReasoning = caps?.thinking ?? caps?.reasoning;
				const reasoning = capsReasoning ?? nameSupportsThinking(entry.id, entry.name);

				const context = resolveContext(entry) ?? 128_000;
				const maxTokens =
					matchMaxOutputTokens(entry.id) ??
					entry.max_output_tokens ??
					caps?.max_output_tokens ??
					LLAMA_SWAP_MAX_OUTPUT_TOKENS;

				const compat = matchCompat(entry.id);

				const model: Model<"openai-completions"> = {
					id: entry.id,
					name: entry.name ?? entry.id,
					provider: "llama-swap",
					api: "openai-completions",
					baseUrl,
					reasoning,
					input,
					cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
					contextWindow: context,
					maxTokens,
					...(compat ? { compat } : {}),
					...(reasoning ? { thinkingLevelMap: matchThinkingLevelMap(entry.id) } : {}),
				};
				return model;
			});
		},
	});
}

function matchMaxOutputTokens(id: string): number | undefined {
	const normalizedId = id.toLowerCase();
	for (const [key, value] of Object.entries(MODEL_MAX_OUTPUT_TOKENS)) {
		if (normalizedId.includes(key)) return value;
	}
	return undefined;
}

function matchThinkingLevelMap(id: string): typeof THINKING_LEVEL_MAP {
	const normalizedId = id.toLowerCase();
	for (const [key, map] of Object.entries(THINKING_LEVEL_MAPS)) {
		if (normalizedId.includes(key)) return map;
	}
	return THINKING_LEVEL_MAP;
}

function matchCompat(id: string): OpenAICompletionsCompat | undefined {
	const normalizedId = id.toLowerCase();
	const match = Object.entries(MODEL_COMPAT).find(([key]) => normalizedId.includes(key));
	return match?.[1];
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseOptionalNumber(value: string | undefined): number | undefined {
	if (value === undefined) return undefined;
	const parsed = Number(value);
	if (!Number.isFinite(parsed) || parsed < 0) throw new Error(`Invalid ORNITH_TEMPERATURE: ${value}`);
	return parsed;
}
