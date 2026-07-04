// Thin entry point: pi loads top-level extension files. The implementation
// lives in permissions/ — start reading at permissions/types.ts, then follow
// the pipeline: subject.ts → classify/ → decide.ts → ask.ts.

export { PERMISSIONS_ASK_EVENT, type PermissionAskRequest } from "./permissions/ask";
export type { PermissionSubject } from "./permissions/types";
export { default } from "./permissions/extension";
