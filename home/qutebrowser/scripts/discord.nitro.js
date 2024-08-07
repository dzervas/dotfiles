// ==UserScript==
// @name         Disable Nitro nagging
// @version      1.0
// @description  Marks the user locally as premium to avoid all the nitro nagging (doesn't enable any feature in reality)
// @author       me
// @match        https://discord.com/channels*
// @match        https://discord.com/app*
// @grant        none
// ==/UserScript==

function loader() {
	let wpRequire;
	console.log("Injecting to discord webpack")
	webpackChunkdiscord_app.push([[Symbol()], {}, r => wpRequire = r.c]);
	webpackChunkdiscord_app.pop();

	console.log("Searching for the getUsers module")
	const getUsers = Object
		.values(wpRequire)
		.find(x => x?.exports?.default?.getUsers)
		.exports.default;

	window.wpRequire = wpRequire;
	window.getUsers = getUsers;

	getUsers.addChangeListener(() => {
		// console.log("getUsers store changed:", this);
		console.log("Activating premium", window.getUsers.getCurrentUser())
		getUsers.getCurrentUser().premiumType = 2;
	});
	// let m = Object.values(u._dispatcher._actionHandlers._dependencyGraph.nodes);
}

document.addEventListener("readystatechange", (event) => {
	if (document.readyState === "complete")
		loader();
});
