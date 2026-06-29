---
name: roguecore-ue4ss-mod
description: Build UE4SS Lua mods for Deep Rock Galactic Rogue Core (and DRG-family UE5 games). Use when the user wants to create, debug, or package a mod for RogueCore / Deep Rock Galactic that hooks game functions, reads/edits UObjects, modifies UI/menus, sorts/filters lists, or adds keybinds — covers SDK dumping, the FSD/RogueCore API surface, UE4SS Lua idioms, on-screen UI text, and distribution.
---

# RogueCore / DRG-family UE4SS Lua Modding

Build runtime Lua mods for **Deep Rock Galactic: Rogue Core** (codename/module **FSD**,
Unreal Engine **5.6.1**, by Ghost Ship Games) and the original Deep Rock Galactic. Both share
the `FSD` module, so the same patterns transfer. This skill is the distilled, battle-tested
workflow — generalize it for whatever mod is being built.

## When to use
- Creating a new RogueCore/DRG mod (UI tweak, list sort/filter, keybind action, value tweak, automation).
- Hooking a game `UFunction`, reading/writing reflected properties, or driving menu widgets.
- Debugging "my hook doesn't fire / value is empty / UI doesn't update / game crashed".
- Packaging a mod for end users.

## Environment facts (verify per-install, don't assume)
- Engine: UE 5.6.1 → **UE4SS experimental build required** (stable targets ≤5.4). Get it from
  https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental — use the `zDEV-` (dev) zip for dumping.
- Packaged Shipping build, no editor. Internal script package is `/Script/RogueCore` and
  `/Script/RogueCoreOnlineServices`; source-path fingerprints show `...\RR\RogueCore\Source\FSD\...`.
- The main pak is typically **unencrypted, classic v11, Oodle** — no AES key needed; `~mods`/`_P.pak`
  loadable. (Confirm by parsing the pak footer if pak work is needed.)
- No mod.io / in-game mod menu ships in RogueCore (stripped from DRG). Mods load via UE4SS or Mint.
- **No anti-cheat binaries** observed → injection is safe. Still: mods that change gameplay flag the
  lobby/save as modded; cosmetic/client-side mods don't. Never hide the modded flag.
- Host may be **Linux/Proton**: UE4SS proxy DLL needs Steam launch option
  `WINEDLLOVERRIDES="dwmapi=n,b" %command%`. Windows needs nothing.

## Standard workflow

### 1. Get an SDK dump (the source of truth)
Install the dev UE4SS into `<game>/Binaries/Win64/` (files sit next to the `-Shipping.exe`:
`dwmapi.dll`, `UE4SS.dll`, `UE4SS-settings.ini`, `ue4ss/Mods/...`). Launch, open the UE4SS console,
run **`dumpobjects`** (or "Dump CXX Headers"). Output lands at
`<game>/Binaries/Win64/ue4ss/UE4SS_ObjectDump.txt` (tens of MB, ~200k lines).

**CRITICAL: dump with the relevant UI/menu OPEN.** Menu widgets and their live instances only exist
in the dump if loaded at dump time. If a widget/function is "missing," re-dump with it on screen.

### 2. Mine the dump in a sandbox, never read it raw
It's huge — process it with code and print only what you need. Line format:
```
[ADDR] <Type> /Script/<Pkg>.<Class>:<Member> [o: OFFSET] [n:..] [pc:..] [ss:..] [em:..] [ai:..]
```
- `[o:]` = byte offset; `[pc:]` = ObjectProperty's pointed-to class; `[ss:]` = inner ScriptStruct;
  `[em:]` = enum; `[ai:]` = array inner. Resolve a pointer by finding the line `startswith('['+addr+']')`.
- Function params are `...:FuncName:ParamName` lines under the `Function` line (in declaration order).
- `/Game/...` paths are blueprint assets/instances; `/Script/...` are native.
- Find who CALLS a UFunction by grepping `CallFunc_<FuncName>` (appears in caller blueprints).

