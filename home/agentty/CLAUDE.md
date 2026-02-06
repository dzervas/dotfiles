# Agentty — Inline Agent Mode (Implementation Notes)

This document captures the implementation plan, what was completed, and operational notes for the inline fish+starship agent mode.

## Goal

Bring Claude Code directly into the fish prompt flow (Warp-style inline mode):

- Toggle agent mode with keybinds
- Send natural-language prompts from the command line
- Stream responses inline (no TUI/alt-screen)
- Handle permissions and follow-up questions inline
- Persist session/mode/model/provider per working directory

---

## Original Plan (Summary)

1. Build per-directory state store
2. Implement provider abstraction + Claude provider
3. Render normalized streaming events inline
4. Add orchestration (toggle, mode cycle, prompt dispatch, resume)
5. Add PreToolUse permission hook (`/dev/tty` prompt)
6. Add starship agent indicators + active frame color
7. Wire fish keybindings + source files
8. Configure Claude Code hook registration

---

## What Was Implemented

## 1) State management

**File:** `home/agentty/state.fish`

Implemented:

- `__agentty_state_file`
- `__agentty_state_load`
- `__agentty_state_save`
- `__agentty_state_new_session`
- `__agentty_state_clear_env`

State file path:

- `~/.cache/agentty/state.json`

Stored per directory:

- `session_id`
- `session_name`
- `model`
- `mode`
- `provider`
- `updated_at`

Defaults when no state exists:

- `AGENTTY_MODEL=sonnet`
- `AGENTTY_MODE=edit`
- `AGENTTY_PROVIDER=claude`
- `AGENTTY_SESSION=<basename of cwd>`

## 2) Provider abstraction + Claude provider

**File:** `home/agentty/providers/claude.fish`

Implemented interface:

- `__agentty_provider_claude_run <prompt>`
- `__agentty_provider_claude_resume <session_id> <prompt>`
- `__agentty_provider_claude_supports <feature>`
- `__agentty_provider_claude_normalize`

Behavior:

- Executes `claude -p ... --output-format stream-json --model $AGENTTY_MODEL`
- Reuses active session via `--resume --session-id $AGENTTY_SESSION_ID`
- Mode mapping:
  - `edit`: default permissions
  - `plan`: `--permission-mode plan`
  - `read-only`: `--permission-mode plan` + allow/disallow tool lists
- Normalizes stream-json to provider-agnostic events:
  - `init`
  - `text`
  - `tool_start`
  - `tool_result`
  - `ask`
  - `done`

## 3) Stream renderer

**File:** `home/agentty/render.fish`

Implemented:

- `__agentty_render_stream`
- `__agentty_render_text`
- `__agentty_render_tool_header`
- `__agentty_render_tool_result`
- `__agentty_render_ask`
- `__agentty_render_footer`

Behavior:

- Reads normalized JSONL from stdin
- Prints assistant text directly inline
- Renders tool headers and dimmed tool outputs
- Truncates tool results to ~10 lines
- Detects `ask` events and collects answers from `/dev/tty`
- Emits follow-up state via `AGENTTY_NEEDS_FOLLOWUP`
- Updates session id from `init` events

## 4) Core orchestration

**File:** `home/agentty/agentty.fish`

Implemented:

- `agentty_toggle`
- `agentty_mode_cycle`
- `agentty_new_session`
- `__agentty_accept_line`
- `__agentty_run_prompt`
- `__agentty_on_pwd_change --on-variable PWD`

Behavior:

- Toggle ON:
  - loads per-dir state
  - sets `AGENTTY_ACTIVE=1`
  - binds Enter to agent submit handler
- Toggle OFF:
  - restores default Enter binding
  - clears `AGENTTY_*` vars
- Enter in agent mode:
  - reads commandline
  - appends to fish history
  - dispatches via current provider
  - streams inline render
  - handles ask/resume cycle
  - saves updated state
- PWD change while active reloads state for new directory

## 5) PreToolUse permission hook

**File:** `home/agentty/hooks/pretooluse.sh`

Implemented policy:

