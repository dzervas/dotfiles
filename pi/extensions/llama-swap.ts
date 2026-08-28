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
	// qwen3 in this repo runs with `--reasoning-format deepseek`.
	qwen3: { thinkingFormat: "deepseek" },
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
				const maxTokens = entry.max_output_tokens ?? caps?.max_output_tokens ?? 8192;

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
					...(reasoning ? { thinkingLevelMap: THINKING_LEVEL_MAP } : {}),
				};
				return model;
			});
		},
	});
}

function matchCompat(id: string): OpenAICompletionsCompat | undefined {
	const normalizedId = id.toLowerCase();
	const match = Object.entries(MODEL_COMPAT).find(([key]) => normalizedId.includes(key));
	return match?.[1];
}
