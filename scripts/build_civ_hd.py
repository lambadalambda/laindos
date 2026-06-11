#!/usr/bin/env python3
"""Build a bootable hard-disk image with Civilization in C:\\CIV.

Extracts the floppy images inside vendor/sid-meiers-civilization-au.zip
and lays their files out flat in the CIV directory, matching the extras
image layout: CD CIV, then CIV.
"""
import os
import sys

from testlib import run_cmd
from build_extras_hd import extract_civilization, require_file, CIV_ARCHIVE, CIV_FILES_DIR
import build_games_hd_all as games


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "civ_hd_boot.bin")
KERNEL = os.path.join(BUILDDIR, "civ_hd_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
LOADFIX = os.path.join(BUILDDIR, "loadfix.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "civ_hd.img")


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    require_file(CIV_ARCHIVE)

    os.makedirs(BUILDDIR, exist_ok=True)
    extract_civilization()

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/loadfix.asm", "-o", LOADFIX])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd32m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        FREE,
        LOADFIX,
        TIME,
    ]
    cmd.extend(f"CIV:{path}" for path in games.files_in(CIV_FILES_DIR))
    run_cmd(cmd)
    print(f"Built {IMG}")


if __name__ == "__main__":
    main()