See `reference/dump_queries.py` for ready-made extraction snippets (signatures, struct fields,
callers, widget labels, live instances).

### 3. Map the API surface you need
Typical targets (RogueCore-confirmed examples — generalize):
- **Server list / lobbies:** `UFSDServerListLibrary:SortLobbies(WorldContext, Lobbies[], LobbiesStatus[],
  SortOrder, Reverse, KeepFriendsFirst, KeepJoinableFirst, SortedLobbies[], SortedLobbiesStatus[])`.
  `ServerListLobby` struct has `Classes` (`TArray<UPlayerCharacterID*>`), `NumPlayers`, `IsJoinable`,
  `IsClassLocked`, etc. Browser widget is `_MENU_ServerList_C` with `PopulateServerList` (calls
  SortLobbies) and `RefreshServerList` (no-arg refresh). `FSDServerlistClientRogueCore:GetLastFoundLobbies`.
- **Player/class:** `FSDPlayerController:GetFSDPlayerState`, `FSDPlayerState:GetSelectedCharacterID()`
  -> `UPlayerCharacterID*` (identify by `:GetFullName()` or `.AssetName`), `OnSelectedCharacterChanged`.
- **Refresh levers:** `FSDGameInstance:SetServerSearchActive(bool)` and client `ListLobbies()` —
  but these start a NEW network search that EMPTIES the list; prefer the widget's own `RefreshServerList()`.

### 4. Write the Lua mod
Layout: `<game>/Binaries/Win64/ue4ss/Mods/<ModName>/` containing `Scripts/main.lua` and an empty
`enabled.txt` (presence = auto-load). See `reference/main.lua.template`.

Core UE4SS Lua API (confirmed working here):
- `RegisterHook("/Script/Pkg.Class:Func", preFn, postFn)` — **preFn = before exec, postFn = after.**
  Output params are only populated in the POST callback. Each callback gets `(self, param1, param2, ...)`
  where every arg is a `RemoteUnrealParam` — call `:get()` to read the underlying UObject/array.
- `RegisterKeyBind(Key.F2, {ModifierKey.CONTROL}, fn)` — keybind. (Avoid F8 in RogueCore: bug-report UI.)
- `FindFirstOf("ClassShortName")` / `FindAllOf("ClassShortName")` — live instances. **Class short name
  includes the `_C` for blueprint classes** (e.g. `_MENU_ServerList_C`).
- `StaticFindObject("/Script/Engine.Default__SomeLibrary")` — get a CDO to call static library funcs.
- `ExecuteInGameThread(fn)` — REQUIRED wrapper for any UObject/widget mutation triggered from a keybind
  or async context. Touching widgets off the game thread crashes.
- `LoopAsync(ms, fn)` / `ExecuteWithDelay(ms, fn)` — timers. `ExecuteWithDelay` runs OFF the game
  thread — do NOT touch widgets inside it without re-wrapping in `ExecuteInGameThread`.
- **TArray:** 1-based indexing. `arr[i]`, `arr[i] = v`, `#arr`, `arr:GetArrayNum()`, `arr:ForEach(fn)`
  with `elem:get()`/`elem:set()`. **No insert/resize** — you can permute/copy existing elements only.
  To reorder a struct array, snapshot to a same-length scratch array (e.g. an unused input array) and
  write back in new order — cross-array copies avoid aliasing.
- **FText:** `SetText` needs an **FText**, NOT a Lua string (passing a string crashes with
  EXCEPTION_ACCESS_VIOLATION). Build it: `StaticFindObject("/Script/Engine.Default__KismetTextLibrary"):Conv_StringToText(str)`.

### 5. On-screen UI / feedback
- `KismetSystemLibrary:PrintString` is **suppressed in Shipping builds** — it logs "OK" but renders
  nothing. Don't rely on it.
