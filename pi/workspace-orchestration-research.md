# JJ workspace orchestration in Pi and Pi Durable

Research date: 2026-10-02. Durable source checked at `v1.0.0`; JJ command behavior checked against the installed `jj 0.45.1`. This document captures findings and a proposed implementation plan. No workspace manager or orchestration extension has been implemented by this research.

## Recommendation

Keep workspace ownership and coordination inside the agent harness, rather than coordinating independent Pi processes through filesystem scans, PID polling or ad-hoc messaging.

There are two viable implementations:

- **Normal Pi:** a small extension/adaptor around an existing in-process subagent runner. Best fit for retaining the current CLI and conveniences.
- **Pi Durable:** a Durable extension loaded by one Harness, plus a small host execution-environment resolver. Best fit when jobs, assignments and completion reporting need checkpointed recovery across restarts.

Ordinary Pi extensions and Durable extensions use different APIs. A normal Pi extension does not automatically become a Durable extension. Durable's SDK is explicitly experimental: its README says, “The API changes without notice between releases.”

## Verified findings

### JJ workspaces

A JJ workspace is a separate checkout with its own working-copy change, sharing repository storage and history with the other workspaces. No per-agent bookmark is required. `@` means the current workspace's change; `agent-a@` addresses another named workspace's working-copy change.

`jj workspace add -r BASE PATH` creates a new working-copy change with BASE as its parent. Without `-r`, the new workspace shares the current working copy's parents, which can exclude changes currently held in `@`.

Use a fixed starting snapshot that the coordinator stops editing. Capturing its commit ID alone does not prevent JJ from rebasing descendants if that ancestor is later rewritten. Move the coordinator onto a separate child before dispatching workers and avoid rewriting the common base while they run.

Checkout isolation does not isolate repository-wide operations. Rebases, ancestor rewrites and operation restores can affect other workspaces. Shared services and global configuration also remain shared.

A workspace under `.pi/workspace/<name>` is a reasonable layout, provided the whole workspace directory is ignored by the outer checkout. Keep the name associated with a specific job and avoid reuse while a previous job still owns it.

### Current normal-Pi integration points

Local configuration retains `@gotgenes/pi-subagents@21.8.0`. The full runner dispatch/lifecycle API was not audited in this research; the ability to set each child's real `cwd` and observe its lifecycle is an implementation prerequisite, not an established API guarantee.

The current [`jj-undo`](extensions/jj-undo.ts) extension reads a process-global Gotgenes service and calls `hasRunning()`. This is an existing coordination point, but it is not a complete cross-workspace ownership registry.

`jj-undo` uses `jj op restore`, which restores repository-wide operation state. Its running-subagent guard does not establish that completed work has been integrated, or account for independent Pi processes. A workspace workflow must protect outstanding worker results from this restore too.

Automatic JJ snapshots in `jj-undo` are restricted to TUI sessions. Headless worker snapshots therefore need an explicit lifecycle policy. The existing parent-only behavior should not be mistaken for automatic worker handoff snapshots.

Other workspace-readiness details to audit:

- Every file/tool/subprocess operation must use the worker's actual workspace directory. Current permission path resolution and configuration defaults refer to `process.cwd()` in places; changing only a session's `ctx.cwd` is insufficient without checking those paths.
- [`jj-footer`](extensions/jj-footer.ts) invokes `pi.exec` without an explicit `cwd`; this pattern needs review wherever a UI-bearing session can use a different directory.
- [`home/ai.nix`](../home/ai.nix) points global Pi extensions and skills at the original dotfiles checkout. Starting Pi from a secondary workspace does not make those global symlinks point at that workspace's edited extensions.
- [`sand.fish`](../home/fish-functions/sand.fish) primarily binds the selected project directory. A secondary JJ workspace also needs access to its shared JJ/Git metadata paths. Determine the precise paths before granting access; other agents' source checkouts need not be exposed merely to make JJ work.

These observations identify relevant integration requirements. No changes to these existing components are proposed as part of writing this note.

### Durable SDK

Durable provides a process-owned extension registry, concurrent conversations, persisted documents, task ownership, checkpointed tasks and committed views.

An extension can bundle `tools`, prompt `sections`, `hooks`, `wraps` and `tasks`. The host installs it in a registry; conversations select extensions/tools by name. A task-owned child conversation starts with its owner's agent configuration, which can then be overridden, including its working directory and offered tools.

Upstream examples demonstrate the relevant pieces:

