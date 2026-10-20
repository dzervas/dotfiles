// Backend-only learned memory: the sandbox launcher loads this package, while
// the ordinary Desktop server and its GUI extension remain unchanged.
import { Plugin } from "@opencode/plugin";
import { Schema } from "effect";
import { getPrompt } from "../../../pi/extensions/lib/prompts.ts";
import { createAtuinBackend } from "./backend.ts";
import { createMemoryManager } from "./manager.ts";

const Scope = Schema.Literals(["global", "project"]);
const Memory = Schema.Struct({
  action: Schema.Literals(["list", "remember", "replace", "forget"]),
  scope: Schema.optional(Scope),
  text: Schema.optional(Schema.String.annotate({ description: getPrompt("memory", "parameter-text") })),
  previous: Schema.optional(Schema.String.annotate({ description: getPrompt("memory", "parameter-previous") })),
});
const Search = Schema.Struct({ query: Schema.String, scope: Schema.optional(Scope) });

export default Plugin.define({
  id: "dotfiles.memory",
  async setup(ctx) {
    const manager = createMemoryManager(ctx, createAtuinBackend);
    await ctx.tool.transform((editor) => {
      editor.add({
        name: "memory",
        description: getPrompt("memory", "description"),
        options: { codemode: true, pinned: true },
        input: Memory,
        execute: async (input, call) => {
          // Durable preferences are edits even though they are not workspace
          // files. Native Plan/read-only edit policies must still apply.
          const resource = `memory:${input.scope ?? "project"}`;
          await ctx.permission.assert({
            action: input.action === "list" ? "read" : "edit",
            resources: [resource], save: [resource],
            sessionID: call.sessionID, agent: call.agent,
            source: { type: "tool", messageID: call.messageID, id: call.id },
          });
          return { content: await manager.memory(input, call.sessionID, call.signal) };
        },
      });
      editor.add({
        name: "memory_search",
        description: getPrompt("memory", "search-description"),
        options: { codemode: true, pinned: true },
        input: Search,
        execute: async (input, call) => {
          const resource = `memory:${input.scope ?? "*"}`;
          await ctx.permission.assert({
            action: "read", resources: [resource], save: [resource],
            sessionID: call.sessionID, agent: call.agent,
            source: { type: "tool", messageID: call.messageID, id: call.id },
          });
          return { content: await manager.search(input.query, input.scope, call.sessionID, call.signal) };
        },
      });
    });
    await ctx.session.hook("context", async (event) => {
      event.system.push({ type: "text", text: await manager.context(event.sessionID) });
    });
    const timer = setInterval(() => { void manager.poll().catch(() => {}); }, 30_000);
    timer.unref?.();
    return () => { clearInterval(timer); manager.close(); };
  },
});
