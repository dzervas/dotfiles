#!/usr/bin/env python3
"""Compact-style Nix formatter: `nixfmt` followed by a compaction pass.

Usage:
    compact-nix          # read stdin, write stdout (zed / conform / nil_ls)
    compact-nix FILE...  # format each file in place (nixfmt-style)

`nixfmt` canonicalizes indentation, `if` parentheses and comment placement.
This pass then restores the human style nixfmt destroys, all width-checked:

  - join `{ a, b, c }` parameter patterns and single-`inherit` sets when they fit
  - attach `let` to the header line and `in` to the term after it
  - glue `}:` to the lambda body, `X =` to its block, `(` to `if`
  - de-indent a lambda body whose header was joined
  - `{ }` -> `{}`, `[ ]` -> `[]`

The result is verified with `nix-instantiate --parse`; anything that does not
parse falls back to the plain nixfmt output, and a file nixfmt cannot read is
returned untouched.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

WIDTH = 100


# ---------------------------------------------------------------- tokenizer
def mask(lines):
    """Structural view of each line: string/comment content blanked.

    Returns (masked, comments, in_string) where:
      comments[i]  - line i has a comment
      in_string[i] - line i starts inside an indented `''` string
    """
    masked = []
    comments = []
    in_string = []
    state = "code"  # code | string | blockcomment
    stack = []  # 'interp' | 'brace'
    for line in lines:
        out = []
        has_comment = False
        in_string.append(state == "string")
        i, n = 0, len(line)
        while i < n:
            if state == "blockcomment":
                if line.startswith("*/", i):
                    state = "code"
                    out.append("  ")
                    i += 2
                else:
                    out.append(" ")
                    i += 1
                continue
            if state == "string":
                if line.startswith("''", i):
                    state = "code"
                    out.append("  ")
                    i += 2
                elif line.startswith("${", i):
                    state = "code"
                    stack.append("interp")
                    out.append("  ")
                    i += 2
                else:
                    out.append(" ")
                    i += 1
                continue
            # code
            if line.startswith("#", i):
                out.append(" " * (n - i))
                has_comment = True
                break
            if line.startswith("/*", i):
                state = "blockcomment"
                out.append("  ")
                i += 2
                continue
            if line.startswith("''", i):
                state = "string"
                out.append("  ")
                i += 2
                continue
            if line[i] == '"':
                j = i + 1
                while j < n:
                    if line[j] == "\\":
                        j += 2
                        continue
                    if line[j] == '"':
                        break
                    j += 1
                end = j if j < n else n - 1
                out.append(" " * (end - i + 1))
                i = end + 1
                continue
            c = line[i]
            if c == "{":
                stack.append("brace")
                out.append(c)
            elif c == "}":
                if stack and stack[-1] == "interp":
                    stack.pop()
                    state = "string"
                    out.append(" ")
                elif stack:
                    stack.pop()
                    out.append(c)
                else:
                    out.append(c)
            else:
                out.append(c)
            i += 1
        masked.append("".join(out))
        comments.append(has_comment)
    return masked, comments, in_string


def indent(line):
    return len(line) - len(line.lstrip())


# ------------------------------------------------------------- block analysis
def has_comment(comments, s, e):
    return any(comments[j] for j in range(s + 1, e))


def is_param_block(masked, comments, s, e):
    """Content lines are `name,` / `name ? v,` / `...`.

    Returns True when the pattern should collapse, False when it stays vertical.
    """
    if has_comment(comments, s, e):
        return None
    names, ellipsis = 0, False
    for j in range(s + 1, e):
        t = masked[j].strip()
        if t == "...":
            ellipsis = True
        elif t.endswith(","):
            names += 1
        else:
            return None
    if names == 0:
        return None
    # Keep a long, explicit destructuring vertical; collapse the short ones
    return names <= (4 if ellipsis else 3)


def is_literal_block(masked, comments, s, e):
    """Content lines are single bindings / inherits, one per line."""
    if has_comment(comments, s, e):
        return False
    for j in range(s + 1, e):
        t = masked[j].strip()
        if not t:
            continue
        if t.startswith("inherit") or t == "inherit":
            continue
        if t.endswith(";") and "=" in t:
            continue
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_\-]*", t):
            continue
        if t == ";":
            continue
        return False
    return True


def is_inherit_only(masked, s, e):
    """The block is one `inherit` statement (possibly expanded)."""
    toks = [masked[j].strip() for j in range(s + 1, e) if masked[j].strip()]
    if not toks or not toks[0].startswith("inherit"):
        return False
    return toks[-1].endswith(";")


def blocks_of(masked):
    """Every `{` block spanning more than one line: (start, end, column)."""
    stack, found = [], []
    for i, line in enumerate(masked):
        for col, ch in enumerate(line):
            if ch == "{":
                stack.append((i, col))
            elif ch == "}":
                if stack:
                    s, col = stack.pop()
                    if s < i:
                        found.append((s, i, col))
    return found


def merge(lines, s, e, drop_param_comma=False):
    parts = [lines[s].rstrip()]
    for j in range(s + 1, e + 1):
        t = lines[j].strip()
        if t:
            parts.append(t)
    if drop_param_comma and len(parts) > 2 and parts[-2].endswith(","):
        parts[-2] = parts[-2][:-1]
    return re.sub(r"\s+;", ";", " ".join(parts))


# ------------------------------------------------------------------- passes
def collapse(lines, width):
    """Join blocks that fit, innermost first."""
    changed = True
    while changed:
        changed = False
        masked, comments, _ = mask(lines)
        for s, e, col in sorted(blocks_of(masked), key=lambda b: b[1] - b[0]):
            prefix = masked[s][:col].strip()
            param = is_param_block(masked, comments, s, e)
            if param is False:
                continue
            if param is None:
                if not is_literal_block(masked, comments, s, e):
                    continue
                # `x = { ... }` stays vertical, unless it is a single inherit
                if prefix.endswith("=") and not is_inherit_only(masked, s, e):
                    continue
            joined = merge(lines, s, e, drop_param_comma=param is True)
            if len(joined) <= width:
                lines[s : e + 1] = [joined]
                changed = True
                break
    return lines


def deindent(lines, start, base):
    """Shift a lambda body left by one level, skipping indented strings."""
    _, _, in_string = mask(lines)
    i = start
    while i < len(lines):
        if lines[i].strip() and indent(lines[i]) <= base:
            break
        if lines[i].strip() and not in_string[i]:
            lines[i] = lines[i][2:]
        i += 1


def paren_end(lines, start):
    """Line index of the `)` matching the `(` on line `start`."""
    masked, _, _ = mask(lines)
    depth, end = 0, None
    for k in range(start, len(lines)):
        for ch in masked[k]:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return k
    return end


def joins(lines, width):
    """Attach header fragments to what follows (let/in, `}:`, `X =`, `(`)."""
    changed = True
    while changed:
        changed = False
        i = 0
        while i < len(lines):
            masked, _, in_string = mask(lines)
            t = masked[i].strip()
            nxt_ok = i + 1 < len(lines) and masked[i + 1].strip() and not in_string[i + 1]

            if t == "let" and i > 0 and (masked[i - 1].strip().endswith(":") or masked[i - 1].strip().endswith("=")):
                prev = lines[i - 1].rstrip()
                if len(prev) + 4 <= width:
                    lines[i - 1] = prev + " let"
                    del lines[i]
                    changed = True
                    continue
            elif t == "in" and nxt_ok:
                pad = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
                if len(pad + "in " + lines[i + 1].strip()) <= width:
                    lines[i:i + 2] = [pad + "in " + lines[i + 1].strip()]
                    changed = True
                    continue
            elif t.endswith("}:") and nxt_ok:
                joined = lines[i].rstrip() + " " + lines[i + 1].strip()
                if len(joined) <= width:
                    lines[i : i + 2] = [joined]
                    changed = True
                    continue
            elif t == "(" and nxt_ok and masked[i + 1].strip().startswith("if"):
                end = paren_end(lines, i)
                if end is None:
                    i += 1
                    continue
                lines[i : i + 2] = [lines[i].rstrip() + lines[i + 1].strip()]
                end -= 1
                for k in range(i + 1, end + 1):
                    if lines[k].strip():
                        lines[k] = lines[k][2:]
                lines[end - 1] = lines[end - 1].rstrip() + ")"
                del lines[end]
                changed = True
                continue
            elif (t.endswith(":") or t.endswith("=")) and nxt_ok:
                if t.endswith("=") and masked[i + 1].strip() == "let":
                    i += 1
                    continue
                if indent(lines[i + 1]) <= indent(lines[i]):
                    i += 1
                    continue
                joined = lines[i].rstrip() + " " + lines[i + 1].strip()
                if len(joined) <= width:
                    base = indent(lines[i])
                    lines[i : i + 2] = [joined]
                    deindent(lines, i + 1, base)
                    changed = True
                    continue
            i += 1
    return lines


def spaces(lines):
    """`{ }` -> `{}` and `[ ]` -> `[]` outside strings."""
    masked, _, _ = mask(lines)
    for i, line in enumerate(lines):
        out = list(line)
        mm = masked[i]
        for j in range(len(mm) - 2):
            if mm[j : j + 3] in ("{ }", "[ ]"):
                out[j + 1] = ""
        lines[i] = "".join(out)
    return lines


# ------------------------------------------------------------------- driver
def nixfmt(text, filename, width):
    """Run nixfmt on stdin, return its stdout, or None on failure."""
    cmd = ["nixfmt", "-", "--width", str(width)]
    if filename:
        cmd += ["--filename", filename]
    try:
        p = subprocess.run(cmd, input=text.encode(), capture_output=True)
    except FileNotFoundError:
        return None
    if p.returncode != 0:
        return None
    return p.stdout.decode()


def parses(text):
    """True when `nix-instantiate --parse` accepts the text."""
    with tempfile.NamedTemporaryFile("w", suffix=".nix", delete=True) as f:
        f.write(text)
        f.flush()
        p = subprocess.run(
            ["nix-instantiate", "--parse", f.name],
            capture_output=True,
        )
        return p.returncode == 0


def format_text(text, filename=None, width=WIDTH):
    formatted = nixfmt(text, filename, width)
    if formatted is None:
        return text
    lines = formatted.split("\n")
    lines = collapse(lines, width)
    lines = joins(lines, width)
    lines = collapse(lines, width)
    lines = joins(lines, width)
    lines = spaces(lines)
    result = "\n".join(lines)
    return result if parses(result) else formatted


def main():
    parser = argparse.ArgumentParser(prog="compact-nix", description=__doc__)
    parser.add_argument("files", nargs="*", help="files to format in place (default: stdin)")
    parser.add_argument("-w", "--width", type=int, default=WIDTH, help="line width (default 100)")
    args = parser.parse_args()

    if not args.files:
        sys.stdout.write(format_text(sys.stdin.read(), width=args.width))
        return 0
    for path in args.files:
        if path == "-": # nixfmt-style anonymous stdin
            sys.stdout.write(format_text(sys.stdin.read(), width=args.width))
            continue
        with open(path) as f:
            text = f.read()
        result = format_text(text, os.path.basename(path), args.width)
        if result != text:
            with open(path, "w") as f:
                f.write(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
