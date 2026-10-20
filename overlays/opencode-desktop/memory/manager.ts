// OpenCode hosts many conversations in one backend. Persist immutable prompt
// snapshots per session/project, and deliver live changes as passive input—not
// changing the system prefix or starting another model turn.
import { createHash } from "node:crypto";
import type { Plugin } from "@opencode/plugin";
import { getPrompt } from "../../../pi/extensions/lib/prompts.ts";
import { diffNotes, formatNotes, formatStartupNotes, searchNotes, type Action, type Scope } from "../../../pi/extensions/memory/store.ts";
import { describe, scopes, type Backend, type MemoryData } from "./backend.ts";

type Value = NonNullable<MemoryData[Scope]>;
type Notes = Record<Scope, Value>;
type Snapshot = { version: 1; text: string; initial: Notes; baseline: Notes };
type SessionID = Parameters<Plugin.Context["session"]["get"]>[0]["sessionID"];
type State = { id: SessionID; key: string; backend: Backend; record: Snapshot; notify: boolean };
export type MemoryInput = { action: Action; scope?: Scope; text?: string; previous?: string };
type Host = Pick<Plugin.Context, "session" | "storage">;

export function snapshotKey(namespace: string, sessionID: string): string {
  const project = createHash("sha256").update(namespace).digest("hex").slice(0, 16);
  return `snapshot/v1/${project}/${sessionID}`;
}

function snapshot(value: unknown): Snapshot | undefined {
  if (value === undefined) return;
  const record = value as Snapshot;
  if (record?.version !== 1 || typeof record.text !== "string" || !record.initial || !record.baseline) {
    throw new Error("Unsupported learned-memory session snapshot");
  }
  return structuredClone(record);
}

