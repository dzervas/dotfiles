#!/usr/bin/env python3
"""
Extraction snippets for a UE4SS UE4SS_ObjectDump.txt (RogueCore / DRG / any UE5 game).

Run these in a sandbox over the dump; print only what you need (the file is tens of MB).
Each line looks like:
  [ADDR] <Type> /Script/<Pkg>.<Class>:<Member> [o: OFFSET] [n:..] [pc:..] [ss:..] [em:..] [ai:..]
  [ADDR] <Type> /Game/<Path>.<Class>_C:<Member> ...   (blueprint asset/instance)

Usage:
  DUMP = "/path/to/UE4SS_ObjectDump.txt"
  L = open(DUMP, encoding="utf-8", errors="replace").read().splitlines()
"""
import re


def load(path):
    return open(path, encoding="utf-8", errors="replace").read().splitlines()


def by_addr(L, addr):
    """Resolve a [pc:]/[ss:]/[em:] pointer to the object line it points at."""
    pre = "[" + addr + "]"
    for l in L:
        if l.startswith(pre):
            return l
    return None


def func_signature(L, func_path):
    """Print a UFunction's params in declaration order.
    func_path e.g. '/Script/RogueCore.FSDServerListLibrary:SortLobbies'."""
    print(f"== {func_path} ==")
    if not any(func_path + " " in l and " Function " in l for l in L):
        print("  (function not found - is the owning class loaded in this dump?)")
    for l in L:
        if func_path + ":" in l and "Property" in l:
            field = l.split(func_path + ":", 1)[1].split(" ")[0]
            typ = l.split("] ", 1)[1].split(" ", 1)[0]
            off = (re.search(r"\[o:\s*([0-9A-Fa-f]+)\]", l) or [None, "?"])[1]
            print(f"   +0x{off:<4} {typ:<22} {field}")


def struct_fields(L, struct_path, limit=200):
    """Print a ScriptStruct/Class's fields with offsets.
    struct_path e.g. '/Script/RogueCore.ServerListLobby'."""
    print(f"== {struct_path} ==")
    for l in L:
        if struct_path + ":" in l and "Property" in l:
            field = l.split(struct_path + ":", 1)[1].split(" ")[0]
            typ = l.split("] ", 1)[1].split(" ", 1)[0]
            off = (re.search(r"\[o:\s*([0-9A-Fa-f]+)\]", l) or [None, "?"])[1]
            print(f"   +0x{off:<4} {typ:<22} {field}")


def class_functions(L, class_token):
    """List all UFunctions on a class. class_token e.g. 'FSDServerListLibrary' or '_MENU_ServerList_C'."""
    print(f"== {class_token} functions ==")
    seen = set()
    for l in L:
        m = re.search(r"\.%s:([A-Za-z0-9_]+) " % re.escape(class_token), l)
        if m and " Function " in l and m.group(1) not in seen:
            seen.add(m.group(1))
            print("  ", m.group(1))


def callers_of(L, func_name):
    """Find blueprints that call a UFunction (grep CallFunc_<name>)."""
    print(f"== callers of {func_name} ==")
    s = set()
    for l in L:
        if "CallFunc_" + func_name in l:
            m = re.search(r"(/Game/\S+?)\.(\w+)_C:([A-Za-z0-9_ ]+?):", l)
            if m:
                s.add(m.group(2) + "_C :: " + m.group(3))
    for x in sorted(s):
        print("  ", x)


def menu_textblocks(L, menu_token):
    """List TextBlock widget names that belong to a given menu (for UI status text).
    menu_token e.g. '_MENU_ServerList'."""
    print(f"== TextBlocks under {menu_token} ==")
    seen = set()
    for l in L:
        if "] TextBlock " in l and menu_token in l:
            m = re.search(r"\.([A-Za-z0-9_]+) \[", l)
            if m and m.group(1) not in seen:
                seen.add(m.group(1))
                print("  ", m.group(1))


def live_instances(L, class_token, limit=10):
    """Show live (non-default) instances of a class. Confirms a widget/actor is loaded."""
    print(f"== live {class_token} instances ==")
    n = 0
    for l in L:
        if re.search(r"\] %s " % re.escape(class_token), l) and "Default__" not in l:
            print("  ", l.split("] ", 1)[1][:140])
            n += 1
            if n >= limit:
                break


# ---- example driver ----
if __name__ == "__main__":
    import sys
    DUMP = sys.argv[1] if len(sys.argv) > 1 else "UE4SS_ObjectDump.txt"
    L = load(DUMP)
    print("lines:", len(L))
    # Examples — adapt to your target:
    func_signature(L, "/Script/RogueCore.FSDServerListLibrary:SortLobbies")
    struct_fields(L, "/Script/RogueCore.ServerListLobby")
    callers_of(L, "SortLobbies")
    menu_textblocks(L, "_MENU_ServerList")
    live_instances(L, "_MENU_ServerList_C")
