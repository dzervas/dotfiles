# Pi fleet

A dedicated Neovim session manager using the existing Snacks installation and native terminals. Normal Neovim does not load it.

After applying the Home Manager configuration, run `pifleet`. Before rebuilding, from the dotfiles repository:

```fish
fish home/fish-functions/pifleet.fish
```

The manager runs on the host. Selecting a saved session starts Pi through the existing `sand.fish` sandbox, with `--session` and an explicit cwd taken from the JSONL header. Before entering the sandbox, the launcher loads the session directory's direnv environment the way the shell hook does: blocked `.envrc` files print direnv's error and the agent starts without them, and secrets listed in `sand.fish` are still stripped. No agent starts merely because you open the manager. Hidden terminals keep running; closing the manager stops its agents.

| Key | Action |
| --- | --- |
| Alt-o | Hide/show the sidebar (fullscreen) |
| Alt-f | Search session names/project labels, with recent-message preview |
| Ctrl-f | Search user/assistant message text across session files, with surrounding-message preview |
| Alt-down in an agent terminal | Leave terminal input and move to the previous window |
| Enter in the sidebar | Open a session or expand/collapse a project |
| Double-click in the sidebar | Switch to a running session; dead sessions are ignored |
| n in the sidebar | Start immediately in the highlighted session/project directory |
| N in the sidebar | Choose a directory, prefilled from the highlighted session/project |
| s in the sidebar | Snooze; press again to clear an existing reminder |
| q in the sidebar | Hide the sidebar |

The terminal title shows `  <selected project label>`. When any managed agent needs human input, including a hidden agent, it alternates `` / `` once per second. Working and idle agents do not trigger this animation.

If the highlighted row has no existing directory available, both **n** and **N** ask for a directory with `$HOME` prefilled. Project paths come from their session headers, never from the lossy encoded folder names.

Other global Neovim shortcuts, statusline, and tabline are retained. Escape and Alt-up reach Pi. Alt-f and Ctrl-f take priority over Pi's word/character-forward shortcuts; arrow keys remain available.

Folders sort by session activity: waiting/working agents first, idle running agents next, then inactive folders. Within each group, the latest session-file update wins; names break ties. Folders containing only inactive sessions start collapsed; manual expansion survives refreshes. Expanded folders show every running, waiting, or idle agent and the three newest inactive sessions. Enter on `[show more...]` reveals older inactive sessions; `[show less...]` folds them again. Both searches always include the full history.

Sessions are grouped from `~/.pi/agent/sessions/` directory names, with the special Lab/work labels. Directory decoding is for display only: launch paths come from session headers. Names use the latest Pi `session_info`, falling back to the first user prompt. Metadata is cached and refreshed every five seconds. Name previews load on selection; history search streams results through Snacks and uses literal text matching rather than regular expressions. Tool output, reasoning blocks, and image data are excluded. The JSONL file's user/assistant history includes retained branches.

The explicitly loaded `pi/extensions/lib/fleet-session.ts` reports Pi's current session file and name over the terminal. Pi handles `/new`, `/resume`, `/fork`, and renaming; Neovim just updates the terminal association. No host control socket is exposed to Pi. The existing titlebar spinner supplies working/waiting markers. If two managed processes resume the same file, both remain tracked and show a warning; this does not lock the file or prevent concurrent writes.

No external-process detection or ownership guarantee is provided. A session running outside this manager may appear inactive. There is no background daemon, detach persistence, or cross-instance coordination; use one manager at a time. A sandbox launch still has all requirements of the existing `pis`/`sand` setup.

## Snooze

Choose 1, 4, or 8 hours; next occurrence of 14:00; Friday 20:00; or Monday 14:00. Local calendar calculations account for DST. At 04:00, the 14:00 choice means later that same day.

State is saved atomically in `stdpath("state")/pi-fleet/snoozes.json`, keyed by the real session file. Snoozed rows are dimmed and show the deadline; overdue rows show a warning. Pending reminders notify via `notify-send` immediately on launch, including missed deadlines, and while the manager remains open. A successful notification is persisted to avoid repeating it on reopening. Failed delivery can retry on the next launch. Press **s** to clear either a snoozed or due reminder. Snoozing never stops an agent.

## Verification

`check.lua` uses disposable JSONL files and Python terminal processes. It never starts Pi or reads real session histories. It removes its own `.test-work` fixture directory on exit and refuses to overwrite an existing fixture directory.

```sh
nvim --headless -c 'lua dofile("pi/fleet/check.lua")'
TZ=Europe/Athens nvim --headless -c 'lua dofile("pi/fleet/check-snooze.lua")'
```