- Instead drive a real, **bind-free** widget label: find a `TextBlock` in the target menu and `SetText`
  it. Caveats learned: labels with per-frame text bindings (e.g. localized "FILTERS") revert your text;
  labels inside collapsed containers (e.g. "no servers found") never render. A menu **title** label is
  usually bind-free and always visible — match it by its visible text, cache its widget name, then
  re-find by name afterward (its text changes once you edit it).
- Scope widget searches to the menu: `FindAllOf("TextBlock")` is game-wide and many widgets reuse
  auto-names like `TextBlock_3` — filter by `GetFullName()` containing the menu class.
- To apply changes immediately AND keep a status label in sync, do work in the post-hook of the
  function the menu calls every refresh tick (it fires ~1-2s while open), rather than a one-shot
  `Construct` hook (which may run before labels are populated).

### 6. Validate without a Lua runtime in the sandbox
There's usually no `lua` binary available. Sanity-check by stripping comments/strings then balancing
block keywords (`function/if/for/while` vs `end`) and brackets. See `reference/lua_syntax_check.py`.
Always wrap risky reflection/array work in `pcall` and **fail open** (e.g. on error, don't hide rows).

### 7. Iterate fast
- Set `EnableAutoReloadingLuaMods = 1` in `UE4SS-settings.ini` (needs one restart to take effect),
  then edits to `main.lua` hot-reload automatically. Or press the `HotReloadKey` (default `R`) with the
  UE4SS console focused.
- Add diagnostic `log()` lines liberally while debugging; the hook firing + param counts tell you
  whether you're on the pre vs post side and whether data is populated. Remove them for release.

### 8. Package for end users
A Lua mod REQUIRES the UE4SS runtime — there is no zero-UE4SS option short of rewriting as a
blueprint `_P.pak` (needs a modkit that may not exist for RogueCore yet). So bundle a **minimal
UE4SS + your mod** as one paste-in folder:
- Trim `Mods/mods.txt` to only what's needed (your mod + `Keybinds`; disable dev tools like
  `ConsoleCommandsMod`, `LineTraceMod`, `ActorDumperMod`, etc.).
- In `UE4SS-settings.ini` set `ConsoleEnabled=0`, `GuiConsoleEnabled=0` so no console window shows.
- Set `Verbose=false` in your mod's settings to stop log spam.
- Ship one zip extracted into `<game>/Binaries/Win64/`. Include an `INSTALL.txt` noting the Proton
  launch option for Linux users. UE4SS's license permits redistribution.
- Alternatively distribute via **Mint** (community DRG mod loader/integrator) or mod.io when available.

## Key pitfalls (all hit during development — avoid them)
1. Single-callback `RegisterHook` = PRE hook; output arrays are empty there. Use the POST callback.
2. Forcing a refresh via `SetServerSearchActive`/`ListLobbies` wipes the list (new network search) —
   use the widget's own no-arg refresh instead.
3. `SetText(luaString)` crashes — must be FText via `Conv_StringToText`.
4. `PrintString` is invisible in Shipping — use a real widget label.
5. Bound/localized labels revert; collapsed-container labels don't render — pick a bind-free,
   always-visible label (menu title) and re-find it by cached widget name.
6. `FindFirstOf` needs the `_C` suffix for blueprint classes; `FindAllOf` is game-wide (scope by path).
7. Off-game-thread widget mutation crashes — wrap in `ExecuteInGameThread`.
8. Mods that change gameplay flag the save as modded; keep cosmetic mods client-side only.

## Reference files
- `reference/dump_queries.py` — sandbox snippets to extract signatures, structs, callers, widgets from the dump.
- `reference/main.lua.template` — annotated starting Lua mod (hook + keybind + safe widget text + game-thread).
- `reference/lua_syntax_check.py` — no-runtime syntax balance check.
- `reference/pak_footer.py` — parse a pak footer/index to confirm encryption/version and list assets.
