import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";

const CUSTOM_TYPE = "jj-undo";
const JJ_CONFIG_ARGS = ["--config", "signing.backend=none"];
const JJ_TIMEOUT_MS = 30_000;

type CheckpointData = {
	version: 1;
	kind: "checkpoint";
	checkpointId: string;
	operationId: string;
	leafId: string | null;
	createdAt: string;
};

type UndoData = {
	version: 1;
	kind: "undo";
	checkpointId: string;
	fromOperationId: string;
	toOperationId: string;
	fromLeafId: string | null;
	toLeafId: string | null;
	createdAt: string;
};

type JjUndoData = CheckpointData | UndoData;

type StoredCheckpoint = CheckpointData & {
	entryId: string;
};

function notify(ctx: ExtensionContext, message: string, type: "info" | "warning" | "error") {
	if (ctx.hasUI) ctx.ui.notify(message, type);
}

function makeCheckpointId(): string {
	return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

function shortOperation(operationId: string): string {
	return operationId.slice(0, 12);
}

function commandError(action: string, result: { stdout: string; stderr: string; code: number }): Error {
	const output = (result.stderr || result.stdout).trim();
	return new Error(output || `${action} failed with exit code ${result.code}`);
}

function isJjUndoData(data: unknown): data is JjUndoData {
	if (!data || typeof data !== "object") return false;
	const value = data as Partial<JjUndoData>;
	return value.version === 1 && (value.kind === "checkpoint" || value.kind === "undo");
}

function removeCheckpoint(stack: StoredCheckpoint[], checkpointId: string): void {
	for (let i = stack.length - 1; i >= 0; i--) {
		if (stack[i]?.checkpointId === checkpointId) {
			stack.splice(i, 1);
			return;
		}
	}
}

function latestCheckpoint(ctx: ExtensionContext): StoredCheckpoint | undefined {
	const stack: StoredCheckpoint[] = [];

	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || entry.customType !== CUSTOM_TYPE || !isJjUndoData(entry.data)) {
			continue;
		}

		if (entry.data.kind === "checkpoint") {
			stack.push({ ...entry.data, entryId: entry.id });
		} else {
			removeCheckpoint(stack, entry.data.checkpointId);
		}
	}

	return stack.at(-1);
}

async function isJjRepo(pi: ExtensionAPI, cwd: string): Promise<boolean> {
	const result = await pi.exec("jj", ["--ignore-working-copy", "root"], {
		cwd,
		timeout: 5_000,
	});
	return result.code === 0;
}

async function runJj(pi: ExtensionAPI, cwd: string, args: string[]) {
	const result = await pi.exec("jj", [...JJ_CONFIG_ARGS, "--color", "never", ...args], {
		cwd,
		timeout: JJ_TIMEOUT_MS,
	});
	return result;
}

async function snapshotWorkingCopy(pi: ExtensionAPI, cwd: string): Promise<void> {
	const result = await runJj(pi, cwd, ["status"]);
	if (result.code !== 0) throw commandError("jj status", result);
}

async function currentOperation(pi: ExtensionAPI, cwd: string): Promise<string> {
	const result = await runJj(pi, cwd, [
		"--ignore-working-copy",
		"op",
		"log",
		"--no-graph",
		"-n1",
		"--template",
		"id",
	]);
	if (result.code !== 0) throw commandError("jj op log", result);

	const operationId = result.stdout.trim();
	if (!operationId) throw new Error("jj op log did not return an operation id");
	return operationId;
}

async function snapshotAndGetOperation(pi: ExtensionAPI, cwd: string): Promise<string> {
	await snapshotWorkingCopy(pi, cwd);
	return currentOperation(pi, cwd);
}

async function restoreOperation(pi: ExtensionAPI, cwd: string, operationId: string): Promise<void> {
	const result = await runJj(pi, cwd, ["op", "restore", operationId]);
	if (result.code !== 0) throw commandError(`jj op restore ${shortOperation(operationId)}`, result);
}