export function createMemoryManager(ctx: Host, backendForDirectory: (cwd: string) => Backend) {
  const lifetime = new AbortController();
  const states = new Map<string, State>();
  const initializing = new Map<string, Promise<State>>();
  const backends = new Map<string, Backend>();
  let pending: Promise<unknown> = Promise.resolve();
  const serial = <T>(work: () => Promise<T>): Promise<T> => {
    const result = pending.then(work, work);
    pending = result.catch(() => {});
    return result;
  };
  const signal = (caller?: AbortSignal) => AbortSignal.any([
    lifetime.signal, AbortSignal.timeout(20_000), ...(caller ? [caller] : []),
  ]);
  const persist = (key: string, record: Snapshot) => ctx.storage.set(key, record);

  async function stateFor(sessionID: SessionID): Promise<State> {
    lifetime.signal.throwIfAborted();
    const info = await ctx.session.get({ sessionID });
    const directory = info.location.directory;
    let backend = backends.get(directory);
    if (!backend) {
      backend = backendForDirectory(directory);
      backends.set(directory, backend);
    }
    const project = await backend.namespace("project", signal());
    const key = snapshotKey(project, sessionID);
    const existing = states.get(sessionID);
    if (existing?.key === key) return existing;
    let initial = initializing.get(key);
    if (!initial) {
      const selected = backend;
      initial = (async () => {
        let record = snapshot(await ctx.storage.get(key));
        if (!record && info.fork) {
          const source = snapshot(await ctx.storage.get(snapshotKey(project, info.fork.sessionID)));
          if (source) {
            // A fork may precede the parent's live notices. Starting observation
            // at the frozen notes guarantees later changes aren't silently lost.
            record = { ...source, baseline: structuredClone(source.initial) };
          }
        }
        if (!record) {
          const empty: Notes = {
            global: { namespace: await selected.namespace("global", signal()), notes: [] },
            project: { namespace: project, notes: [] },
          };
          let notes = empty;
          let text = "";
          try {
            const loaded = await selected.read(scopes, signal());
            notes = { ...empty, ...loaded.data };
            text = scopes.flatMap((scope) => notes[scope].notes.length ? [getPrompt("memory", "startup-section", {
              scope, namespace: notes[scope].namespace, notes: formatStartupNotes(notes[scope].notes),
            })] : []).join("\n\n");
          } catch {
            lifetime.signal.throwIfAborted();
            // Don't prevent coding when Atuin is offline. Freeze the failure
            // too; tools/polling can recover without replacing this prefix.
            text = "Learned memory was unavailable at this session's first request. Memory tools can retry.";
          }
          record = { version: 1, text, initial: structuredClone(notes), baseline: structuredClone(notes) };
        }
        lifetime.signal.throwIfAborted();
        await persist(key, record);
        const state = { id: sessionID, key, backend: selected, record, notify: !info.parentID };
        states.set(sessionID, state);
        return state;
      })();
      initializing.set(key, initial);
      void initial.finally(() => initializing.delete(key)).catch(() => {});
    }
    return initial;
  }

  async function observe(data: MemoryData, origin?: SessionID) {
    const acknowledged: string[] = [];
    for (const state of states.values()) {
      lifetime.signal.throwIfAborted();
      const next = structuredClone(state.record);
      const sections: string[] = [];
      let changed = false;
      for (const scope of scopes) {
        const value = data[scope];
        const before = next.baseline[scope];
        if (!value || value.namespace !== before.namespace) continue;
        const diff = diffNotes(before.notes, value.notes);
        if (!diff) continue;
        changed = true;
        const section = getPrompt("memory", "changed-section", { scope, namespace: value.namespace, diff });
        // A mutation can discover external edits too. Its origin needs those
        // differences in the tool result, even though it doesn't need a notice.
        if (state.id === origin) acknowledged.push(section);
        else if (state.notify) sections.push(section);
        next.baseline[scope] = structuredClone(value);
      }
      if (!changed) continue;
      try {
        if (sections.length) {
          // Native synthetic input is durable and admitted at session boundaries.
          // resume:false is essential: a memory refresh must not wake an agent.
          await ctx.session.synthetic({
            sessionID: state.id,
            text: getPrompt("memory", "changed-notice", { changes: sections.join("\n\n") }),
            description: "Learned memory updated",
            metadata: { source: "dotfiles.memory" },
            resume: false,
          });
        }
        lifetime.signal.throwIfAborted();
        await persist(state.key, next);
        state.record = next;
      } catch (error) {
        lifetime.signal.throwIfAborted();
        // A deleted/busy session must not block other conversations or make an
        // already persisted Atuin write appear unsuccessful. Retry transient
        // failures with the old baseline; stop observing deleted sessions.
        if ((error as { _tag?: string })?._tag === "Session.NotFoundError") states.delete(state.id);
      }
    }
    return acknowledged.length ? getPrompt("memory", "changed-notice", { changes: acknowledged.join("\n\n") }) : "";
  }

  return {
    async context(sessionID: SessionID): Promise<string> {
      const state = await stateFor(sessionID);
      return getPrompt("memory", "system-context", {
        guidance: getPrompt("memory", "guidance"), notes: state.record.text,
      });
    },
    memory(input: MemoryInput, sessionID: SessionID, caller?: AbortSignal): Promise<string> {
      return serial(async () => {
        const state = await stateFor(sessionID);
        const scope = input.scope ?? "project";
        if (input.action === "list") {
          const result = await state.backend.read([scope], signal(caller));
          return describe(result.data) + (result.warning ? `\n${result.warning}` : "");
        }
        const result = await state.backend.mutate(scope, input.action, input.text, input.previous, signal(caller));
        const acknowledged = await observe(result.data, sessionID);
        if (result.error) throw new Error([result.error, acknowledged].filter(Boolean).join("\n\n"));
        const value = result.data[scope]!;
        const message = `${scope} memory ${result.changed ? "saved" : "unchanged"} (${value.namespace}); ${value.notes.length} notes.`;
        if (result.indexError) throw new Error([`${message} ${result.changed ? "Write succeeded. " : ""}${result.indexError}`, acknowledged].filter(Boolean).join("\n\n"));
        return [message, result.warning, acknowledged].filter(Boolean).join("\n\n");
      });
    },
    search(query: string, scope: Scope | undefined, sessionID: SessionID, caller?: AbortSignal): Promise<string> {
      return serial(async () => {
        const state = await stateFor(sessionID);
        const result = await state.backend.read(scope ? [scope] : scopes, signal(caller));
        const sections = scopes.flatMap((selected) => {
          const value = result.data[selected];
          if (!value) return [];
          const matches = searchNotes(value.notes, query);
          return matches.length ? [`${selected}:\n${formatNotes(matches)}`] : [];
        });
        return (sections.join("\n\n") || "No matching notes.") + (result.warning ? `\n${result.warning}` : "");
      });
    },
    poll(): Promise<void> {
      return serial(async () => {
        const seen = new Set<string>();
        for (const state of states.values()) {
          const project = state.record.initial.project.namespace;
          if (!state.notify || seen.has(project)) continue;
          seen.add(project);
          const result = await state.backend.read(scopes, signal());
          await observe(result.data);
        }
      });
    },
    close() { lifetime.abort(); states.clear(); },
  };
}
