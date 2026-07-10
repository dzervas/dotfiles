/**
 * https://github.com/gotgenes/pi-packages/blob/main/packages/pi-nocd/src/index.ts
 * pi-nocd — Inject the resolved working directory into the system prompt.
 *
 * Hooks `before_agent_start` and appends a block forbidding `cd`-into-cwd
 * command prefixes. Pi's prompt already states the resolved CWD (a
 * `Current working directory: <path>` footer that survives downstream shaping),
 * but ships no instruction against `cd`-prefixing it. This adds that rule to
 * defeat the habit of prefixing commands with `cd $(pwd) &&`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Marker used to detect and avoid double-appending the block. */
export const WORKING_DIRECTORY_HEADING = "# Working Directory";

/**
 * Build the instruction block for a given resolved working directory.
 *
 * @param cwd - The resolved current working directory (e.g. `ctx.cwd`).
 * @returns A markdown block naming the literal path and forbidding `cd`-into-cwd.
 */
function buildWorkingDirectoryPrompt(cwd: string): string {
  return [
    WORKING_DIRECTORY_HEADING,
    "",
    `Shell commands already execute in \`${cwd}\`. ` +
      "Never prefix a command with `cd` into the current working directory — " +
      `neither \`cd ${cwd} &&\` nor \`cd $(pwd) &&\`. ` +
      "Just run the command directly.",
  ].join("\n");
}

/**
 * Append the working-directory block to an existing system prompt.
 *
 * Idempotent: if the block's heading is already present, the prompt is returned
 * unchanged so chained `before_agent_start` handlers do not stack duplicates.
 *
 * @param systemPrompt - The fully assembled system prompt.
 * @param cwd - The resolved current working directory.
 * @returns The system prompt with the working-directory block appended.
 */
function appendWorkingDirectoryPrompt(
  systemPrompt: string,
  cwd: string,
): string {
  if (systemPrompt.includes(WORKING_DIRECTORY_HEADING)) {
    return systemPrompt;
  }
  return `${systemPrompt}\n\n${buildWorkingDirectoryPrompt(cwd)}`;
}

export default function piNocd(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event, ctx) => ({
    systemPrompt: appendWorkingDirectoryPrompt(event.systemPrompt, ctx.cwd),
  }));
}
