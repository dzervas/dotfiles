---
name: course-check
description: Reassess open-ended work before an expensive commitment, after repeated inconclusive fixes, or when a credible alternative appears. Use when the user asks “why are we still stuck?”
---

Own the user's outcome, not the current implementation. The lead makes this
decision; individual workers need not repeat it.

1. Name the observable outcome and the current baseline. What would the user
   notice if this work succeeded? If the current milestone doesn't exercise
   the code, say which milestone does and why it needs attention now.

2. Compare continuing with the strongest alternative. That might be trying
   another implementation as-is, changing the hypothesis, or parking the
   work. When upstream matters, cite the last successful check, not the
   watcher's configured interval. Compare under the user's constraints.

3. Choose the cheapest observation that would change the decision. State
   what you expect under each explanation and what you'll do in either case.
   Prefer an existing trace or a small comparison over another patch. Give
   the experiment a budget in the scarce resource: runs, hours, or attention.

4. Decide: continue, switch, or park. After two attempts that move the
   symptom without explaining it, pause implementation. Resume when you
   have a test that distinguishes the remaining explanations. Parked work
   gets one concrete condition for reopening it.

Report briefly: what changed for the user; what we learned; what we should
do next and why. Use the existing ticket or conversation, not a new report.
