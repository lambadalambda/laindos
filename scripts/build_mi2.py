#!/usr/bin/env python3
"""Build Monkey Island 2 demo disk image for LainDOS testing."""
import os
import subprocess
import sys

from testlib import run_cmd
import zipfile

BUILDDIR = "build"
MI2DIR = os.path.join(BUILDDIR, "mi2demo")
MI2_ZIP = "vendor/mi2demo.zip"
MI2_KERNEL = f"{BUILDDIR}/mi2_kernel.bin"
MI2_IMG = f"{BUILDDIR}/mi2.img"


def main():
    if not os.path.exists(MI2_ZIP):
        print(f"Missing {MI2_ZIP}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(MI2DIR, exist_ok=True)
    with zipfile.ZipFile(MI2_ZIP) as zf:
        zf.extractall(MI2DIR)

    for src, out in [
        ("src/boot.asm", f"{BUILDDIR}/boot.bin"),
        ("src/kernel.asm", MI2_KERNEL),
        ("tests/programs/writetest.asm", f"{BUILDDIR}/write.exe"),
        ("tests/programs/mi2iotest.asm", f"{BUILDDIR}/mi2io.exe"),
    ]:
        cmd = ["nasm", "-f", "bin", src, "-o", out]
        if src == "src/kernel.asm":
            cmd.insert(1, '-DBOOT_FILE="MI2DEMO EXE"')
        elif src == "src/boot.asm":
            cmd.insert(1, "-DFAT12=1")
        run_cmd(cmd)

    mi2_files = [
        "MI2DEMO.EXE",
        "MI2DEMO.000",
        "MI2DEMO.001",
        "MI2DEMO.002",
        "DEMO.REC",
        "NULL.IMS",
    ]

    paths = []
    for name in mi2_files:
        path = os.path.join(MI2DIR, name)
        if not os.path.exists(path):
            print(f"Missing extracted file: {path}", file=sys.stderr)
            sys.exit(1)
        paths.append(path)

    run_cmd([
        "python3", "scripts/mkimage.py", "--format=2880k",
        f"{BUILDDIR}/boot.bin",
        MI2_KERNEL,
        MI2_IMG,
        f"{BUILDDIR}/mi2io.exe",
        *paths,
    ])


if __name__ == "__main__":
    main()
