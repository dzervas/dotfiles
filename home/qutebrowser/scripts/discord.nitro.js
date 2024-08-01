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
            window.wpRequire = e
        }
    ]);
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
    let i = s("sendMessage");
    i.__sendMessage = i.__sendMessage || i._sendMessage, i._sendMessage = async function(e, t, n) {
        if (t?.validNonShortcutEmojis?.forEach((e => {
                t.content = t.content.replaceAll(new RegExp("<(a|):" + (e.originalName || e.name) + ":" + e.id + ">", "g"), e.url)
            })), n && (n?.stickerIds?.forEach((e => {
                t.content = t.content + "https://media.discordapp.net/stickers/" + e + ".webp?size=160"
            })), n = {
                ...n,
                stickerIds: undefined
            }), t.content.length > 2e3) {
            let a = t.content.split(/([\S\s]{1,2000})/g);
            if (a[1].match(/```/g)?.length % 2 !== 0 && a[3].length <= 1980) {
                let e = a[1];
                a[1] = e.substring(0, 1997) + "```";
                let t = a[1].match(/```[^\n ]+/g);
                t = t[t.length % 2 === 0 ? t.length - 2 : t.length - 1].replace("```", "");
                let n = "```";
                a[3].match(/```/g)?.length >= 1 && a[3].match(/```/g)?.length % 2 !== 0 && (n = ""), a[3] = "```" + t + "\n" + e.substring(1997, 2e3) + a[3] + n
            }
            let l = s("getCachedChannelJsonForGuild").getChannel(e).rateLimitPerUser;
            await i.__sendMessage.bind(i)(e, {
                ...t,
                content: a[1]
            }, n);
            let o = !1;
            for (; !o;) {
                await r(l);
                let s = i.__sendMessage.bind(i)(e, {
                    ...t,
                    content: a[3]
                }, n).catch((e => {
                    l = 1e3 * e.body.retry_after, o = !1
                }));
                if (s = await s, s?.ok) return await s
            }
        }
        return await i.__sendMessage.bind(i)(e, t, n)
    };
}
z = setInterval(loader, 100)
