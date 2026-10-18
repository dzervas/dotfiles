import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { getSettingsListTheme } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, SettingsList, truncateToWidth, type SettingItem } from "@earendil-works/pi-tui";
import { withHumanInput } from "../lib/human-input.ts";
import type { Note, Scope } from "./store.ts";

export interface MemoryPage {
	namespace: string;
	notes: Note[];
}

export interface MemoryPanelStore {
	read(scope: Scope): Promise<MemoryPage>;
	mutate(scope: Scope, action: "remember" | "replace" | "forget", text: string, previous?: string): Promise<{ notes: Note[]; warning?: string }>;
}

type Selection = { scope: Scope } | { note?: Note } | undefined;

/** A settings-style browser; storage and startup-context policy belong to the caller. */
export async function showMemoryPanel(
	pi: Pick<ExtensionAPI, "events">,
	ctx: ExtensionCommandContext,
	store: MemoryPanelStore,
): Promise<void> {
	if (ctx.mode !== "tui") {
		ctx.ui.notify("/mem requires TUI mode", "error");
		return;
	}

	await withHumanInput(pi, async () => {
		let scope: Scope = "project";
		let page: MemoryPage;
		try {
			page = await store.read(scope);
		} catch (error) {
			ctx.ui.notify(`Could not load memories: ${String(error)}`, "error");
			return;
		}

		while (true) {
			const selection = await ctx.ui.custom<Selection>((tui, theme, _kb, done) => {
				const items: SettingItem[] = [
					{
						id: "add",
						label: "Add memory",
						currentValue: "",
						description: "Save a new memory in this scope.",
						values: ["open"],
					},
					...page.notes.map((note, index) => ({
						id: String(index),
						label: note.date,
						currentValue: note.text,
						description: note.text,
						values: ["open"],
					})),
				];
				const list = new SettingsList(
					items,
					Math.min(items.length, 12),
					getSettingsListTheme(),
					(id) => done(id === "add" ? {} : { note: page.notes[Number(id)] }),
					() => done(undefined),
				);
				return {
					render(width: number) {
						const tabs = scope === "project" ? "[Project]  Global" : "Project  [Global]";
						return [
							truncateToWidth(theme.fg("accent", `Memory · ${tabs}`), width),
							truncateToWidth(theme.fg("muted", page.namespace), width),
							"",
							...list.render(width),
							truncateToWidth(theme.fg("dim", "Tab/←/→ switch scope · ↑/↓ select · Enter open · Esc close"), width),
						];
					},
					invalidate: () => list.invalidate(),
					handleInput(data: string) {
						if (matchesKey(data, Key.tab) || matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left) || matchesKey(data, Key.right)) {
							done({ scope: scope === "project" ? "global" : "project" });
						} else {
							list.handleInput(data);
							tui.requestRender();
						}
					},
				};
			});
			if (!selection) return;
			if ("scope" in selection) {
				try {
					const next = await store.read(selection.scope);
					scope = selection.scope;
					page = next;
				} catch (error) {
					ctx.ui.notify(`Could not load memories: ${String(error)}`, "error");
				}
				continue;
			}

			const note = selection.note;
			const action = note ? await ctx.ui.select("Memory", ["Edit", "Forget"]) : "Add";
			if (!action) continue;
			const text = action === "Forget" ? note!.text
				: action === "Edit" ? await ctx.ui.editor("Edit memory", note!.text)
				: await ctx.ui.input("Add memory");
			if (text === undefined) continue;

			try {
				const result = await store.mutate(
					scope,
					action === "Forget" ? "forget" : action === "Edit" ? "replace" : "remember",
					text,
					action === "Edit" ? note!.text : undefined,
				);
				page = { ...page, notes: result.notes };
				if (result.warning) ctx.ui.notify(result.warning, "warning");
			} catch (error) {
				ctx.ui.notify(`Could not save memory: ${String(error)}`, "error");
				// Another writer may have changed the selected note while it was open.
				try { page = await store.read(scope); } catch { /* keep the last readable list */ }
			}
		}
	});
}
