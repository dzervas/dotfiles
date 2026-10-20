// Upstream has no installable GUI-renderer extension surface yet. Register our
// files as built-ins at build time, failing on upstream drift instead of keeping
// a line-number-sensitive patch or weakening packaged extension security.
import { createHash } from "node:crypto";
import { chmod, cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export function register(source, kind) {
  if (source.includes('from "./sandbox/index.js"')) throw new Error("Sandbox extension is already registered");
  const anchor = "export const builtins = Extension.compose(\n";
  if (source.split(anchor).length !== 2) throw new Error(`Expected exactly one ${kind} built-in registry`);
  let imports = 'import sandbox from "./sandbox/index.js"\n';
  let entry = '{ ...sandbox, main: () => import("./sandbox/main.js") },';
  if (kind === "renderer") {
    if (!source.includes("const eager = ")) throw new Error("Upstream renderer setup helper changed");
    imports += 'import sandboxRenderer from "./sandbox/renderer.js"\n';
    entry = "{ ...sandbox, renderer: eager(sandboxRenderer) },";
  }
  return imports + source.replace(anchor, `${anchor}  ${entry}\n`);
}

export function stageCli(source, cli) {
  // Version-only staging otherwise reuses a stale executable after a Nix
  // rebuild. The immutable CLI store path identifies the actual build.
  const anchor = 'const stage = `${version}-${process.arch}`';
  if (source.split(anchor).length !== 2) throw new Error("Expected exactly one CLI staging key");
  const identity = createHash("sha256").update(cli).digest("hex").slice(0, 16);
  return source.replace(anchor, 'const stage = `${version}-${process.arch}-' + identity + '`');
}

export async function inject(root, extension, launcher, cli) {
  const directory = join(root, "packages/gui-extensions/src");
  const changes = await Promise.all(["main", "renderer"].map(async (kind) => {
    const path = join(directory, `${kind}.ts`);
    return { path, content: register(await readFile(path, "utf8"), kind) };
  }));
  const staging = join(root, "packages/desktop/src/main/service/desktop-cli.ts");
  changes.push({ path: staging, content: stageCli(await readFile(staging, "utf8"), cli) });
  const main = await readFile(join(extension, "main.js"), "utf8");
  if (main.split("@launcher@").length !== 2) throw new Error("Expected exactly one sandbox launcher placeholder");

  const destination = join(directory, "sandbox");
  await mkdir(dirname(destination), { recursive: true });
  await cp(extension, destination, { recursive: true });
  await chmod(join(destination, "main.js"), 0o644);
  await writeFile(join(destination, "main.js"), main.replace('"@launcher@"', JSON.stringify(launcher)));
  for (const { path, content } of changes) await writeFile(path, content);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 6) throw new Error("Expected source root, extension directory, sandbox launcher and CLI");
  await inject(...process.argv.slice(2));
}
