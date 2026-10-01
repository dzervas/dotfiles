import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const HUMAN_INPUT_EVENT = "human-input:waiting";
export type HumanInputEvent = { id: symbol; waiting: boolean };

/** Mark only the dialog's lifetime, including cancellation and failures. */
export async function withHumanInput<T>(
	pi: Pick<ExtensionAPI, "events">,
	show: () => Promise<T>,
): Promise<T> {
	const id = Symbol("human-input");
	pi.events.emit(HUMAN_INPUT_EVENT, { id, waiting: true } satisfies HumanInputEvent);
	try {
		return await show();
	} finally {
		pi.events.emit(HUMAN_INPUT_EVENT, { id, waiting: false } satisfies HumanInputEvent);
	}
}
