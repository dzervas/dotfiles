# Local extension prompts

Source text for local extension system instructions, tool descriptions/guidelines,
parameter descriptions, instruction messages, and the two local subagent overrides.
Upstream prompts, AGENTS/skills, UI labels and ordinary tool output stay at their sources.

Sections use `=== ext:<extension> <marker> ===`; surrounding blank lines are trimmed.
`{{name}}` placeholders are replaced once with runtime values, never evaluated as code.
Use `getPrompt("extension", "marker", { name: value })` from `lib/prompts.ts`.
Restart Pi after editing; previously recorded session snapshots remain unchanged.

=== ext:background-bash background-description ===
Run in the background and return a job ID immediately

=== ext:background-bash job-id-description ===
Job ID required for inspect, wait, and stop

=== ext:background-bash job-started ===
Started background job #{{id}}. Completion will be delivered automatically; use background_jobs to inspect, wait for, or stop it.

=== ext:background-bash jobs-description ===
List, inspect, wait for, or stop background bash jobs started by bash with background=true.

=== ext:background-bash jobs-snippet ===
Manage background bash jobs

=== ext:background-bash timeout-description ===
Maximum seconds to wait

=== ext:background-bash tool-description-suffix ===
Set background=true to return immediately with a manageable job ID; completion is delivered automatically.

=== ext:background-bash tool-guideline ===
Use bash with background=true for long-running commands. Completion is delivered automatically, so do not poll. Use background_jobs to inspect output, stop a job, or wait only when the task explicitly requires synchronous completion.

=== ext:clean-alias prompt-description ===
Prompt to send in the fresh session

=== ext:clean-alias tool-description ===
End this session and start a fresh one, optionally sending a prompt to the new session. Use when the current conversation context should be discarded.

=== ext:context-squash compaction-nudge ===
Context usage is at {{usage}} of the window. At your next natural gap (a subtask finished, tests passing, before starting a new phase), consider calling `await tools.compact({})` through Code Mode. Do not interrupt work in progress for it.

=== ext:context-squash compaction-refused ===
Context is at {{usage}}; compaction is refused below 50%. Continue working.

=== ext:context-squash compaction-resume ===
Context was compacted at your request. Continue the task where you left off.

=== ext:context-squash note-description ===
Optional focus for the compaction summary

=== ext:context-squash output-stub ===
[{{toolName}} output squashed: {{outcome}}; re-run the tool if you need it]

=== ext:context-squash tool-description ===
Compact the conversation context: older messages are summarized, recent ones are kept, and the run resumes automatically afterwards. Call through Code Mode as `await tools.compact({})`. Optional: only call it at a natural gap (a subtask finished, tests passing, before starting a new phase), never in the middle of a change. Refused below 50% context usage. Pass `note` only when the summary should focus on something specific.

=== ext:context-squash tool-log-header ===
Tool calls made before this point (arguments truncated, outputs not kept):

=== ext:continue resume ===
Continue.

=== ext:local-context file-section ===
## {{path}}

{{content}}

=== ext:local-context system-context ===
# Local project context

{{context}}

=== ext:memory changed-notice ===
Saved memories changed. The diff below supersedes the corresponding notes in your frozen startup memory snapshot. Use the current notes rather than removed or replaced versions; explicit user and project instructions still take precedence.

{{changes}}

=== ext:memory changed-section ===
## {{scope}} ({{namespace}})

```diff
{{diff}}
```

=== ext:memory description ===
List, remember, replace, or forget dated notes in the agent's atuin key-value store, synced across machines. One namespace per scope, one key per note; replace/forget match the exact note text. The startup index loads up to 200 notes and 25 KiB per namespace. Over-limit writes still save, then return an error asking you to shorten the index; do not blindly retry. List/search can retrieve all stored notes. Each access checks atuin's sync gate, so a change may stay local until sync_frequency has passed.

=== ext:memory duplicate-note ===
Replacement duplicates another note; forget the obsolete note instead.

