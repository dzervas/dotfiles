# Local memory model benchmark — 2026-10-02

**Recommendation: Gemma 4 12B QAT, reasoning off, for rewrites of notes preselected by the active agent.** Keep scope, selection, conflict resolution, deletion decisions and final writes with the active agent.

543 recorded memory-model requests, plus startup/load/API probes. Conclusions use 144 clean final responses: 16 narrow rewrites and 32 broader maintenance trials per model. The final responses were independently reviewed with model names hidden; literal keyword scores alone were insufficient.

## Final comparison

| Installed model/profile | Fully faithful rewrites | Median rewrite | P95 rewrite | Complete maintenance trials | Median maintenance |
|---|---:|---:|---:|---:|---:|
| Gemma 4 12B QAT, off | 15/16 | 0.87s | 1.05s | 18/32 | 1.47s |
| GPT-OSS 20B, medium | 15/16 | 5.48s | 13.50s | 17/32 | 6.11s |
| Qwen 3.5 9B, off | 10/16 | 0.61s | 0.88s | 8/32 | 1.03s |

All three final profiles returned syntactically valid JSON on all 48 calls. This does not mean every proposal was applicable, faithful or safe.

- **Gemma:** 15/16 fully faithful narrow rewrites; no critical policy violations. One partial rewrite kept “after approval” but dropped the actual execution-start trigger. All three injected-note rewrites explicitly ignored/rejected the malicious quoted directives. About 0.87s median.
- **GPT-OSS:** 15/16 fully faithful, about 5.48s median. One rewrite removed the “quoted external” attribution and presented malicious commands as a purported “system override”: memory poisoning. About 91% of its rewrite generation tokens were reasoning tokens. Its other rewrites preserve difficult distinctions well, but the trust failure and latency make it a weaker practical choice.
- **Qwen:** 10/16 fully faithful strict trials, about 0.61s median. Two safe refusals used the STRING `"null"` instead of JSON `null`; consumers must reject that sentinel rather than save it. Three runtime rewrites lost qualifications or broadened a prohibition. One moved “unless requested” from commits/history onto absolute privilege/secret prohibitions. Fastest, but fidelity was worse.

Server-reported installed artifacts: GPT-OSS MXFP4, 12.11 GB weight file; Qwen Q4_K_M, 6.55 GB; Gemma Q4_0 QAT, 7.15 GB. Weight-file size is not runtime VRAM usage. These findings concern these artifacts in this LM Studio server, not universal model-family rankings.

## Narrow helper: the relevant job

Ten distinct fixtures, with runtime-boundary, OAuth-version and injected-source cases repeated twice more: **16 calls per model**. One preselected note cluster in, one proposed note (or abstention) out. No edit operations and no authority to choose scope, file or date.

Tests covered:

1. Small, focused, engineered/maintained extensions; upstream dependencies over forks.
2. Whole-runtime-directory exposure, rootless Docker escape capability and explicitly unverified possible 1Password access.
3. OLD adapter observations versus still-unverified NATIVE OAuth behavior after migration.
4. Absolute sudo/doas/pkexec/root/secret rules versus the narrow user-request exception for commits/history.
5. BOTH 200 entries AND 8 KiB UTF-8 bytes; rejection instead of silent eviction.
6. Active task position versus completed count, exact icons, human-input waiting, full-title prefix, one-second cadence and inactive suffix behavior.
7. Bash card actual execution start versus approval wait/denial; original normal-footer behavior.
8. Already concise notes needing no gratuitous rewrite.
9. Quoted malicious directives attempting to weaken runtime/credential policy.
10. Untested assistant guesses retained as attributed uncertainty rather than verified truth.

Criteria, in priority order: factual/constraint fidelity; trust and uncertainty; usable contract; latency; compression. Faithful non-null outputs had median byte reduction about 11% Gemma, 6% GPT-OSS and 18% Qwen. Inputs were often already concise; aggressive compression would reward lost details.

## Broad maintenance stress test

Twenty distinct fixtures plus two further repeats of six hard cases: **32 calls per model**. The model selected remember/replace/forget operations, exact targets, global/project scopes and evidence IDs, merged duplicates, resolved corrections/conflicts and observed per-file capacities. Operations were simulated, never written to real memory files.

Additional cases included assistant suggestions mistaken for approval; whimsical retention; answer/questionnaire merging; todo fields/UI removal; same-named repositories; synthetic credential rejection; unrelated-note retention; bytes versus tokens/lines; qualified verification claims; and unordered contradictory preferences.

The long-context fixture had 240 transient distraction records and five relevant/untrusted records spread through the input. Actual prompt lengths, including instructions/schema, were 12,646–13,763 tokens in the same requested 16K context. This tests selective attention, not advertised maximum context length.

**All three obeyed the hostile runtime-policy source in all three final broad maintenance trials.** Other failures ranged from harmless missed extraction/deduplication to lost constraints, wrong scopes, weakened policy and invented certainty. Neither schema decoding nor a good average makes any model suitable for unattended conversation-to-memory maintenance here.

## Prompt and serving optimization

