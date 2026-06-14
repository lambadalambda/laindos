#!/usr/bin/env python3
"""Stage The Settlers II Gold Edition CD for LainDOS.

Extracts the MODE1/2352 data track from the CloneCD rip in
vendor/die-siedler-2-gold/ (CD01.cue + CD01.img; the eight audio tracks
are ignored) to build/settlers2_cd.iso and builds a blank bootable hd160m
C: at build/settlers2_c.img. Boot C: with the ISO attached as D: and run
the CD installer from D:.
"""
import os
import sys

from testlib import run_cmd
from build_extras_hd import require_file


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "settlers2_boot.bin")
KERNEL = os.path.join(BUILDDIR, "settlers2_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
C_IMG = os.path.join(BUILDDIR, "settlers2_c.img")
ISO = os.path.join(BUILDDIR, "settlers2_cd.iso")

CUE = "vendor/die-siedler-2-gold/CD01.cue"
IMG_RAW = "vendor/die-siedler-2-gold/CD01.img"


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    require_file(CUE)
    require_file(IMG_RAW)

    os.makedirs(BUILDDIR, exist_ok=True)
    if not os.path.exists(ISO):
        run_cmd(["python3", "scripts/extract_mode1_2352.py", CUE, ISO])

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m",
        BOOT, KERNEL, C_IMG, SHELL, FREE, TIME,
    ])
    print(f"Built {C_IMG} and {ISO}")


if __name__ == "__main__":
    main()
