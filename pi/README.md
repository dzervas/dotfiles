# Pi configuration

The Pi CLI loads its built-in MCP, Code Mode and tool-search extensions directly.
Keep their native identities: `pi-subagents` detects native MCP by the `builtin:mcp`
command source and otherwise falls back to the legacy adapter integration.
Nico's `pi-subagents` uses the child SDK's MCP/Code Mode support and an explicit
extension list in `home/ai.nix` for local tools and permission hooks. Its runtime
settings live in `extensions/subagent/config.json`; agent/model overrides live in
`home/ai.nix`. This requires Pi 1.0.0.

## Docker MCP boundary

`home/pi-mcp-gateway.nix` starts a host user service that owns Docker access.
It loads the existing Docker MCP `pi` profile, including its configured servers
and tool allowlists. Pi connects over authenticated Streamable HTTP on loopback;
it has no Docker or host keyring socket. Container mounts and launch options are
owned by the host profile, not supplied by Pi. Gateway management tools follow
Docker's `dynamic-tools` feature setting; `--profile` does not disable them like
`--servers` did.

Gateway 0.44.1 drops `DOCKER_HOST` when spawning container-backed servers. The
service supplies a local `docker` launcher through `PATH` that explicitly selects
the user's rootless socket. The gateway plugin is started directly rather than
through `docker mcp`: nixpkgs' `docker` wrapper prepends its own `libexec/docker`
(containing the real CLI) to `PATH`, which would shadow the launcher. This works around the prebuilt gateway's environment
bug without giving Pi Docker access or changing Docker commands in normal shells.

With `--profile`, the gateway passes container secrets as `se://` references
(e.g. `KAGI_SESSION_TOKEN=se://docker/mcp/kagi.session_token`) and ignores
`--secrets`. Only Docker Desktop resolves these, so plain Docker servers would
receive the literal reference. The launcher runs through `docker pass run`, which
resolves them from the secrets engine before `docker run` copies them into the
container. The launcher also restores `HOME`, which the gateway strips too;
`docker pass` locates the engine socket under `~/.cache`.

The Kagi server image `git.vpn.dzerv.art/dzervas/homelab/kagi-mcp` is pulled by the
gateway; `docker/Dockerfile.kagi-mcp` is its source, built and pushed separately.
Activation installs `~/.docker/mcp/catalogs/pi.yaml`, which declares the
`kagi.session_token` secret, because image labels cannot bind secrets. Add the
secret once:

```fish
docker mcp secret set kagi.session_token   # token on stdin
systemctl --user restart pi-mcp-gateway
```

Gateway authorization is generated under `~/.cache/pi-mcp-gateway/` with private
permissions. Only the authorization header file is made available inside `sand`.
The gateway's environment file and Docker configuration stay outside. Manage
servers through the Docker MCP `pi` profile rather than putting `docker run` or
`npx` in Pi's MCP configuration.

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

Loading `sandbox.ts` requires that same extension in native child sessions,
including detached and nested children and agent extension-list overrides. Each
child publishes sandbox state locally; there is no additional environment flag.
Contained sessions skip local permission/protected-path gates and mandatory child
permission hooks. Ordinary launches never load or propagate `sandbox.ts`.
Unsandboxed headless asks still fail closed when no parent UI broker is available:
cross-process approval forwarding remains unimplemented. Bwrap does not constrain
remote MCP actions.

## Extension review

- Removed the MCP adapter and web-access packages; native MCP and Code Mode replace
  the integration layer. General web search is no longer a built-in local capability;
  add a configured Docker MCP service if needed.
- Removed the JavaScript workflow engine and its local dependencies. Its terminal
  activity helper remains shared by background Bash. Nico's `pi-subagents` replaces
  Gotgenes; the bundled `delegate` permits bounded nested delegation. Tool grants
  extend bundled roles through settings rather than copied agent definitions.
- Merged `/answer` and `ctrl+.` extraction into questionnaire's existing dialog.
- Removed the empty runtime patcher and moved the no-redundant-directory-change
  instruction into `global_agents.md`. Whimsical messages remain.
- Beads ownership uses `BEADS_ACTOR=pi:<parent-session-id>`, set when the parent
  starts and inherited unchanged by its subagents. The widget and `/todos` filter
  claims to that team; Fleet identifies individual contributors. Helpers reuse
  the team's claim unless explicitly assigned another ticket. Existing claims
  under an older assignee are not automatically reassigned. Start a fresh session
  for the updated claiming guidance; recorded guidance stays frozen on resume.
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
- Permission dialogs serialize in-process child requests on the parent UI.
  Detached children cannot use that process-local broker: approval-required calls
  fail closed and must be escalated to the interactive parent. Native MCP
  names/resources are recognized by the permission policy. The Bash card starts
  timing at actual execution, after approval; denied calls never start a timer.
- Kept the focused bookmark, clear/model-selection, context loading, llama-swap,
  system-prompt inspection, tool listing, JJ footer, and compaction status helpers.

Remaining limits: old Pi extension packages can need API updates; questionnaire is
an interactive-parent tool; the permission classifier is a decision aid rather
than an OS security boundary. No generic Docker API proxy was introduced.

## Learned memory

The local `memory/` extension lets the active agent save durable preferences and
verified project lessons. `/mem` opens a settings-style Project/Global browser:
Tab or left/right switches scope, Enter opens Edit/Forget, and the first/default
row adds a memory. Edit opens a prefilled editor; Esc cancels or closes the panel.

Panel edits notify only the parent immediately with a diff. The interactive parent
also polls the agent-only Atuin profile every 30 seconds for changes made elsewhere;
polls do not overlap and stop on shutdown/reload. Changes append at the next safe
boundary and never start another model turn, even during compaction. Existing startup
snapshots stay frozen. Remote synchronization still follows Atuin's sync-frequency
gate. `atuin-agent` remains available; `/mem` replaces `atuin-agent-mem`.

The extension exposes two tools:

- `memory`: `list`, `remember`, `replace`, or `forget`, with `project` (default)
  or `global` scope. Replace supplies `previous` as the exact existing note text;
  forget supplies that text in `text`.
- `memory_search`: case-insensitive keyword search of both scopes, or one selected
  scope. All query terms must match.

Notes live in the dedicated Atuin agent KV profile: `pi/global` and a namespace
for each project's remote slug (repository directory name when no remote exists).
Repository discovery recognizes `.git` directories/files and `.jj` directories.
Each note is a dated, single-line value keyed by its text hash.

The startup index is limited to 200 notes and 25 KiB per namespace, including
formatting and any overflow notice. Storage is not capped by those limits:
remember/replace/forget persist first, then return a tool error asking the agent
to shorten or merge notes if the resulting index is still too large. The response
explicitly says the write succeeded; retrying is not needed. Nothing is silently
evicted or summarized. Malformed note input is still rejected before writing.

New sessions load a bounded prefix of complete notes with an explicit overflow
notice; list/search can retrieve all stored notes, including omitted ones.
Startup context is frozen and recorded to preserve prompt caching, so reload,
resume and fork reuse the existing snapshot. Later edits are visible through
list/search immediately and in startup context on the next fresh session.
Atuin synchronization follows its configured sync-frequency gate.

Read mode requests approval for mutations; configured denied paths still apply.
Dates indicate when a note was saved, not when its truth was independently checked.

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
