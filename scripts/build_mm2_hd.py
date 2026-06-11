#!/usr/bin/env python3
"""Stage Micro Machines 2 for its real floppy installer.

Extracts the four installer floppies from vendor/003513_micro_machines_2.7z
to build/mm2_disk1.img .. mm2_disk4.img and builds a blank bootable hd32m
target at build/mm2_hd.img. The game installs itself: boot the target with
disk 1 in A:, run A:\\INSTALL, and swap disks when prompted (the files live
in .SHR bundles the installer unpacks, so there is nothing to copy
directly).
"""
import os
import shutil
import sys

from testlib import run_cmd
from build_extras_hd import extract_7z, require_file


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "mm2_boot.bin")
KERNEL = os.path.join(BUILDDIR, "mm2_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "mm2_hd.img")

ARCHIVE = "vendor/003513_micro_machines_2.7z"
ARCHIVE_DIR = os.path.join(BUILDDIR, "mm2_archive")


def disk_image(n):
    return os.path.join(BUILDDIR, f"mm2_disk{n}.img")


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    require_file(ARCHIVE)

    os.makedirs(BUILDDIR, exist_ok=True)
    extract_7z(ARCHIVE, ARCHIVE_DIR)
    src_dir = os.path.join(ARCHIVE_DIR, "003513_micro_machines_2")
    for n in range(1, 5):
        shutil.copyfile(os.path.join(src_dir, f"disk{n}.img"), disk_image(n))

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd32m",
        BOOT, KERNEL, IMG, SHELL, FREE, TIME,
    ])
    print(f"Built {IMG} and mm2_disk1..4.img")


if __name__ == "__main__":
    main()