- [23-subagent-background.ts](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/23-subagent-background.ts): persistent background subagents with spawn/send/stop/status, durable assignment records, steering/follow-ups and completion reporters. Request IDs prevent duplicate submissions/reports after recovery.
- [29-sandbox-per-conversation.ts](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/29-sandbox-per-conversation.ts): a per-conversation document stores an assigned path, and the host's `env` function reads it to construct the tool execution environment. Its directory-based example demonstrates routing, not OS security containment.
- [11-extension-state.ts](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/11-extension-state.ts): extension tools update documents in commits, and prompt sections read committed state.
- [24-child-tasks.ts](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/24-child-tasks.ts): ownership, cancellation, child completion and restart behavior.

`harness.taskGraph()` reports live tasks and their ownership/waiting state. Terminal tasks disappear from that graph, so completed results and final revision references belong in a separate durable job document.

The execution-environment factory belongs to `Harness.open(...)`; it is not a field on `defineExtension(...)`. Consequently, orchestration can live mostly in an extension, but the host must wire its workspace document into the environment resolver.

The UI attaches to committed conversation/task views. A child can run without a viewer; the UI can later attach, switch to it or steer it. Separate UI clients remain possible without turning every agent into a separate Pi process.

The bundled Durable coding TUI is a minimal example. Its [README](https://github.com/earendil-works/pi/blob/v1.0.0/packages/coding-agent/src/experimental/durable/README.md) lists ordinary extension loading, images and several session-navigation features as missing. Existing Pi CLI UI methods and permission dialogs are not automatically available through the Durable SDK.

## Common design

### Ownership and status

Associate each managed editing job with its assignment, child identity, workspace name/path, starting revision and final revision. Store enough information to explain who owns the work; do not make the model infer ownership from relative paths such as `../../`.

Runner state and JJ state must remain distinct:

- The runner tells whether a child is working, waiting, failed or finished.
- JJ tells what its last snapshot contains, which paths changed and whether there are conflicts.
- A finished child can still have work awaiting review/integration.

A compact `workspace_status` tool should join those views. Return assignment, workspace, runner state, last snapshot, changed-file summary, conflicts and integration state. Report validation as worker-reported unless the host actually recorded the checks and their revision.

Observe other workspaces using `--ignore-working-copy`. Do not silently snapshot an actively writing worker from a coordinator polling loop. Have each worker snapshot its own checkout at quiescent checkpoints and before publishing a result. Explicitly label observer results as the last snapshot; they may omit subsequent unsnapshotted edits.

Give agents stable ownership guidance and include the actual workspace in dispatch results. Prefer querying changing coordination state through the status tool over rebuilding a large, changing system-prompt inventory every request.

### Integration

One coordinator owns integration, ancestor rewrites, bookmarks and repository-wide undo. Workers edit/test their assigned checkout and hand back a concrete revision plus a concise result.

Wait until workers stop editing before consuming live workspace-head references, or use fixed handoff commit IDs. Review each result, create the integration change from the desired parent revisions, resolve conflicts and validate the combined behavior. A clean textual merge is not proof that independently changed interfaces still agree.

Retain failed/cancelled workspaces for review by default. Cleanup is a separate deliberate step; a cancelled model run does not mean its partial edits are disposable.

### Boundaries

Different working directories prevent ordinary checkout collisions. They do not enforce filesystem access boundaries. Tool execution must use a properly constrained environment if agents should be unable to read/write neighboring checkouts or host configuration.

JJ metadata/history remain shared even with sandboxed checkouts. Treat repository-wide operations as coordinated operations, not as private worker actions.

## Case A: normal Pi extension

Implement workspace isolation at the existing subagent dispatch boundary rather than introduce a second scheduler.

1. Verify the runner's child-directory and lifecycle interfaces. Keep its existing message, cancellation and result delivery mechanisms.
2. On dispatch of editing work, prepare a fixed base, create a workspace and bind its absolute directory to the child session and tool execution context. Read-only research need not allocate a workspace if it remains genuinely read-only.
3. Keep a small agent-to-workspace registry. Prefer the runner's lifecycle as the source of live state; optional persisted metadata can aid inspection after reload, but does not itself resume a lost job.
4. Snapshot workers at settled boundaries and final handoff, then add the compact joined status tool.
5. Make integration coordinator-owned and ensure repository-wide undo cannot rewind other managed work or unintegrated results.

The normal-Pi approach does not require IPC when the children run in-process. Shared UI permission brokering remains feasible, but correct child-directory permission evaluation must be checked explicitly.

Restart recovery is a separate capability. Do not imply that saving workspace metadata makes a normal-Pi orchestration job resume automatically. Evaluate the actual runner/session recovery behavior before promising this.

## Case B: Durable extension plus host wiring

Compose Durable's existing tasks/conversations/documents rather than copy their scheduler or invent a filesystem messaging protocol.

1. Define a workspace-assignment document and a coordinator job/result document.
2. Add a task that provisions a workspace, associates it with a child conversation, dispatches the assignment, waits/reports and records final handoff state.
3. Configure the child with the assigned `cwd` and role-appropriate tools. Keep workspace creation/integration authority with the coordinator.
4. Install an `env` resolver in the host that reads the conversation assignment and returns the corresponding constrained execution environment. Ensure the configured directory and environment agree.
5. Derive live status from the Harness/task/conversation state; keep completed results in the job document. Add a thin status tool and reuse committed views for UI presentation.
6. Choose foreground/background ownership deliberately. Foreground work follows parent cancellation; background boundaries can keep work alive across the parent's normal abort. Do not select background behavior merely because a task runs concurrently.
7. Implement approval/input presentation separately if required. Shared Harness state makes routing possible, but a durable approval lifecycle and UI are application work, not a free Pi CLI dialog API.

JJ changes and Durable database commits are not one atomic transaction. Workspace creation, snapshotting, merging and deletion are external effects. Use stable job/workspace identities, check what already happened after a restart and make task phases recoverable. Do not mark a tool replay-safe simply because its child conversation is durable.

Keep arbitrary external effects out of assumptions about transaction atomicity. A crash between workspace creation and recording the assignment must be reconciled without creating a duplicate workspace or claiming ownership of unrelated existing work.

## Implementation and verification sequence

Start with the smallest capability in the chosen harness: two editing workers, separate workspaces and an inspectable handoff. Build additional recovery behavior only when required.

| Check | Required evidence |
|---|---|
| Directory routing | Two workers make different edits to the same relative filename in separate workspaces; neither checkout receives the other's edit. |
| Snapshot visibility | Observer polling does not mutate worker snapshots; final handoff includes the worker's actual latest tracked edits. |
| Child permissions | A child can edit its own assigned tree and surfaces approval when required; parent paths/UI identity are not substituted accidentally. |
| Integration | Disjoint changes combine; conflicting changes remain explicit; combined checks run after resolution. |
| Semantic overlap | Tests catch incompatible changes even where JJ reports no textual conflict. |
| Undo/ownership | Coordinator undo cannot quietly rewind an outstanding worker result. |
| Cancellation | Work stops according to its ownership policy and partial checkout contents remain inspectable. |
| Durable recovery | Restart before/after workspace creation, child admission and result reporting; no duplicate workspace, submission or completion report. |
| Sandbox routing | The required shared JJ/Git metadata is usable while unrelated source trees and host configuration remain outside the intended access boundary. |

The Durable cases have supporting SDK examples; this precise JJ orchestration extension and its approval/sandbox behavior remain unimplemented and untested. Normal Pi runner hooks and full multi-workspace permission behavior also remain to be verified.

## Non-goals

No replacement TUI, new cross-process agent messaging service, independent generic scheduler, distributed workers, automatic conflict solver, forced workspace per read-only task or broad per-workspace configuration system is required for the initial feature.

Choose Durable for checkpointed orchestration and recovery. Choose normal Pi for a smaller extension that preserves the existing CLI. Neither approach requires separate Pi processes merely to run multiple editing agents.

## Sources

- [Durable README and API warning](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/README.md)
- [Durable extension and Harness types](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/src/harness/types.ts)
- [Persistent background subagent example](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/23-subagent-background.ts)
- [Per-conversation execution environment example](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/29-sandbox-per-conversation.ts)
- [Extension-owned state example](https://github.com/earendil-works/pi/blob/v1.0.0/packages/durable/test/examples/11-extension-state.ts)
- [Durable coding TUI README](https://github.com/earendil-works/pi/blob/v1.0.0/packages/coding-agent/src/experimental/durable/README.md)
- Installed JJ help: `jj workspace add --help`, `jj new --help`, `jj resolve --help`, `jj help -k revsets` and `jj workspace update-stale --help`.
- Local configuration/code inspected: [`home/ai.nix`](../home/ai.nix), [`sand.fish`](../home/fish-functions/sand.fish), [`jj-undo.ts`](extensions/jj-undo.ts), [`jj-footer.ts`](extensions/jj-footer.ts), [`permissions/config.ts`](extensions/permissions/config.ts), [`permissions/paths.ts`](extensions/permissions/paths.ts).
