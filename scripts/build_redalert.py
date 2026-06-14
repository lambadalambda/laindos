#!/usr/bin/env python3
"""Stage Command & Conquer: Red Alert (DOS) for LainDOS.

The vendor media is EA's 2008 freeware release of the original two-CD
set (plain ISO9660 data discs, no extraction needed). Builds a blank
bootable hd160m C: at build/redalert_c.img; boot it with the Allied ISO
attached as D: and run the CD installer from D:.
"""
import os
import sys

from testlib import run_cmd
from build_extras_hd import require_file


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "redalert_boot.bin")
KERNEL = os.path.join(BUILDDIR, "redalert_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
C_IMG = os.path.join(BUILDDIR, "redalert_c.img")

ALLIED_ISO = "vendor/cnc-red-alert/redalert_allied.iso"
SOVIET_ISO = "vendor/cnc-red-alert/redalert_soviets.iso"


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    require_file(ALLIED_ISO)

    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m",
        BOOT, KERNEL, C_IMG, SHELL, FREE, TIME,
    ])
    print(f"Built {C_IMG}; attach {ALLIED_ISO} as D:")


if __name__ == "__main__":
    main()
