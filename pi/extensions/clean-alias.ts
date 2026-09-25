import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
	let pendingPrompt: string | undefined;

	pi.registerCommand("clear", {
		description: "Alias for /new; optionally start the new session with a prompt",
		handler: async (args, ctx) => {
			const prompt = pendingPrompt ?? args;
			const model = ctx.model && { provider: ctx.model.provider, id: ctx.model.id };
			pendingPrompt = undefined;
			await ctx.newSession({
				withSession: async (fresh) => {
					// Only the new session's extension API can change its model. Dispatch
					// a command there before sending the first prompt.
					if (model && (fresh.model?.provider !== model.provider || fresh.model.id !== model.id)) {
						await fresh.sendUserMessage(`/clear-select-model ${JSON.stringify(model)}`, {
							expandPromptTemplates: true,
						});
						if (fresh.model?.provider !== model.provider || fresh.model.id !== model.id) {
							throw new Error(`Could not restore model ${model.provider}/${model.id}`);
						}
					}
					if (prompt.trim()) await fresh.sendUserMessage(prompt);
				},
			});
		},
	});

	pi.registerCommand("clear-select-model", {
		description: "Restore the model after /clear",
		handler: async (args, ctx) => {
			const { provider, id } = JSON.parse(args) as { provider: string; id: string };
			const model = ctx.modelRegistry.find(provider, id);
			if (!model || !(await pi.setModel(model))) throw new Error(`Could not select model ${provider}/${id}`);
		},
	});

	pi.registerTool({
		name: "clear",
		label: "Clear",
		description: "End this session and start a fresh one, optionally sending a prompt to the new session. Use when the current conversation context should be discarded.",
		parameters: Type.Object({
			prompt: Type.Optional(Type.String({ description: "Prompt to send in the fresh session" })),
		}),
		async execute(_toolCallId, { prompt }) {
			if (pendingPrompt !== undefined) throw new Error("A session clear is already pending");
			pendingPrompt = prompt ?? "";
			return {
				content: [{ type: "text", text: "Starting a fresh session after this turn." }],
				details: undefined,
				terminate: true,
			};
		},
	});

	// Session replacement is command-only; wait until the tool's turn has settled
	// before dispatching /clear through its command context.
	pi.on("agent_settled", () => {
		if (pendingPrompt !== undefined) {
			pi.sendUserMessage("/clear", { expandPromptTemplates: true });
		}
	});
}
