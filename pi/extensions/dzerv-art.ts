import type { Model } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PROVIDER_ID = "dzerv-art";
const PROVIDER_NAME = "dzerv.art";
const ROOT_BASE_URL = "https://ai.vpn.dzerv.art";
const OPENAI_BASE_URL = `${ROOT_BASE_URL}/v1`;
const DEFAULT_API_KEY = process.env.DZERV_ART_API_KEY ?? "sk-dummy";

const IGNORED_MODELS = new Set(["coder-model"]);
const ALIASES: Record<string, string[]> = {
	// "gpt-5-codex-mini": ["gpt-5-codex"],
};

interface GatewayModelsResponse {
	data: Array<{
		id: string;
		owned_by?: string;
	}>;
}

interface GeneratedModels {
	[provider: string]: Record<string, Model<any>>;
}

function providerRank(modelId: string, provider: string): number {
	if (modelId.startsWith("claude-")) {
		return provider === "anthropic" ? 0 : 100;
	}

	if (modelId.startsWith("gpt-")) {
		switch (provider) {
			case "openai":
				return 0;
			case "openai-codex":
				return 1;
			case "azure-openai-responses":
				return 2;
			default:
				return 100;
		}
	}

	if (modelId.startsWith("glm-")) {
		return provider === "zai" ? 0 : 100;
	}

	return 100;
}

function normalizeSourceId(id: string): string {
	return id.includes("/") ? id.slice(id.lastIndexOf("/") + 1) : id;
}

function sourceBaseUrl(model: Model<any>): string {
	return model.api === "anthropic-messages" ? ROOT_BASE_URL : OPENAI_BASE_URL;
}

async function loadGeneratedModels(): Promise<Model<any>[]> {
	const piAiEntry = import.meta.resolve("@mariozechner/pi-ai");
	const generatedModelsUrl = new URL("./models.generated.js", piAiEntry);
	const { MODELS } = (await import(generatedModelsUrl.href)) as { MODELS: GeneratedModels };
	return Object.values(MODELS).flatMap((providerModels) => Object.values(providerModels));
}

function pickModel(modelId: string, allModels: Model<any>[]): Model<any> | undefined {
	const ids = [modelId, ...(ALIASES[modelId] ?? [])];
	const candidates = ids.flatMap((id, aliasIndex) => {
		const exact = allModels
			.filter((model) => model.id === id)
			.map((model) => ({ model, score: aliasIndex * 1_000 + providerRank(modelId, model.provider) }));
		const normalized = allModels
			.filter((model) => normalizeSourceId(model.id) === id)
			.map((model) => ({ model, score: aliasIndex * 1_000 + 500 + providerRank(modelId, model.provider) }));
		return [...exact, ...normalized];
	});

	candidates.sort((a, b) => a.score - b.score);
	return candidates[0]?.model;
}

function toProviderModel(modelId: string, source: Model<any>) {
	return {
		id: modelId,
		name: source.name,
		api: source.api,
		baseUrl: sourceBaseUrl(source),
		reasoning: source.reasoning,
		thinkingLevelMap: source.thinkingLevelMap,
		input: source.input,
		cost: source.cost,
		contextWindow: source.contextWindow,
		maxTokens: source.maxTokens,
		compat: source.compat,
	};
}

export default async function (pi: ExtensionAPI) {
	const [allModels, response] = await Promise.all([
		loadGeneratedModels(),
		fetch(`${OPENAI_BASE_URL}/models`),
	]);

	if (!response.ok) {
		throw new Error(`Failed to fetch ${OPENAI_BASE_URL}/models: ${response.status} ${response.statusText}`);
	}

	const payload = (await response.json()) as GatewayModelsResponse;
	const missing: string[] = [];
	const models = payload.data
		.filter((model) => !IGNORED_MODELS.has(model.id))
		.map((model) => {
			const source = pickModel(model.id, allModels);
			if (!source) {
				missing.push(model.id);
				return undefined;
			}
			return toProviderModel(model.id, source);
		})
		.filter((model) => model !== undefined);

	// if (missing.length > 0) {
	// 	console.warn(`[${PROVIDER_ID}] skipped models missing from pi-ai/models.generated: ${missing.join(", ")}`);
	// }

	pi.registerProvider(PROVIDER_ID, {
		name: PROVIDER_NAME,
		baseUrl: OPENAI_BASE_URL,
		apiKey: DEFAULT_API_KEY,
		models,
	});
}
