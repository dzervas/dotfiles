import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("clear", {
		description: "Alias for /new",
		handler: async (_args, ctx) => {
			await ctx.newSession();
		},
	});
}
