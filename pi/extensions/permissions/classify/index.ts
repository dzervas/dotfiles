// The classification pipeline. Each classifier appends findings to the
// subject; the decision engine (decide.ts) turns findings into ask/deny
// outcomes.
//
// This is the seam for the upcoming command safety classification model:
// add it as another Classifier here. It can vouch for "unknown"-verdict
// findings (unrecognized commands) but must never override "unsafe" ones.

import type { Classifier, PermissionSubject } from "../types";
import { classifyBash } from "./bash";

const CLASSIFIERS: Classifier[] = [
	classifyBash,
	// safetyModelClassifier, ← future command safety model slots in here
];

export async function classify(subject: PermissionSubject): Promise<PermissionSubject> {
	for (const classifier of CLASSIFIERS) subject.findings.push(...(await classifier(subject)));
	return subject;
}

// TODO: Handle batch execute:
// ctx_batch_execute
//   commands: [{"label":"extract-host","command":"curl -s 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/server/forge/common/utils.go' | grep -nA15 'func ExtractHostFromCloneURL'"},{"label":"clone-override-search","command":"curl -s
// 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/server/forge/forgejo/forgejo.go' | grep -nE 'opts.URL|c.url|CloneURL|r.Clone|Clone =|cloneURL' "},{"label":"any-clone-env","command":"curl -s
// 'https://raw.githubusercontent.com/woodpecker-ci/woodpecker/main/cmd/server/flags.go' | grep -niE 'clone|forgejo-url|forge.*url' | head -40"}]
//   queries: ["ExtractHostFromCloneURL implementation","clone URL override environment variable","forgejo url flag definition"]
//   concurrency: 3
