#!/usr/bin/env python3
import ast
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE_EXCERPT_DOCS = [
    ROOT / "docs/site/data.jsx",
    *sorted((ROOT / "docs/site").glob("page_*.jsx")),
]
PATH_REF_DOCS = [
    ROOT / "README.md",
    ROOT / "docs/test_ladder.md",
    *sorted((ROOT / "docs/site").glob("*.jsx")),
]
TEST_COUNT_DOCS = [
    ROOT / "README.md",
    ROOT / "docs/site/shell.jsx",
]
ALLOW_MISSING_PATHS = {
    "scripts/test_example.py",
    "tests/programs/example.asm",
}


def rel(path):
    return path.relative_to(ROOT).as_posix()


def read(path):
    return path.read_text(encoding="utf-8")


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
        if ch in ('"', "'", "`"):
            in_string = ch
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return None


def source_path_for_code_block(text, code_pos):
    prefix = text[max(0, code_pos - 2500):code_pos]
    matches = list(re.finditer(r"\b(?:file|codeFile):\s*\"([^\"]+)\"", prefix))
    if not matches:
        return None
    path = matches[-1].group(1)
    if path in {"-", "--", "---"} or path.startswith("—"):
        return None
    return path


def parse_code_entries(block):
    entries = []
    pattern = re.compile(r"\[\s*(\d+)\s*,\s*(\"(?:\\.|[^\"\\])*\")\s*\]")
    for match in pattern.finditer(block):
        line_no = int(match.group(1))
        entries.append((line_no, json.loads(match.group(2))))
    return entries


def code_part(line):
    return line.split(";", 1)[0].rstrip()


def check_source_excerpts(errors):
    checked = 0
    for doc in SOURCE_EXCERPT_DOCS:
        text = read(doc)
        pos = 0
        while True:
            match = re.search(r"\bcode:\s*\[", text[pos:])
            if not match:
                break
            code_pos = pos + match.start()
            bracket_start = pos + match.end() - 1
            bracket_end = find_matching(text, bracket_start)
            if bracket_end is None:
                errors.append(f"{rel(doc)}: unterminated code block near byte {code_pos}")
                break
            source_rel = source_path_for_code_block(text, code_pos)
            if source_rel:
                source = ROOT / source_rel
                if not source.exists():
                    errors.append(f"{rel(doc)}: source excerpt file missing: {source_rel}")
                else:
                    source_lines = source.read_text(encoding="utf-8").splitlines()
                    for line_no, excerpt in parse_code_entries(text[bracket_start:bracket_end + 1]):
                        checked += 1
                        if line_no < 1 or line_no > len(source_lines):
                            errors.append(f"{rel(doc)}: {source_rel}:{line_no} is outside file")
                            continue
                        actual = source_lines[line_no - 1]
                        if code_part(actual) != code_part(excerpt):
                            errors.append(
                                f"{rel(doc)}: stale excerpt {source_rel}:{line_no}\n"
                                f"  doc:    {excerpt!r}\n"
                                f"  source: {actual!r}"
                            )
            pos = bracket_end + 1
    if checked == 0:
        errors.append("no source excerpts were checked")


def default_test_count():
    tree = ast.parse(read(ROOT / "scripts/run_tests.py"))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "DEFAULT_TESTS":
                    if isinstance(node.value, ast.List):
                        return len(node.value.elts)
    raise RuntimeError("DEFAULT_TESTS not found")


def check_test_counts(errors):
    expected = default_test_count()
    pattern = re.compile(r"\b(\d+)/(\d+)`?\s+tests\b")
    found = 0
    for doc in TEST_COUNT_DOCS:
        for match in pattern.finditer(read(doc)):
            found += 1
            left, right = int(match.group(1)), int(match.group(2))
            if left != expected or right != expected:
                errors.append(f"{rel(doc)}: stale test count {left}/{right}; expected {expected}/{expected}")
    if found == 0:
        errors.append("no hardcoded test counts were checked")


def make_targets():
    targets = set()
    for line in read(ROOT / "Makefile").splitlines():
        if not line or line[0].isspace() or ":" not in line:
            continue
        left = line.split(":", 1)[0].strip()
        if not left or "=" in left:
            continue
        targets.update(part for part in left.split() if part)
    return targets


def documented_make_commands(text):
    pattern = re.compile(r"(?<![\w-])make\s+(?:[A-Z_][A-Z0-9_]*=\S+\s+)*(?:-[A-Za-z0-9]+\s+)*(?!-)([A-Za-z0-9_.-]+)")
    return [match.group(1) for match in pattern.finditer(text)]


def make_command_fragments(text):
    for match in re.finditer(r"`([^`]*\bmake\b[^`]*)`|\"([^\"]*\bmake\b[^\"]*)\"|'([^']*\bmake\b[^']*)'", text):
        fragment = next(group for group in match.groups() if group is not None).strip()
        if fragment.startswith("make ") or re.match(r"^[A-Z_][A-Z0-9_]*=\S+\s+make\s+", fragment):
            yield fragment
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("make ") or re.match(r"^[A-Z_][A-Z0-9_]*=\S+\s+make\s+", stripped):
            yield stripped


def check_make_targets(errors):
    targets = make_targets()
    for doc in PATH_REF_DOCS:
        for fragment in make_command_fragments(read(doc)):
            for target in documented_make_commands(fragment):
                if target not in targets:
                    errors.append(f"{rel(doc)}: documented make target does not exist: {target}")


def check_path_refs(errors):
    pattern = re.compile(r"(?<![A-Za-z0-9_./-])((?:\.github|docs|meta|programs|scripts|src|tests)/(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+)")
    for doc in PATH_REF_DOCS:
        for match in pattern.finditer(read(doc)):
            path = match.group(1).rstrip(".,;:)]}")
            if path in ALLOW_MISSING_PATHS:
                continue
            if "." not in Path(path).name:
                continue
            if not (ROOT / path).exists():
                errors.append(f"{rel(doc)}: referenced file does not exist: {path}")


def check_site_scripts(errors):
    index = ROOT / "docs/site/index.html"
    for src in re.findall(r"<script[^>]+src=\"([^\"]+)\"", read(index)):
        if "://" in src:
            continue
        if not (index.parent / src).exists():
            errors.append(f"{rel(index)}: local script missing: {src}")


def main():
    errors = []
    check_source_excerpts(errors)
    check_test_counts(errors)
    check_make_targets(errors)
    check_path_refs(errors)
    check_site_scripts(errors)
    if errors:
        print("Documentation sync check failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Documentation sync check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
