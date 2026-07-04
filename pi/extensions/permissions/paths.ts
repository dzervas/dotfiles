// Filesystem path helpers: normalization, containment checks, PathRef creation.

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { PathRef } from "./types";

export function resolvePath(target: string) {
	const expanded =
		target === "~"
			? os.homedir()
			: target.startsWith("~/")
				? path.join(os.homedir(), target.slice(2))
				: target;
	const absolute = path.isAbsolute(expanded) ? expanded : path.resolve(process.cwd(), expanded);
	try {
		return fs.realpathSync.native(path.normalize(absolute));
	} catch {
		return path.normalize(absolute);
	}
}

export const CWD = resolvePath(process.cwd());

export function inside(target: string, root: string) {
	const relative = path.relative(root, target);
	return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

export function pushPath(paths: PathRef[], raw: string, access: PathRef["access"]) {
	paths.push({ raw, access, resolved: resolvePath(raw) });
}

// The root to whitelist when the user saves a path-based allow rule.
export function savePathRoot(resolved: string) {
	try {
		return fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);
	} catch {
		return path.dirname(resolved);
	}
}
