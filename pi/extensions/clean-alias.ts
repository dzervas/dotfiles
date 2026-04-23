import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("clear", {
		description: "Alias for /new",
		handler: async (_args, ctx) => {
			await ctx.newSession();
		},
	});
}
