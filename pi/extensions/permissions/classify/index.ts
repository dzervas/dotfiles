import type { PermissionSubject } from "../types";
import { classifyBash } from "./bash";

export async function classify(subject: PermissionSubject): Promise<PermissionSubject> {
	subject.findings.push(...(await classifyBash(subject)));
	return subject;
}
