#!/usr/bin/env python3
"""Resolve source-anchor references in docs/site/*.jsx to concrete line numbers.

Docs may use ``{a: "anchor_name"}`` to refer to a line marked with
``; @anchor: anchor_name`` in a source file. The static site code-block
component needs numeric line numbers for its gutter, so this script
copies the docs to a staging directory with every anchor replaced by
the current line number it points at.

Usage::

    scripts/resolve_doc_anchors.py --src docs/site --out build/.resolved-docs

The source files themselves are never modified.
"""
import argparse
import re
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE_EXCERPT_DOCS_GLOB = (
    "app.jsx", "data.jsx", "shared.jsx", "shell.jsx", "v86machine.jsx",
    *[f"page_{name}.jsx" for name in [
        "boot", "misc", "dosapi", "tests", "filesystem", "memory", "programs",
        "shell", "mouse", "emulators", "casestudies", "glossary",
    ]],
)
ANCHOR_LINE_RE = re.compile(r"^\s*;\s*@anchor:\s*(\S+)\s*$")
CODE_ENTRY_NUM_RE = re.compile(r"\[(\d+)\s*,\s*(\"(?:\\.|[^\"\\])*\")\s*\]")
CODE_ENTRY_ANCHOR_RE = re.compile(
    r"\[\s*\{\s*a\s*:\s*\"([^\"]+)\"\s*\}\s*,\s*(\"(?:\\.|[^\"\\])*\")\s*\]"
)
HI_LIST_RE = re.compile(r"\bhi:\s*\[([^\]]+)\]")
FILE_DECL_RE = re.compile(r"\bfile:\s*\"([^\"]+)\"")


def collect_anchors(source_lines):
    anchors = {}
    for i, line in enumerate(source_lines, 1):
        m = ANCHOR_LINE_RE.match(line)
        if m:
            name = m.group(1)
            if name in anchors:
                raise ValueError(
                    f"duplicate anchor {name!r} at line {i} (first at line {anchors[name] - 1})"
                )
            target = i + 1
            if target > len(source_lines):
                raise ValueError(
                    f"anchor {name!r} at line {i} has no following line"
                )
            anchors[name] = target
    return anchors


def find_matching(text, start, open_ch="[", close_ch="]"):
    depth = 0
    in_string = None
    escaped = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == in_string:
                in_string = None
            continue
        if ch in ('"', "'"):
            in_string = ch
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return None


def resolve_doc(text, source_cache):
    out = []
    pos = 0
    while True:
        m = re.search(r"\bcode:\s*\[", text[pos:])
        if not m:
            out.append(text[pos:])
            break
        block_start = pos + m.end() - 1
        block_end = find_matching(text, block_start)
        if block_end is None:
            raise ValueError(f"unterminated code block near byte {pos + m.start()}")
        prefix = text[max(0, pos + m.start() - 2500):pos + m.start()]
        decls = FILE_DECL_RE.findall(prefix)
        if decls:
            source_rel = decls[-1]
            source_path = ROOT / source_rel
            if source_path.exists():
                if source_path not in source_cache:
                    source_cache[source_path] = collect_anchors(
                        source_path.read_text(encoding="utf-8").splitlines()
                    )
                anchors = source_cache[source_path]
                block_text = text[block_start:block_end + 1]
                resolved = resolve_code_block(block_text, anchors)
                out.append(text[pos:pos + m.end() - 1] + resolved)
            else:
                out.append(text[pos:block_end + 1])
        else:
            out.append(text[pos:block_end + 1])
        pos = block_end + 1

    resolved = "".join(out)

    def hi_sub(match):
        prefix = resolved[max(0, match.start() - 5000):match.start()]
        decls = FILE_DECL_RE.findall(prefix)
        if not decls:
            return match.group(0)
        source_rel = decls[-1]
        source_path = ROOT / source_rel
        if not source_path.exists() or source_path not in source_cache:
            return match.group(0)
        anchors = source_cache[source_path]
        parts = []
        for part in match.group(1).split(","):
            part = part.strip()
            if not part:
                continue
            if part.startswith("{"):
                m = re.match(r"\{\s*a\s*:\s*\"([^\"]+)\"\s*\}", part)
                if not m:
                    raise ValueError(f"unrecognised hi entry: {part!r}")
                if m.group(1) not in anchors:
                    raise ValueError(
                        f"unknown anchor {m.group(1)!r} for hi array in {source_rel}"
                    )
                parts.append(str(anchors[m.group(1)]))
            else:
                parts.append(part)
        return "hi: [" + ", ".join(parts) + "]"

    return HI_LIST_RE.sub(hi_sub, resolved)


def resolve_code_block(block, anchors):
    def anchor_sub(match):
        anchor_name, content = match.group(1), match.group(2)
        if anchor_name not in anchors:
            raise ValueError(f"unknown anchor {anchor_name!r}")
        return "[" + str(anchors[anchor_name]) + ", " + content + "]"

    block = CODE_ENTRY_ANCHOR_RE.sub(anchor_sub, block)
    return block


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default="docs/site", help="source docs directory")
    parser.add_argument("--out", default="build/.resolved-docs",
                        help="output directory for resolved docs")
    args = parser.parse_args()

    src_dir = (ROOT / args.src).resolve()
    out_dir = (ROOT / args.out).resolve()
    if not src_dir.is_dir():
        print(f"error: source dir not found: {src_dir}", file=sys.stderr)
        return 1

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    source_cache = {}
    for name in SOURCE_EXCERPT_DOCS_GLOB:
        src_file = src_dir / name
        if not src_file.exists():
            continue
        text = src_file.read_text(encoding="utf-8")
        try:
            resolved = resolve_doc(text, source_cache)
        except ValueError as exc:
            print(f"error: {src_file.relative_to(ROOT)}: {exc}", file=sys.stderr)
            return 1
        (out_dir / name).write_text(resolved, encoding="utf-8")

    print(f"Resolved {len(source_cache)} source file(s) into {out_dir.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
