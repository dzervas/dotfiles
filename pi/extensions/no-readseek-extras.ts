/**
 * Disables the extra readSeek_* tools (search, def, refs, hover, rename, check, view).
 * The readseek-backed read/edit/write/grep replacements stay active.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", () => {
		pi.setActiveTools(pi.getActiveTools().filter((name) => !name.startsWith("readSeek_")));
	});
}
