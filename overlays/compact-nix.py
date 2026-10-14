#!/usr/bin/env python3
"""Compact-style Nix formatter: `nixfmt` followed by a compaction pass.

Usage:
    compact-nix          # read stdin, write stdout (zed / conform / nil_ls)
    compact-nix FILE...  # format each file in place (nixfmt-style)

`nixfmt` canonicalizes indentation, `if` parentheses and comment placement.
This pass then restores the human style nixfmt destroys, all width-checked:

  - join `{ a, b, c }` parameter patterns and single-line binding sets when they fit
  - attach `let` to the header line and `in` to the term after it
  - glue `}:` to the lambda body, `X =` to its block, `(` to `if`
  - de-indent a body whose header was joined
  - `{ }` -> `{}`, `[ ]` -> `[]`

Structure comes from tree-sitter-nix; the edits themselves are line joins on
nixfmt's output. The result is verified with `nix-instantiate --parse`;
anything that does not parse falls back to the plain nixfmt output, and a file
nixfmt cannot read is returned untouched.
"""

import argparse
import bisect
import os
import subprocess
import sys
import tempfile

import tree_sitter_nix
from tree_sitter import Language, Parser, Query, QueryCursor

WIDTH = 100

NIX = Language(tree_sitter_nix.language())
PARSER = Parser(NIX)
SETS = Query(NIX, "[(attrset_expression) (rec_attrset_expression) (formals)] @n")
HEADERS = Query(NIX, "[(binding) (function_expression) (let_expression) (parenthesized_expression)] @n")
STRINGS = Query(NIX, "[(string_expression) (indented_string_expression)] @n")
EMPTIES = Query(NIX, "[(attrset_expression) (rec_attrset_expression) (formals) (list_expression)] @n")
COMMENTS = Query(NIX, "(comment) @n")


# ------------------------------------------------------------------ syntax
def parse(lines):
    return PARSER.parse("\n".join(lines).encode()).root_node


def find(root, query):
    """Nodes captured by `query`, in document order."""
    return sorted((n for ns in QueryCursor(query).captures(root).values() for n in ns), key=lambda n: n.start_byte)


def token(node, kind):
    return next((c for c in node.children if c.type == kind), None)


def after(node):
    """The syntax node (or comment) that follows `node`."""
    while node.next_sibling is None:
        node = node.parent
        if node is None:
            return None
    return node.next_sibling


def before(node):
    """The syntax node (or comment) that precedes `node`."""
    while node.prev_sibling is None:
        node = node.parent
        if node is None:
            return None
    return node.prev_sibling


def verbatim_rows(root):
    """Rows that start inside string content, where whitespace is meaningful."""
    rows = set()
    for s in find(root, STRINGS):
        own = set(range(s.start_point.row + 1, s.end_point.row + 1))
        for c in s.named_children:
            if c.type == "interpolation":
                own -= set(range(c.start_point.row + 1, c.end_point.row + 1))
        rows |= own
    return rows


def indent(line):
    return len(line) - len(line.lstrip())


def dedent(lines, rows, verbatim):
    """Shift `rows` left one level, leaving string content alone."""
    for r in rows:
        if lines[r].strip() and r not in verbatim:
            lines[r] = lines[r][2:]


# ----------------------------------------------------------------- collapse
def compact_formals(node):
    """Short `{ a, b ? v, ... }` patterns collapse, long ones stay vertical."""
    formals = [c for c in node.named_children if c.type == "formal"]
    if any(f.start_point.row != f.end_point.row for f in formals):
        return False
    ellipsis = any(c.type == "ellipses" for c in node.named_children)
    return 0 < len(formals) <= (4 if ellipsis else 3)


def compact_set(node):
    """A set of one-line bindings / inherits; `x = {` only when it starts with an inherit."""
    body = token(node, "binding_set")
    if body is None:
        return False
    bindings = body.named_children
    if any(b.type == "binding" and b.start_point.row != b.end_point.row for b in bindings):
        return False
    prev = before(node)
    return prev is None or prev.type != "=" or bindings[0].type in ("inherit", "inherit_from")


