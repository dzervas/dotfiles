// Reuse Pi's Atuin storage format, namespaces and sync gate so both harnesses
// see the same learned notes without copying them into a second memory system.
import { execFile } from "node:child_process";
import { agentProfile, applyChange, memoryNamespace, readNotes, syncIfDue, type Runner } from "../../../pi/extensions/memory/atuin.ts";
import { formatNotes, indexLimitError, planChange, sortNotes, type Action, type Note, type Scope } from "../../../pi/extensions/memory/store.ts";

export const scopes = ["global", "project"] as const;
export type MemoryData = Partial<Record<Scope, { namespace: string; notes: Note[] }>>;
export type ReadResult = { data: MemoryData; warning?: string };
export type WriteResult = ReadResult & { changed: boolean; indexError?: string; error?: string };
export type Backend = {
  namespace(scope: Scope, signal?: AbortSignal): Promise<string>;
  read(selected: readonly Scope[], signal?: AbortSignal): Promise<ReadResult>;
  mutate(scope: Scope, action: Exclude<Action, "list">, text?: string, previous?: string, signal?: AbortSignal): Promise<WriteResult>;
};
type Transport = {
  runner(signal?: AbortSignal): Runner;
  sync(signal?: AbortSignal): Promise<string | undefined>;
};

function transport(cwd: string): Transport {
  agentProfile();
  const runner = (signal?: AbortSignal, timeout = 5_000): Runner => (command, args) => new Promise((resolve, reject) => {
    execFile(command, args, { cwd, signal, timeout, maxBuffer: 5 * 1024 * 1024 }, (error, stdout, stderr) => {
      if (signal?.aborted) return reject(signal.reason);
      resolve({ code: error ? typeof error.code === "number" ? error.code : 1 : 0, stdout, stderr: stderr || error?.message });
    });
  });
  return { runner, sync: (signal) => syncIfDue(runner(signal, 20_000)) };
}

export function createAtuinBackend(cwd: string, io: Transport = transport(cwd), projectNamespace = process.env.OPENCODE_MEMORY_PROJECT_NAMESPACE): Backend {
  let access: Promise<unknown> = Promise.resolve();
  const serial = <T>(work: () => Promise<T>): Promise<T> => {
    const pending = access.then(work, work);
    access = pending.catch(() => {});
    return pending;
  };
  const namespaces = new Map<Scope, Promise<string>>();
  const namespace = (scope: Scope, signal?: AbortSignal) => {
    let pending = namespaces.get(scope);
    if (!pending) {
      // The trusted launcher preserves repository identity without mounting
      // ancestor Git metadata into a subdirectory/worktree sandbox.
      pending = scope === "project" && projectNamespace
        ? Promise.resolve(projectNamespace)
        : memoryNamespace(io.runner(signal), scope, cwd);
      namespaces.set(scope, pending);
      void pending.catch(() => { if (namespaces.get(scope) === pending) namespaces.delete(scope); });
    }
    return pending;
  };

  return {
    namespace,
    read: (selected, signal) => serial(async () => {
      const warning = await io.sync(signal);
      const data: MemoryData = {};
      for (const scope of selected) {
        const ns = await namespace(scope, signal);
        data[scope] = { namespace: ns, notes: await readNotes(io.runner(signal), ns) };
      }
      return { data, warning };
    }),
    mutate: (scope, action, text, previous, signal) => serial(async () => {
      const warning = await io.sync(signal);
      const ns = await namespace(scope, signal);
      const run = io.runner(signal);
      const before = await readNotes(run, ns);
      const change = planChange(before, action, text, previous);
      const changed = Boolean(change.add || change.remove);
      if (changed) {
        try {
          await applyChange(run, ns, change);
        } catch (error) {
          // Replacements save before deleting: a failed operation may have
          // persisted part of its change. Never invite a blind retry.
          const actual = await readNotes(run, ns).catch(() => undefined);
          return {
            data: actual ? { [scope]: { namespace: ns, notes: actual } } : {},
            changed,
            warning,
            error: `Memory update may have partially succeeded. List current notes before retrying: ${String(error)}`,
          };
        }
      }
      let notes = before;
      let refreshWarning: string | undefined;
      if (changed) {
        try {
          notes = await readNotes(run, ns);
        } catch {
          notes = sortNotes([
            ...before.filter((note) => note.text !== change.remove),
            ...(change.add ? [change.add] : []),
          ]);
          refreshWarning = "Memory saved, but refreshing the store failed; the next access will retry.";
        }
      }
      return {
        data: { [scope]: { namespace: ns, notes } },
        changed,
        warning: [warning, refreshWarning].filter(Boolean).join("\n") || undefined,
        indexError: indexLimitError(notes),
      };
    }),
  };
}

export function describe(data: MemoryData): string {
  return scopes.flatMap((scope) => {
    const value = data[scope];
    return value ? [`${scope} memory (${value.namespace})\n${value.notes.length ? formatNotes(value.notes) : "No notes."}`] : [];
  }).join("\n\n");
}
