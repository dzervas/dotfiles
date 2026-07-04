// The classification pipeline. Each classifier appends findings to the
// subject; the decision engine (decide.ts) turns findings into ask/deny
// outcomes.
//
// This is the seam for command safety classification models. The local LLM
// classifier is opt-in and advisory-only for now: it records a proposed
// action/confidence for UI display, but the decision engine does not trust or enforce it.

import type { Classifier, PermissionSubject } from "../types";
import { classifyBash } from "./bash";
import { classifyWithLocalLlm } from "./local-llm";

const CLASSIFIERS: Classifier[] = [
	classifyBash,
	// Trusted safety model classifiers can be added here later.
];

export async function classify(
	subject: PermissionSubject,
	options: { signal?: AbortSignal; localLlm?: boolean } = {},
): Promise<PermissionSubject> {
	for (const classifier of CLASSIFIERS) subject.findings.push(...(await classifier(subject)));
	if (options.localLlm) await classifyWithLocalLlm(subject, options.signal);
	return subject;
}

// TODO: Handle batch execute:
// ctx_batch_execute
//   commands: [{"label":"extract-host","command":"curl -s 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/server/forge/common/utils.go' | grep -nA15 'func ExtractHostFromCloneURL'"},{"label":"clone-override-search","command":"curl -s
// 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/server/forge/forgejo/forgejo.go' | grep -nE 'opts.URL|c.url|CloneURL|r.Clone|Clone =|cloneURL' "},{"label":"any-clone-env","command":"curl -s
// 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/cmd/server/flags.go' | grep -niE 'clone|forgejo-url|forge.*url' | head -40"}]
//   queries: ["ExtractHostFromCloneURL implementation","clone URL override environment variable","forgejo url flag definition"]
//   concurrency: 3
