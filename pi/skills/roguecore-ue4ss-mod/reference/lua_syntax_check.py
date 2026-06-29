#!/usr/bin/env python3
"""
No-runtime Lua sanity check (when no `lua`/`luac` binary is available in the sandbox).

It is NOT a full parser. It strips comments and string literals, then verifies:
  - block-opener keywords (function/if/for/while) balance against `end`
    (note: for/while use `do` but still close with ONE `end`; `elseif` is not an opener)
  - parentheses, braces, and brackets each balance

A MISMATCH almost always means a real syntax error. A balanced result is necessary
but not sufficient — still test in-game (hot reload) before shipping.

Usage:  python3 lua_syntax_check.py path/to/main.lua
"""
import re
import sys


def check(path):
    raw = open(path, encoding="utf-8", errors="replace").read()
    src = re.sub(r"--\[\[.*?\]\]", "", raw, flags=re.S)   # block comments
    src = re.sub(r"--[^\n]*", "", src)                     # line comments
    src = re.sub(r'"(\\.|[^"\\])*"', '""', src)            # dquote strings
    src = re.sub(r"'(\\.|[^'\\])*'", "''", src)            # squote strings

    def c(pat):
        return len(re.findall(pat, src))

    openers = c(r"\bfunction\b") + c(r"\bif\b") + c(r"\bfor\b") + c(r"\bwhile\b")
    ends = c(r"\bend\b")
    paren = src.count("(") - src.count(")")
    brace = src.count("{") - src.count("}")
    brack = src.count("[") - src.count("]")

    ok = (openers == ends) and paren == 0 and brace == 0 and brack == 0
    print(f"block openers={openers} end={ends} -> {'OK' if openers == ends else 'MISMATCH'}")
    print(f"() {paren}  {{}} {brace}  [] {brack}")
    print("RESULT:", "OK" if ok else "PROBLEM")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(check(sys.argv[1] if len(sys.argv) > 1 else "main.lua"))
