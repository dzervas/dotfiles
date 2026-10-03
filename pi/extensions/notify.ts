/**
 * https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/examples/extensions/notify.ts
 * Pi Notify Extension
 *
 * Rings the terminal bell and sends a native notification when a dialog needs input
 * or the Pi agent is done.
 * Supports multiple terminal protocols:
 * - OSC 777: Ghostty, iTerm2, WezTerm, rxvt-unicode
 * - OSC 99: Kitty
 * - Windows toast: Windows Terminal (WSL)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { HUMAN_INPUT_EVENT, type HumanInputEvent } from "./lib/human-input.ts";

function windowsToastScript(title: string, body: string): string {
	const type = "Windows.UI.Notifications";
	const mgr = `[${type}.ToastNotificationManager, ${type}, ContentType = WindowsRuntime]`;
	const template = `[${type}.ToastTemplateType]::ToastText01`;
	const toast = `[${type}.ToastNotification]::new($xml)`;
	return [
		`${mgr} > $null`,
		`$xml = [${type}.ToastNotificationManager]::GetTemplateContent(${template})`,
		`$xml.GetElementsByTagName('text')[0].AppendChild($xml.CreateTextNode('${body}')) > $null`,
		`[${type}.ToastNotificationManager]::CreateToastNotifier('${title}').Show(${toast})`,
	].join("; ");
}

function notifyOSC777(title: string, body: string): void {
	process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
}

function notifyOSC99(title: string, body: string): void {
	// Kitty OSC 99: i=notification id, d=0 means not done yet, p=body for second part
	process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
	process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
}

function notifyWindows(title: string, body: string): void {
	const { execFile } = require("child_process");
	execFile("powershell.exe", ["-NoProfile", "-Command", windowsToastScript(title, body)]);
}

function notify(title: string, body: string): void {
	// The BEL terminating an OSC sequence does not ring the terminal bell.
	process.stdout.write("\x07");
	if (process.env.WT_SESSION) {
		notifyWindows(title, body);
	} else if (process.env.KITTY_WINDOW_ID) {
		notifyOSC99(title, body);
	} else {
		notifyOSC777(title, body);
	}
}

export default function (pi: ExtensionAPI) {
	let interactive = false;

	pi.on("session_start", (_event, ctx) => {
		interactive = ctx.mode === "tui";
	});

	pi.events.on(HUMAN_INPUT_EVENT, (value) => {
		const event = value as HumanInputEvent;
		if (interactive && event.waiting) notify("Pi", "Input required");
	});

	pi.on("session_shutdown", () => {
		interactive = false;
	});

	pi.on("agent_settled", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		notify("Pi", "Ready for input");
	});
}
