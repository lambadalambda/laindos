#!/usr/bin/env python3
"""Build a bootable hard-disk image holding the Stunt Island installer media.

Extracts the six installer floppies from vendor/002514_stunt_island.7z and
lays their files out the way the DOS installer expects: INSTALL and the
loose files in the root, plus the RES/SETS/VAULT/PILOTS directories. Run
INSTALL from C:\\ to produce C:\\STUNTISL, then CD STUNTISL and STUNT.
"""
import os
import sys

from testlib import run_cmd
from build_extras_hd import clean_dir, extract_7z, extract_fat_image, require_file
import build_games_hd_all as games


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "stunt_hd_boot.bin")
KERNEL = os.path.join(BUILDDIR, "stunt_hd_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "stunt_hd.img")

ARCHIVE = "vendor/002514_stunt_island.7z"
ARCHIVE_DIR = os.path.join(BUILDDIR, "stunt_archive")
FILES_DIR = os.path.join(BUILDDIR, "stunt_source")


def extract_source():
    clean_dir(FILES_DIR)
    extract_7z(ARCHIVE, ARCHIVE_DIR)
    for root, _, names in os.walk(ARCHIVE_DIR):
        for name in sorted(names, key=str.upper):
            if name.lower().endswith(".img"):
                extract_fat_image(os.path.join(root, name), FILES_DIR)


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    require_file(ARCHIVE)

    os.makedirs(BUILDDIR, exist_ok=True)
    extract_source()

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd160m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        FREE,
        TIME,
    ]
    cmd.extend(games.files_in(FILES_DIR))
    for dirname in ("RES", "SETS", "VAULT", "PILOTS"):
        host_dir = os.path.join(FILES_DIR, dirname)
        if os.path.isdir(host_dir):
            cmd.extend(f"{dirname}:{path}" for path in games.files_in(host_dir))
    run_cmd(cmd)
    print(f"Built {IMG}")


if __name__ == "__main__":
    main()
