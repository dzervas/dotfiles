# Pi in Zed through ACP

Zed uses the patched `pi-acp` package from `overlays/pi-acp.nix`, not the registry's adapter. `home/zed/settings.json` launches `run-acp.fish` on the host. Apply the Home Manager/NixOS configuration to install the package, then start a new **pi-acp** thread in Zed (or reload an old connection).

## Project sandbox boundary

The host launcher sets `PI_ACP_PI_COMMAND` to the executable `run-pi.fish`. The adapter starts that launcher **in each ACP session's cwd**, including resumed sessions. It loads that project's direnv environment and invokes the existing `home/fish-functions/sand.fish` wrapper, preserving RPC arguments and explicitly loading `sandbox.ts`.

Do not sandbox the adapter once in its startup directory and reuse that sandbox for other projects. Each top-level session has its own Pi process, with mounts selected by `sand` for that session's project. Starting another thread no longer closes other threads. Reloading a busy session is rejected; finish or cancel its turn first. Idle reload waits for the old process to exit before opening the same file again. In-process Pi subagents inherit the parent's sandbox; they are not separate native Zed threads.

The adapter remains a host process for protocol handling and session discovery. Pi's file and shell tools execute inside bubblewrap, not through Zed's filesystem/terminal delegation. `PI_ACP_READ_COMMAND` points to `read-file.fish`, which also reads native-diff snapshots through `sand` in the session's cwd. Canonical project checks reject outside paths. Inside the sandbox, `read-file.mjs` checks the opened file descriptor's canonical path against the project before reading that same descriptor, preventing symlink races from exposing either host-only or sandbox-visible non-project bytes. Without this helper, the adapter skips snapshots rather than falling back to host reads. Remote MCP actions still have the permissions of their server; bubblewrap does not constrain them.

## Native UI

- **Questionnaire:** the existing terminal component is unchanged in TUI mode. In this integration's RPC mode it becomes an ACP elicitation form. Options retain their labels and descriptions; Other has a separate optional text field. Current Zed text fields are single-line, not Pi's tabbed/multiline editor.
- **Permissions:** when Pi's permission gate asks, a labelled permission form offers Allow once, Allow and save, and No, with an optional steering message. Cancellation or invalid answers never grants permission. The form does not replace the underlying Pi permission rules or sandbox.
- **`/answer`:** question extraction runs without a terminal loader in RPC mode, followed by the same questionnaire form. The terminal shortcut stays terminal-only; type the command in Zed.
- **Todos:** successful `todo` results become native ACP plans. Resuming reconstructs the latest successful list on the active branch, including history before compaction. A cleared list stays cleared; failed writes and abandoned branches are ignored.
- **Subagents:** normal Pi subagent tools/progress/results remain available; the terminal's custom management widget and transcript viewer are not native Zed UIs.

## Form transport

Pi RPC already supports `ctx.ui.editor()` dialogs but cannot serialize `ctx.ui.custom()` terminal components. `lib/acp-form.ts` uses a versioned editor envelope:

```text
method: editor
 title: __pi_acp_form_v1__
prefill: JSON.stringify({ message, requestedSchema })
```

The adapter recognizes this envelope, validates the flat schema, checks the client's negotiated form capability, and sends `elicitation/create`. Accepted content returns as a JSON string in the correlated Pi editor response. Decline, cancellation, unsupported clients and errors cancel the dialog. The Pi launcher alone enables this path with `PI_ACP_FORMS=1`; other Pi frontends retain their existing behavior.

## Verification

From the repository root:

```sh
node --experimental-transform-types --test pi/extensions/lib/acp-form.test.ts pi/extensions/lib/question-extraction.test.ts
python pi/acp/test-launcher.py
statix check overlays/pi-acp.nix
nix build --impure --no-link --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage ./overlays/pi-acp.nix {}'
```

The package check runs adapter typechecking and tests. The launcher tests stub direnv/bubblewrap/Pi, so they exercise argument forwarding and independent project mount selection without accessing real credentials or launching agents.

After activation, verify in Zed: multi-question choices + Other, cancellation, a todo update and resume, and simultaneous threads in two projects. Do not open the same session file in Zed and pifleet concurrently.
