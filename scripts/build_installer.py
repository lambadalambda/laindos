#!/usr/bin/env python3
"""Build a self-booting LainDOS installer floppy.

The floppy boots LainDOS to a shell; running INSTALL.COM formats a target
hard disk to FAT16 (sized to the detected disk) and copies the system
files onto it, making it bootable. The floppy carries:

  - a FAT12 boot sector + KERNEL.SYS (BOOT_FILE=SHELL) to boot itself
  - SHELL.COM / FREE.COM / TIME.COM  -- the system files to install
  - INSTALL.COM                       -- the installer
  - BOOT16.BIN                        -- a FAT16 boot sector template the
                                         installer patches and writes to C:

Intermediates are staged in build/installer/ (not build/ directly) so a
parallel test run does not race other tests building shell.com/etc. The
final floppy is build/installer.img.
"""
import os
import sys

from testlib import build_dir, run_cmd

BUILDDIR = build_dir()
STAGE = os.path.join(BUILDDIR, "installer")
BOOT12 = os.path.join(STAGE, "boot12.bin")
BOOT16 = os.path.join(STAGE, "boot16.bin")
KERNEL = os.path.join(STAGE, "kernel.bin")
SHELL = os.path.join(STAGE, "shell.com")
FREE = os.path.join(STAGE, "free.com")
TIME = os.path.join(STAGE, "time.com")
INSTALL = os.path.join(STAGE, "install.com")
IMG = os.path.join(BUILDDIR, "installer.img")


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    os.makedirs(STAGE, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT12])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT16])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])
    run_cmd(["nasm", "-f", "bin", "programs/install.asm", "-o", INSTALL])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=1440k",
        BOOT12, KERNEL, IMG,
        SHELL, FREE, TIME, INSTALL, BOOT16,
    ])
    print(f"Built installer floppy {IMG}")
    print("Boot it, then run INSTALL to format and populate a hard disk.")


if __name__ == "__main__":
    main()
