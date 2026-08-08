/**
 * Disables the extra readSeek_* tools (search, def, refs, hover, rename, check, view).
 * The readseek-backed read/edit/write/grep replacements stay active.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const EXTRAS = new Set([
	"readSeek_search",
	"readSeek_def",
	"readSeek_refs",
	"readSeek_hover",
	"readSeek_rename",
	"readSeek_check",
	"readSeek_view",
]);

export default function (pi: ExtensionAPI) {
	// pi-readseek activates its tools during session_start. resources_discover runs
	// afterward, so filtering here cannot be undone by its startup handler.
	pi.on("resources_discover", () => {
		pi.setActiveTools(pi.getActiveTools().filter((name) => !EXTRAS.has(name)));
	});
}