def merge(lines, drop_comma):
    parts = [lines[0].rstrip()]
    for raw in (line.strip() for line in lines[1:]):
        if not raw:
            continue
        # The lone `;` closing an expanded inherit joins without a space
        if raw == ";":
            parts[-1] += raw
        else:
            parts.append(raw)
    if drop_comma and len(parts) > 2 and parts[-2].endswith(","):
        parts[-2] = parts[-2][:-1]
    return " ".join(parts)


def collapse(lines, width):
    """Join sets that fit, innermost first."""
    while True:
        root = parse(lines)
        comments = [c.start_byte for c in find(root, COMMENTS)]
        sets = [n for n in find(root, SETS) if n.start_point.row < n.end_point.row]
        for node in sorted(sets, key=lambda n: n.end_point.row - n.start_point.row):
            k = bisect.bisect(comments, node.start_byte)
            if k < len(comments) and comments[k] < node.end_byte:
                continue
            formals = node.type == "formals"
            if not (compact_formals(node) if formals else compact_set(node)):
                continue
            s, e = node.start_point.row, node.end_point.row
            joined = merge(lines[s : e + 1], drop_comma=formals)
            if len(joined) <= width:
                lines[s : e + 1] = [joined]
                break
        else:
            return lines


# -------------------------------------------------------------------- joins
def glue(lines, node, verbatim, width):
    """Try one join anchored at `node`; True when `lines` changed."""
    if node.type == "parenthesized_expression":
        # `(\n  if ...\n)` -> `(if ...)`, the inside shifted left
        row, inner, close = node.start_point.row, node.named_children[0], token(node, ")")
        if lines[row].strip() != "(" or inner.type != "if_expression" or inner.start_point.row != row + 1:
            return False
        end = close.start_point.row
        if inner.end_point.row >= end:
            return False
        dedent(lines, range(row + 2, end), verbatim)
        lines[end - 1] += lines[end].strip()
        del lines[end]
        lines[row : row + 2] = [lines[row].rstrip() + lines[row + 1].strip()]
        return True

    if node.type == "let_expression":
        # `in\nbody` -> `in body`
        tok = token(node, "in")
        row = tok.start_point.row
        body = after(tok)
        if lines[row].strip() != "in" or body.type == "comment" or body.start_point.row != row + 1:
            return False
        joined = lines[row].rstrip() + " " + lines[row + 1].strip()
        if len(joined) > width:
            return False
        lines[row : row + 2] = [joined]
        return True

    # `X =\n  body` and `args:\n  body`: body joins the header line
    tok = token(node, "=" if node.type == "binding" else ":")
    row = tok.start_point.row
    body = after(tok)
    if body.type == "comment" or body.start_point.row != row + 1:
        return False
    deeper = indent(lines[row + 1]) > indent(lines[row])
    # `{ ... }:` and `let` bodies sit at the header's level; other lambda bodies must be deeper
    same_ok = node.type == "function_expression" and (
        body.type == "let_expression" or token(node, "formals") is not None
    )
    if not (deeper or same_ok):
        return False
    joined = lines[row].rstrip() + " " + lines[row + 1].strip()
    if len(joined) > width:
        return False
    if deeper:
        dedent(lines, range(row + 2, node.end_point.row + 1), verbatim)
    lines[row : row + 2] = [joined]
    return True


def joins(lines, width):
    """Attach header fragments to what follows (let/in, `}:`, `X =`, `(`)."""
    changed = True
    while changed:
        root = parse(lines)
        verbatim = verbatim_rows(root)
        # Every join edits the lines, so re-parse after the first one
        changed = any(glue(lines, n, verbatim, width) for n in find(root, HEADERS))
    return lines


def spaces(lines):
    """`{ }` -> `{}` and `[ ]` -> `[]`."""
    text = "\n".join(lines).encode()
    drop = [
        n.end_byte - 2
        for n in find(PARSER.parse(text).root_node, EMPTIES)
        if not n.named_children and n.text.endswith((b"{ }", b"[ ]"))
    ]
    for i in reversed(drop):
        text = text[:i] + text[i + 1 :]
    return text.decode().split("\n")


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
