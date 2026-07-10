# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Better bash tool calls

- Avoid using environment variables for simple path substitution
- Prefer the built-in read/ls/grep/edit tools instead of bash commands
- Prefer ripgrep over grep
- Prefer the read tool with offset & limit instead of sed

## Subagent Model Selection

When delegating via the `subagent` tool, pick the `model` arg by matching task
difficulty to cost — do NOT just inherit the parent model. Prefer delegating over
doing everything inline when a task is parallelizable, isolatable, or benefits from
a fresh/independent context. Available models, cheapest/most-abundant first:

- **gpt-5.5** — DEFAULT workhorse. Cheap, abundant sub, strong at coding and long
  multi-step workflows. Use for the bulk of delegated work: recon, research,
  routine implementation, and anything run in parallel or high volume.
- **claude-sonnet-5** — If gpt is out of tokens and the work is simple enough,
  use it. It's dumber than gpt but good enough for recon/summaries/etc.
- **claude-opus-4-8** — Similar model to GPT but harsh limits.
- **claude-fable-5** — Last resort, hardest ceiling. Most capable model, for the
  most ambitious long-horizon work only.

**Quality over tokens:** if a result isn't good enough, escalate to a stronger
model and retry. Saving tokens is never worth a bad result — quality is always
preferred over token cost.


## Subagent Usage

- Use `delegate` for arbitrary one-off subagent instructions. The named agents
  (`scout`, `reviewer`, `worker`, etc.) are role presets; they are not the only
  delegation path. Prefer `delegate` when the task does not fit a preset.
- When launching subagents, explicitly choose a model based on task difficulty
  instead of blindly inheriting the parent model. Use cheaper/default models for
  simple recon, summaries, and small delegated tasks; use stronger models for
  complex planning, implementation, or adversarial review.
