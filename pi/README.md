# Pi configuration

Normal Pi CLI and in-process subagents use the same local extensions. `native-tools.ts`
loads Pi's public MCP, Code Mode, and tool-search factories. Their automatic CLI
entries are disabled to avoid registering them twice. This requires Pi 1.0.0.

## Docker MCP boundary

`home/pi-mcp-gateway.nix` starts a host user service that owns Docker access.
Its declarative server list currently contains only the NixOS documentation image.
The gateway uses an explicit server list, so dynamic server-management tools are
not exposed. Pi connects over authenticated Streamable HTTP on loopback; it has
no Docker or host keyring socket. Container mounts and launch options are owned
by the host configuration, not supplied by Pi.

Gateway authorization is generated under `~/.cache/pi-mcp-gateway/` with private
permissions. Only the authorization header file is made available inside `sand`.
The gateway's environment file and Docker configuration stay outside. Add local
servers to the declarative list rather than putting `docker run` or `npx` in
Pi's MCP configuration.

After rebuilding the configuration, check:

```fish
systemctl --user status pi-mcp-gateway
pi --version
pi mcp list
pis
```

The gateway's `/health` route is for service diagnostics; MCP uses `/mcp`.

## OAuth inside the sandbox

The removed MCP adapter used an OS keyring. Sharing its old `mcp-oauth` directory
could not provide access to that keyring inside bwrap.

Native MCP stores OAuth state in `mcp-auth.json`. In `pis`, that file and its
locks live in the writable persistent sandbox home, independently from bare Pi.
Sign in once with `/mcp login context7` in each project sandbox after migrating.
Refreshes no longer require host keyring access. Real provider refresh behavior
still needs verification after the rebuild; no credentials were inspected or
copied during this migration.

Permissions stay enabled inside bwrap. `/yolo` explicitly disables the gate in a
sandboxed session; read-only mode and nested Code Mode checks work with the gate
enabled. Bwrap does not constrain remote MCP actions.

## Extension review

- Removed the MCP adapter and web-access packages; native MCP and Code Mode replace
  the integration layer. General web search is no longer a built-in local capability;
  add a configured Docker MCP service if needed.
- Removed the JavaScript workflow engine and its local dependencies. Its terminal
  activity helper remains shared by background Bash. Gotgenes subagents stay installed.
- Merged `/answer` and `ctrl+.` extraction into questionnaire's existing dialog.
- Removed the empty runtime patcher and moved the no-redundant-directory-change
  instruction into `global_agents.md`. Whimsical messages remain.
- Todo uses complete snapshots of subjects and explicit statuses, with no IDs,
  active-form labels, confidence scoring, or collapse controls. The title suffix
  shows the active task's one-based position, such as `3/5`, and disappears when
  there is no active task. Permission and questionnaire dialogs alternate ``
  and `` at the start of the title once per second, then restore its normal animation.
- Compact read/search tools preserve upstream prompt metadata and use each session's
  working directory. They compact presentation, not model context.
- Notifications and title spinners run only in the TUI. Continuation handlers are
  registered separately for each session and survive reload correctly.
- Automatic JJ checkpoints belong to the TUI parent; undo refuses while subagents
  are running. Undo still restores repository-wide state and should be used deliberately.
- Long usage-limit waits are a parent-TUI convenience; headless children surface
  failures instead of retrying indefinitely. Background Bash records failed results.
- Permission dialogs serialize child requests on the parent UI. Native MCP
  names/resources are recognized by the permission policy. The Bash card starts
  timing at actual execution, after approval; denied calls never start a timer.
- Kept the focused bookmark, clear/model-selection, context loading, llama-swap,
  system-prompt inspection, tool listing, JJ footer, and compaction status helpers.

Remaining limits: old Pi extension packages can need API updates; questionnaire is
an interactive-parent tool; the permission classifier is a decision aid rather
than an OS security boundary. No generic Docker API proxy was introduced.

## Learned memory

The local `memory/` extension lets the active agent save durable preferences and
verified project lessons. It exposes two tools:

- `memory`: `list`, `remember`, `replace`, or `forget`, with `project` (default)
  or `global` scope. Replace supplies `previous` as the exact existing note text;
  forget supplies that text in `text`.
- `memory_search`: case-insensitive keyword search of both scopes, or one selected
  scope. All query terms must match.

Global notes live in `~/.pi/agent/memory/MEMORY.md`; project notes live in
`<repository root>/.pi/MEMORY.md` (current directory outside a repository).
Repository discovery recognizes `.git` directories/files and `.jj` directories.
Each file is capped at 200 dated, single-line notes and 8 KiB, including formatting.
Files are created on the first successful write. Example:

```text
# Memory

- 2026-10-02: Prefer Fish for scripts.
```

Notes load once per session to keep the system prompt stable; searches and lists
read the latest files. Writes use an exclusive directory lock and atomic rename,
so concurrent parent/child sessions cannot silently overwrite each other.
Read mode requests approval for mutations; configured denied paths still apply.
`sand` shares only the global memory directory with the host. This requires the
updated Fish function to be activated; other sandboxes keep isolated notes until
then.

The extension rejects overflow instead of dropping or summarizing notes. It also
refuses malformed or manually oversized files; repair those manually. After a
writer crashes while holding its lock, remove the adjacent `MEMORY.md.lock`
directory once that writer has stopped. Dates indicate when a note was saved,
not when its truth was independently checked.

There are no background reviews or local-model calls. The main agent chooses
what deserves a note, with guidance to avoid secrets, transient progress, guesses,
and facts readily recovered from code. Local models can later suggest shortening
or duplicate merges on demand. Keep personal project notes out of version control
using the repository's local exclude file when appropriate.


## Experimental Pi Durable

The `pi-durable` package installs a separate `pi-durable` command alongside Pi.
After `rebuild`, run `pi-durable` for a new session or `pi-durable --continue`
(`-c`) to reopen the newest Durable session for the current directory.

It runs upstream's experimental coding-agent TUI through its source resolver,
with the Durable SDK and its dependencies also compiled for library use under
`lib/pi-durable/packages/durable/dist` in the package output. The source version,
offline npm cache and provider model catalog follow `pi-coding-agent-latest`.

The demo shares Pi's settings and authentication, while keeping its SQLite
sessions under `~/.pi/agent/experimental/durable-sessions`. It has its own
extension registry: the normal Pi extensions, including our permission dialogs,
are not loaded by this demo. Its command-line options currently support only
`--continue` / `-c`; model selection happens in the TUI.

## Neovim session manager

`pifleet` opens the opt-in [Snacks session tree](fleet/README.md) using normal Neovim configuration. It launches sandboxed Pi terminals, searches saved messages, and stores snooze reminders. Before rebuilding, run `fish home/fish-functions/pifleet.fish` from the dotfiles repository.