export default function jjUndo(pi: ExtensionAPI) {
	let jjQueue: Promise<void> = Promise.resolve();

	function withJjLock<T>(task: () => Promise<T>): Promise<T> {
		const result = jjQueue.then(task, task);
		jjQueue = result.then(
			() => undefined,
			() => undefined,
		);
		return result;
	}

	async function snapshotIfJjRepo(ctx: ExtensionContext): Promise<string | undefined> {
		const cwd = ctx.cwd;
		if (!(await isJjRepo(pi, cwd))) return undefined;
		return snapshotAndGetOperation(pi, cwd);
	}

	async function checkpointBeforeTurn(ctx: ExtensionContext): Promise<void> {
		await withJjLock(async () => {
			const operationId = await snapshotIfJjRepo(ctx);
			if (!operationId) return;

			pi.appendEntry<JjUndoData>(CUSTOM_TYPE, {
				version: 1,
				kind: "checkpoint",
				checkpointId: makeCheckpointId(),
				operationId,
				leafId: ctx.sessionManager.getLeafId() ?? null,
				createdAt: new Date().toISOString(),
			});
		});
	}

	async function lifecycleSnapshot(ctx: ExtensionContext, eventName: string): Promise<void> {
		try {
			await withJjLock(async () => {
				await snapshotIfJjRepo(ctx);
			});
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			notify(ctx, `[jj-undo] ${eventName}: ${message}`, "warning");
		}
	}

	async function undo(ctx: ExtensionCommandContext): Promise<void> {
		await ctx.waitForIdle();

		await withJjLock(async () => {
			const cwd = ctx.cwd;
			if (!(await isJjRepo(pi, cwd))) {
				notify(ctx, "jj undo: not a jj repo", "error");
				return;
			}

			const checkpoint = latestCheckpoint(ctx);
			if (!checkpoint) {
				notify(ctx, "jj undo: no agent turn checkpoint to restore", "warning");
				return;
			}

			const targetEntryId = checkpoint.leafId ?? checkpoint.entryId;
			if (!ctx.sessionManager.getEntry(targetEntryId)) {
				notify(ctx, `jj undo: session entry ${targetEntryId} no longer exists`, "error");
				return;
			}

			let currentOperationId: string;
			try {
				currentOperationId = await snapshotAndGetOperation(pi, cwd);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				notify(ctx, `jj undo: failed to snapshot current working copy: ${message}`, "error");
				return;
			}

			try {
				await restoreOperation(pi, cwd, checkpoint.operationId);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				notify(ctx, `jj undo: failed to restore ${shortOperation(checkpoint.operationId)}: ${message}`, "error");
				return;
			}

			const fromLeafId = ctx.sessionManager.getLeafId() ?? null;
			try {
				const result = await ctx.navigateTree(targetEntryId, { summarize: false });
				if (result.cancelled) {
					await restoreOperation(pi, cwd, currentOperationId);
					notify(ctx, "jj undo: conversation navigation was cancelled; restored repo state", "error");
					return;
				}
			} catch (error) {
				await restoreOperation(pi, cwd, currentOperationId);
				const message = error instanceof Error ? error.message : String(error);
				notify(ctx, `jj undo: conversation navigation failed; restored repo state: ${message}`, "error");
				return;
			}

			pi.appendEntry<JjUndoData>(CUSTOM_TYPE, {
				version: 1,
				kind: "undo",
				checkpointId: checkpoint.checkpointId,
				fromOperationId: currentOperationId,
				toOperationId: checkpoint.operationId,
				fromLeafId,
				toLeafId: checkpoint.leafId,
				createdAt: new Date().toISOString(),
			});

			notify(ctx, `jj undo: restored ${shortOperation(checkpoint.operationId)}`, "info");
		});
	}

	pi.on("session_start", async (_event, ctx) => lifecycleSnapshot(ctx, "session_start"));
	pi.on("before_agent_start", async (_event, ctx) => checkpointBeforeTurn(ctx));
	pi.on("agent_end", async (_event, ctx) => lifecycleSnapshot(ctx, "agent_end"));
	pi.on("session_shutdown", async (_event, ctx) => lifecycleSnapshot(ctx, "session_shutdown"));

	pi.registerCommand("undo", {
		description: "Restore jj and pi conversation state to before the previous agent turn",
		handler: async (_args, ctx) => undo(ctx),
	});
}