- If `AGENTTY_ACTIVE` not set: exit immediately (no interference)
- Auto-allow safe tools (`Read`, `Glob`, `Grep`, `WebSearch`, `WebFetch`, etc.)
- Auto-allow safe Bash command patterns (e.g. `git status`, `ls`, `pwd`, `jq`, `rg`)
- Auto-deny dangerous patterns (e.g. destructive disk/system commands)
- Otherwise prompt user via `/dev/tty` and return JSON allow/deny decision

Returns Claude hook response format:

- `hookSpecificOutput.hookEventName=PreToolUse`
- `permissionDecision=allow|deny`
- `permissionDecisionReason=...`

## 6) Starship integration

**File:** `home/starship.nix`

Implemented:

- Added `env_var` modules:
  - `AGENTTY_MODE`
  - `AGENTTY_SESSION`
  - `AGENTTY_MODEL`
- Added custom frame modules for active/inactive prompt frame coloring
- Inserted agent modules into prompt after directory segment

Note: these modules only render when corresponding env vars are set.

## 7) Fish wiring

**File:** `home/fish.nix`

Added to `interactiveShellInit`:

- Sources:
  - `agentty/state.fish`
  - `agentty/render.fish`
  - `agentty/providers/claude.fish`
  - `agentty/agentty.fish`
- Keybindings:
  - `Alt+i` (`\ei`) → `agentty_toggle`
  - `Alt+m` (`\em`) → `agentty_mode_cycle`
  - `Alt+n` (`\en`) → `agentty_new_session`

## 8) Hook registration

**File:** `home/ai.nix`

Added Claude Code settings hook:

- `settings.hooks.PreToolUse[*].hooks[*].command = toString ./agentty/hooks/pretooluse.sh`

This ensures the hook is configured through Home Manager Claude settings.

---

## Runtime Environment Variables

Set while active:

- `AGENTTY_ACTIVE`
- `AGENTTY_SESSION_ID`
- `AGENTTY_SESSION`
- `AGENTTY_MODEL`
- `AGENTTY_MODE`
- `AGENTTY_PROVIDER`

Used by:

- Starship prompt modules
- Provider mode/session logic
- Hook gating behavior (`AGENTTY_ACTIVE`)

---

## Verification Checklist

1. **Toggle mode**
   - `Alt+i` enables/disables agent mode
   - prompt visuals update accordingly

2. **Mode cycle**
   - `Alt+m` cycles: `edit -> plan -> read-only -> edit`
   - mode indicator updates in prompt

3. **New session**
   - `Alt+n` creates new UUID session for current dir

4. **Per-directory state**
   - `cd` to another dir while active
   - state reloads per dir, restores when returning

5. **Prompt dispatch**
   - in agent mode, type a natural-language prompt and press Enter
   - assistant output streams inline

6. **Permission hook**
   - trigger a tool use requiring approval
   - confirm `/dev/tty` prompt appears and decision is applied

7. **Read-only mode**
   - switch to read-only and ask for an edit
   - verify disallowed tools are blocked

8. **AskUserQuestion loop**
   - trigger an ask flow
   - choose answer in terminal
   - verify follow-up resume happens

---

## Dependencies

Expected runtime tools:

- `claude-code`
- `jq`
- `uuidgen` (coreutils)
- `fish`
- `starship`

Optional (not yet wired in current renderer):

- `gum`

---

## Useful Operational Notes

- This implementation is provider-first: core logic calls provider functions, not `claude` directly.
- State is directory-scoped, so each repo/folder can keep its own session/mode/model context.
- Hook behavior is intentionally no-op when `AGENTTY_ACTIVE` is unset, so regular Claude usage is unaffected.
- Renderer question inputs are read from `/dev/tty`, allowing interaction even while stream input is piped.

---

## Future Enhancements

- Add gum-based richer selection UI with fallback
- Improve args summarization for tool headers
- Add incremental/delta rendering for partial stream events
- Add persistence for “always allow” decisions in hook policy
- Add additional providers (e.g. opencode, aider) via same interface
