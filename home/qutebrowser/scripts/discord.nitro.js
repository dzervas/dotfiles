// ==UserScript==
// @name         Discord Free Nitro Features
// @namespace    https://github.com/return-true-if-false/discord-free-nitro-features
// @homepage     https://github.com/return-true-if-false/discord-free-nitro-features
// @version      1.0
// @description  Allows you to use nitro emojis, stickers, and splits large messages in two
// @author       return-true-if-false
// @match        https://discord.com/channels*
// @match        https://discord.com/app*
// @grant        none
// ==/UserScript==
let z

function loader() {
    window.webpackChunkdiscord_app.push([
        [Math.random()], {},
        e => {
            console.log("Loaded webpackChunkdiscord_app");
            window.wpRequire = e
        }
    ]);
    console.log("Loading webpackChunkdiscord_app");

    let e = () => Object.keys(wpRequire.c).map((e => wpRequire.c[e].exports)).filter((e => e)),
        t = t => {
            for (const n of e()) {
                if (n.default && t(n.default)) return n.default;
                if (n.Z && t(n.Z)) return n.Z;
                if (t(n)) return n
            }
        },
        n = t => {
            let n = [];
            for (const s of e()) s.default && t(s.default) ? n.push(s.default) : t(s) && n.push(s);
            return n
        },
        s = (...e) => t((t => e.every((e => void 0 !== t[e])))),
        a = (...e) => n((t => e.every((e => void 0 !== t[e])))),
        r = e => new Promise((t => setTimeout(t, e)));
    if (!s("getCurrentUser").getCurrentUser()) {
        return
    } else {
        clearInterval(z)
    }
    s("getCurrentUser").getCurrentUser().premiumType = 2;
    console.log("UserScript loaded");

    console.log("Current user:", s("getCurrentUser").getCurrentUser());
}
z = setInterval(loader, 100)
