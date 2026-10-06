import { closeSync, openSync, readFileSync, realpathSync } from "node:fs";
import { isAbsolute, relative, sep } from "node:path";

let fd;
try {
	const root = realpathSync(process.cwd());
	fd = openSync(process.argv[2], "r");
	// Check the opened file, not the requested path: ancestor symlinks can change
	// between path validation and open. Read from this same descriptor afterwards.
	const target = realpathSync(`/proc/self/fd/${fd}`);
	const path = relative(root, target);
	if (path === ".." || path.startsWith(`..${sep}`) || isAbsolute(path)) {
		process.exitCode = 1;
	} else {
		process.stdout.write(readFileSync(fd));
	}
} catch (error) {
	process.exitCode = error.code === "ENOENT" ? 44 : 1;
} finally {
	if (fd !== undefined) closeSync(fd);
}