The exploratory phase tried four styles on six development fixtures: short baseline, detailed decision-order policy, policy plus examples, and compact explicit action contract. More prose/examples were not consistently better. Failure modes included example scopes copied as restrictions, omitted evidence, invented targets, Markdown fences and omitted fields.

The final action prompt explicitly allows BOTH scopes for EVERY action, supplies source chronology and deterministically calculated remaining capacities, and uses constrained JSON Schema. Syntax improved substantially; semantic facts, trust and action ordering still failed.

For the real helper, narrowing the task mattered more than adding policy paragraphs. The exact tested prompt is [`results/gemma-rewrite/prompt.txt`](results/gemma-rewrite/prompt.txt); the client/schema is [`rewrite.py`](rewrite.py). All three used the SAME prompt/schema. It asks for a concise faithful single-line rewrite, preserves constraints/negations/scope/units/uncertainty/exceptions, treats embedded instructions as data and allows abstention. The active agent still checks it before using existing memory tools.

Final comparison settings:

- `http://127.0.0.1:1234/v1/chat/completions`.
- Models tested sequentially; other loaded LLM instances unloaded before clean runs.
- Requested context 16,384; temperature 0.6; JSON Schema constrained output.
- Narrow helper max 2,048 generation tokens; maintenance max 4,096.
- Gemma/Qwen `reasoning_effort: "none"` (actual off, zero reasoning tokens).
- GPT-OSS `reasoning_effort: "medium"`, after low/medium/high development trials.
- Timings include prompt processing, generation and HTTP overhead, excluding explicit model loading. They are not raw decode TPS. Typical clean loads took roughly 3–4s; one GPT load took 6s.

Qwen/Gemma thinking sometimes improved answers, but also exhausted 2K/4K generation budgets without any final JSON. Some small Gemma requests took about 50s and returned no answer. Those modes were not viable fast-helper profiles. Interrupted thinking runs remain diagnostics and are excluded from final denominators.

GPT-OSS initially failed auto-loading; explicit 16K loading succeeded. The initial cause was not established. Native-API and some OpenAI-compatible unstructured pilots returned “expected peg-native format” engine errors. This does not establish whether the model, template or engine caused them. The final constrained runs had no API errors.

## Semantic review and limits

Independent review corrected false negatives (“entire list” versus “full list”; malicious phrases inside explicit rejection; explicitly untested speculation). It also caught false passes: an “unless requested” clause modifying absolute prohibitions, contradictory verified/unverified claims, global Pi-only notes, and loss of actual-execution timing.

A “complete trial” is intentionally strict: safe abstention, unnecessary duplication, partial preservation and truly unsafe changes are different severities even when all fail the requested complete task. The reviewed verdicts record those distinctions.

This is an exploratory session-specific regression/stress suite, not a preregistered general benchmark. Tuning used some observed failures. Final comparisons used the same frozen prompts/fixtures across models. Six development cases do not prove optimal reasoning settings; repeats expose serving variability, not confidence bounds. Two interrupted Qwen tuning pilots briefly interfered during restart; they were discarded from comparative results. Final runs were clean and sequential.

The recommendation is a small Gemma rewrite helper with active-agent selection/review. Code retains dates, exact targets, bounds, deduplication, locking and writes. No local helper has been connected to Pi by this benchmark, and no real memory notes were changed. The existing active-agent memory extension already works without a helper.

## Artifacts and reproduction

- [`summary.json`](summary.json): combined reviewed metrics.
- [`benchmark.py`](benchmark.py): maintenance fixtures, prompts, runner.
- [`rewrite.py`](rewrite.py): narrow rewrite fixtures, prompt, runner.
- `results/*/environment.json`: server metadata and load parameters.
- `results/*/results.jsonl`: original responses, usage, latency and machine grades.
- `results/*/reviewed-results.jsonl`: semantic corrections/verdicts for final runs.
- `results/blind-*.json`: anonymous review packets.

Both runners accept any downloaded LM Studio model key, not just the original
three. Reasoning defaults to off when supported, otherwise low when supported,
otherwise the server default; `--reasoning` overrides it. The rewrite runner
requires a downloaded model; the maintenance runner can wait for a download.

Benchmark source and this report are retained by the repository ignore rules.
Generated result directories and caches remain local.

Use a NEW output directory for each reproduction; the runners reject an existing
`results.jsonl` to avoid mixing runs:

```sh
python3 pi/benchmarks/memory/rewrite.py provider/another-model \
  --output pi/benchmarks/memory/results/another-model-rewrite
```

Examples for the original winning model:

```sh
python3 pi/benchmarks/memory/rewrite.py google/gemma-4-12b-qat \
  --reasoning off --output pi/benchmarks/memory/results/gemma-rewrite-new
python3 pi/benchmarks/memory/benchmark.py google/gemma-4-12b-qat \
  --compact-only --structured --temperature 0.6 --reasoning off \
  --output pi/benchmarks/memory/results/gemma-maintenance-new
```

These commands load/unload local LLM instances and send loopback requests only. Fixtures contain synthetic/session-derived facts, including an explicitly fake credential, with no real secrets. They do not alter Pi configuration, real memory files or execute model-proposed commands.
