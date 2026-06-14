#!/usr/bin/env python3
"""Build SHELL.COM with the current git commit in its banner."""
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def run(cmd):
    subprocess.run(cmd, cwd=ROOT, check=True)


def git_build_id():
    try:
        out = subprocess.check_output(
            ["git", "log", "-1", "--format=%h %s"],
            cwd=ROOT,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return "unknown build"
    return sanitize(out.strip() or "unknown build")


def sanitize(text):
    chars = []
    for ch in text:
        code = ord(ch)
        if ch in {'"', '$', '\\'} or code < 32 or code > 126:
            chars.append('?')
        else:
            chars.append(ch)
    return "".join(chars)[:96]


def write_if_changed(path, data):
    old = path.read_text(encoding="ascii") if path.exists() else None
    if old != data:
        path.write_text(data, encoding="ascii")


def main(argv):
    if len(argv) != 2:
        print("usage: build_shell_com.py OUTPUT", file=sys.stderr)
        return 2
    output = Path(argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    inc = output.with_suffix(".build.inc")
    tmp = output.with_name(output.name + ".tmp")
    build_id = git_build_id()
    write_if_changed(inc, f'%define SHELL_BUILD_ID "{build_id}"\n')
    run(["nasm", "-P", str(inc), "-f", "bin", "programs/shell.asm", "-o", str(tmp)])
    new = tmp.read_bytes()
    old = output.read_bytes() if output.exists() else None
    if old == new:
        tmp.unlink()
    else:
        os.replace(tmp, output)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
