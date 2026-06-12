#!/usr/bin/env python3
"""Stage Wing Commander for its real floppy installer.

Copies the three vendor floppies (vendor/wing-commander_202104/disk1..3.ima,
the "Version B2.4: HI 3.5" release) to build/wc_disk1..3.img and builds a
blank bootable hd32m target at build/wc_hd.img. The game installs itself:
boot the target with disk 1 in A:, run A:\\INSTALL, and swap disks when
prompted.
"""
import os
import shutil
import sys

from testlib import run_cmd
from build_extras_hd import require_file


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "wc_boot.bin")
KERNEL = os.path.join(BUILDDIR, "wc_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "wc_hd.img")

VENDOR_DIR = "vendor/wing-commander_202104"


def disk_image(n):
    return os.path.join(BUILDDIR, f"wc_disk{n}.img")


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    for n in range(1, 4):
        require_file(os.path.join(VENDOR_DIR, f"disk{n}.ima"))

    os.makedirs(BUILDDIR, exist_ok=True)
    for n in range(1, 4):
        shutil.copyfile(os.path.join(VENDOR_DIR, f"disk{n}.ima"), disk_image(n))

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd32m",
        BOOT, KERNEL, IMG, SHELL, FREE, TIME,
    ])
    print(f"Built {IMG} and wc_disk1..3.img")


if __name__ == "__main__":
    main()