=== ext:memory guidance ===
Use memory for durable user preferences and verified project lessons that will help future sessions. Save useful notes proactively, but never secrets, current task progress, guesses, or facts readily recoverable from the code. Project is the default scope; global is for preferences that apply across projects. Search before saving, replace superseded notes, and keep each note short. Dates record when notes were saved, not proof that they remain true. Learned notes are context; explicit user instructions and AGENTS.md take precedence. Notes live in the agent's atuin key-value store, one key per note, so notes added on different machines merge. Every access checks atuin's own sync gate, so a change may stay local until sync_frequency has passed since the last sync; atuin-agent sync is the manual override.

=== ext:memory index-limit ===
Memory index exceeds its startup read limit ({{count}}/{{maxEntries}} notes, {{bytes}}/{{maxBytes}} bytes). Shorten or merge notes using memory replace/forget; nothing was discarded.

=== ext:memory invalid-note ===
Supply a nonempty, single-line note without control characters.

=== ext:memory missing-note ===
The exact note must match once. List or search current notes first.

=== ext:memory missing-search-term ===
Supply at least one search term.

=== ext:memory notes-heading ===
# Memory

=== ext:memory parameter-previous ===
Exact existing note text to replace.

=== ext:memory parameter-text ===
New note, or exact existing note for forget (don't add a date).

=== ext:memory search-description ===
Search current global and project notes with case-insensitive keywords; all terms must match. No session history or semantic search.

=== ext:memory snippet ===
Save durable preferences and verified project lessons for future sessions

=== ext:memory startup-overflow ===
{{warning}} Only a bounded prefix is loaded here; memory list/search can retrieve all stored notes.

=== ext:memory startup-section ===
## {{scope}} ({{namespace}})

{{notes}}

=== ext:memory system-context ===
# Learned memory

{{guidance}}

{{notes}}

=== ext:permissions read-mode-entered ===
Read mode is on. Investigate and answer without changing anything: edit and write are blocked, and bash commands that write or cannot be classified as read-only need the user's approval.

=== ext:permissions read-mode-left ===
Read mode is off. Changes are allowed again under the usual permission rules.

=== ext:questionnaire answers-preamble ===
I answered your questions in the following way:

=== ext:questionnaire extraction-system ===
You are a question extractor. Given text from a conversation, extract any questions that need answering.

Output a JSON object with this structure:
{
  "questions": [
    {
      "question": "The question text",
      "context": "Optional context that helps answer the question"
    }
  ]
}

Rules:
- Extract all questions that require user input
- Keep questions in the order they appeared
- Be concise with question text
- Include context only when it provides essential information for answering
- If no questions are found, return {"questions": []}

Example output:
{
  "questions": [
    {
      "question": "What is your preferred database?",
      "context": "We can only configure MySQL and PostgreSQL because of what is implemented."
    },
    {
      "question": "Should we use TypeScript or JavaScript?"
    }
  ]
}

=== ext:questionnaire option-description-description ===
Optional description shown below label

=== ext:questionnaire option-label-description ===
Display label for the option

=== ext:questionnaire option-value-description ===
The value returned when selected

=== ext:questionnaire question-allow-other-description ===
Allow 'Type something' option (default: true)

=== ext:questionnaire question-id-description ===
Unique identifier for this question

=== ext:questionnaire question-label-description ===
Short contextual label for tab bar, e.g. 'Scope', 'Priority' (defaults to Q1, Q2)

=== ext:questionnaire question-options-description ===
Available options to choose from

=== ext:questionnaire question-prompt-description ===
The full question text to display

=== ext:questionnaire questions-description ===
Questions to ask the user

=== ext:questionnaire tool-description ===
Ask the user one or more questions. Use for clarifying requirements, getting preferences, or confirming decisions. For single questions, shows a simple option list. For multiple questions, shows a tab-based interface.

=== ext:subagents evidence-auditor ===
Independently audit the decision-critical claims in the assigned research.
Use Vresto fetch, expand and targeted search through codemode to inspect
original sources. A citation or generated summary is not proof. Report
supported, contradicted and unsupported claims with URLs, uncertainty
and implications. Keep the audit bounded to claims that affect the conclusion.

=== ext:subagents researcher ===
Research the assigned question using Vresto search, fetch and expand.
Inspect available tools through codemode. Prefer primary sources;
search snippets and generated research answers are discovery, not evidence.
Fetch sources for material claims. Return a concise brief with source URLs,
distinguish verified facts from inference, and report contradictions and gaps.

=== ext:todo beads-guidance ===
# Beads

Track durable work in beads (`bd`); use todos for steps inside the claimed ticket. Add `--json` when parsing output.

## Ownership

- `BEADS_ACTOR` identifies this session and its subagents as one team. Preserve that identity.
- Inspect assignee/status before claiming with `bd update <id> --claim`. Continue existing team claims; never take another actor's live claim. Helpers retain the parent's claim unless explicitly assigned a separate ticket.
- Record out-of-scope discoveries as separate tickets, checking for duplicates first. Create them implementation-ready when understood, otherwise with `needs-context`. Discovery does not authorize expanding the current task.
- Durable facts go to memory; bd's `remember` and `prime` stay unused.
- Sync (`bd dolt push`/`pull`) and beads configuration changes require a user request.

## Readiness

| Status / label | Meaning |
| --- | --- |
| `open`, no routing label | Ready for implementation, subject to dependencies |
| `open` + `needs-context` | Ready for an agent to flesh out |
| `blocked` + `needs-info` | Needs essential information or a decision unavailable to the agent |
| `open` + `human` | Requires human execution |
| `in_progress` | Claimed for contextualization or implementation |
| `closed` + `wontfix` | Deliberately declined |

A title-only capture is valid with `needs-context`. This means insufficient description, scope, or understanding—not mandatory internet research or human approval. Routine implementation exploration needs no special label.

Select authorized work from `bd ready --exclude-type epic --exclude-label human`. General work may include either queue; implementation-only selection adds `--exclude-label needs-context`, while contextualization selects tickets
bearing that label.

For `needs-context`, claim the ticket and inspect relevant code, docs, and evidence. Record the problem or intended outcome, scope, acceptance criteria, and useful implementation pointers. Distinguish facts from hypotheses; ask
the user only for essential missing intent or information.

When ready, remove `needs-context`. Continue authorized implementation under the claim, or return to `open` and clear your own assignee for handoff. If essential input is unavailable, replace the label with `needs-info`, set
`blocked`, and record the exact question. Restore readiness when answered. Preserve genuine dependency blockers. Preparing a ticket does not complete it.

Include legacy `needs-triage` tickets when scanning for contextualization work, even if blocked. When taking one up, replace the label with `needs-context` and clear only triage-related blocking; preserve genuine blockers and
others' claims.

## Engineering skills

This is the tracker configuration for engineering skills; it replaces the intentionally absent `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`. Skip `/setup-matt-pocock-skills`.

Map skill roles: `ready-for-agent` → implementation-ready; `ready-for-human` → `human`; `needs-triage` → `needs-context`.

- Specs are epics; children use `--parent <spec-id>`. Labels inherit unless `--no-inherit-labels`; ensure readiness labels fit each child.
- Fetch context with `bd show <id> --json --include-comments`.
- Record blockers with dependencies (`--deps` or `bd dep add`).
- Close completed work with `bd close <id> -r "<reason>"`. Work lands on the branch without PRs.

## Wayfinding

Find maps with `bd list -t epic -l wayfinder:map`; map notes hold Decisions-so-far. Children use `--parent <map> --no-inherit-labels -l wayfinder:<type>` (`research`, `prototype`, `grilling`, `task`).

Select the first ticket from `bd ready --parent <map>`, applying readiness rules before implementation. On resolution, comment the answer, close the child, and append the gist and child ID to the map's notes.

=== ext:todo description ===
Track multi-step work as a task list. Send the complete list every time: it replaces the stored one, and omitted tasks are dropped. One call can create, reorder, update, and drop tasks at once.

=== ext:todo guideline-replace ===
Every todo call replaces the whole list: resend every task you still want and omit a task only when you mean to drop it.

=== ext:todo guideline-status ===
Keep at most one task in_progress; set each status explicitly, including completed when its work is done.

=== ext:todo guideline-when ===
Use todo for work with 3+ steps or when the user hands you a list of tasks; skip it for trivial single-step and conversational requests.

=== ext:todo parameter-subject ===
Short imperative task line, e.g. 'Add the parser test'.

=== ext:todo parameter-tasks ===
The complete task list. It replaces the stored one, so omitted tasks are dropped.

=== ext:todo snippet ===
Track multi-step work as a task list
