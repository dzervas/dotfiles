# Local patches

Hand-applied fixes to third-party Pi packages installed at runtime by Pi into
`~/.pi/agent/npm/node_modules/`. These are **not** managed by Nix and are
**reverted whenever Pi reinstalls the package** (e.g. after `pi-extension-bump`
or a version change in `home/ai.nix`). Re-apply them after any such reinstall.

---

## `@quintinshaw/pi-dynamic-workflows` — `/workflows` navigator crash

- **Package version:** `2.12.1` (pinned in `home/ai.nix`)
- **Still present upstream in:** `3.2.0` (latest at time of writing) — bumping does not fix it.
- **File:** `~/.pi/agent/npm/node_modules/@quintinshaw/pi-dynamic-workflows/src/workflow-ui.ts`

### Symptom

Opening `/workflows` (in the phases view of a live/paused run) crashes Pi:

```
TypeError: text.slice is not a function
    at truncateToWidth (.../@earendil-works/pi-tui/dist/utils.js:863:45)
    at leftPhaseRow (.../pi-dynamic-workflows/src/workflow-ui.ts:433:43)
    at renderPhasesAgents (.../workflow-ui.ts:609:15)
    at renderNavigator (.../workflow-ui.ts:788:19)
```

### Root cause

`leftPhaseRow()` calls `truncateToWidth(p.title, ...)`. `truncateToWidth` only
handles strings — passing a **number** (or object) throws
`text.slice is not a function`. The `PhaseRow.title` values are produced by
`WorkflowModel.phases()`, which copies `snapshot.phases` entries and each
agent's `phase` straight into `title` with no coercion. A live/paused run whose
phase title is not a string (e.g. a workflow that used a numeric `phase`) then
crashes the renderer. Persisted runs on disk with string phases are unaffected.

### Patch

In `phases()`, coerce the title to a string at the single chokepoint (this
protects both `computeLeftWidth` and `leftPhaseRow`):

```diff
     return order.map((title) => {
       const agents = byPhase.get(title) ?? [];
       return {
-        title,
+        title: typeof title === "string" ? title : String(title),
         done: agents.filter((a) => a.status === "done").length,
         total: agents.length,
         tokens: agents.reduce((n, a) => n + (a.tokens ?? 0), 0),
       };
     });
```

### Re-apply command

```sh
F=~/.pi/agent/npm/node_modules/@quintinshaw/pi-dynamic-workflows/src/workflow-ui.ts
python3 - "$F" <<'PY'
import sys
f=sys.argv[1]; s=open(f).read()
old='''    return order.map((title) => {
      const agents = byPhase.get(title) ?? [];
      return {
        title,'''
new='''    return order.map((title) => {
      const agents = byPhase.get(title) ?? [];
      return {
        title: typeof title === "string" ? title : String(title),'''
if new.split("title:")[1].strip() in s:
    print("already patched"); raise SystemExit
assert s.count(old)==1, f"expected 1 match, got {s.count(old)}"
open(f,"w").write(s.replace(old,new,1)); print("patched OK")
PY
```

### Upstream

Worth reporting to `@quintinshaw/pi-dynamic-workflows`: `WorkflowModel.phases()`
(and, for correctness, the phase-grouping key and `model.agents(runId, p.title)`
lookup) should coerce phase titles to strings before rendering.

---

## `@gotgenes/pi-subagents` — extend completed-agent retention to 24h

- **Package version:** `18.0.1` (pinned in `home/ai.nix`)
- **File:** `~/.pi/agent/npm/node_modules/@gotgenes/pi-subagents/src/lifecycle/subagent-manager.ts`

### Change

Personal preference: keep completed subagents around for 24 hours instead of
10 minutes before the cleanup sweep evicts them (sessions are kept for resume
either way). The sweep still runs once a minute; only the retention cutoff
changes.

```diff
     // Cleanup completed agents after 10 minutes (but keep sessions for resume)
-    // Cleanup completed agents after 10 minutes (but keep sessions for resume)
+    // Cleanup completed agents after 24 hours (but keep sessions for resume)
     this.cleanupInterval = setInterval(() => this.cleanup(), 60_000);
```

```diff
   private cleanup() {
-    const cutoff = Date.now() - 10 * 60_000;
+    const cutoff = Date.now() - 24 * 60 * 60_000;
```

(The doc comment on the evicted-agent snapshot is also updated from "10-minute"
to "24-hour" for accuracy.)

### Re-apply command

```sh
F=~/.pi/agent/npm/node_modules/@gotgenes/pi-subagents/src/lifecycle/subagent-manager.ts
python3 - "$F" <<'PY'
import sys
f=sys.argv[1]; s=open(f).read()
reps=[
 ("    const cutoff = Date.now() - 10 * 60_000;",
  "    const cutoff = Date.now() - 24 * 60 * 60_000;"),
 ("    // Cleanup completed agents after 10 minutes (but keep sessions for resume)",
  "    // Cleanup completed agents after 24 hours (but keep sessions for resume)"),
 (" * A lightweight snapshot of a subagent evicted by the 10-minute cleanup sweep.",
  " * A lightweight snapshot of a subagent evicted by the 24-hour cleanup sweep."),
]
if "24 * 60 * 60_000" in s:
    print("already patched"); raise SystemExit
for old,new in reps:
    assert s.count(old)==1, f"expected 1 match for {old!r}, got {s.count(old)}"
    s=s.replace(old,new,1)
open(f,"w").write(s); print("patched OK")
PY
```
