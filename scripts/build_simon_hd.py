#!/usr/bin/env python3
"""Build a bootable hard-disk image with the Simon the Sorcerer demo in
C:\\SIMON, from vendor/simon1demo.zip. Launch with CD SIMON, then SIMON
(the bundled batch runs RUNVGA GDEMO /3).

The demo uses an EMS path that is not compatible with LainDOS' minimal
backed EMS yet, so this smoke image uses an EMS-less boot profile.
"""
import os
import sys

from testlib import run_cmd
import build_games_hd_all as games


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "simon_hd_boot.bin")
KERNEL = os.path.join(BUILDDIR, "simon_hd_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "simon_hd.img")


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    games.require([games.SIMON_DEMO_ZIP])

    os.makedirs(BUILDDIR, exist_ok=True)
    games.extract_flat(games.SIMON_DEMO_ZIP, games.SIMON_DEMO_DIR)

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-DENABLE_EMS=0",
        "-f", "bin", "src/kernel.asm", "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd32m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        FREE,
        TIME,
    ]
    cmd.extend(f"SIMON:{path}" for path in games.files_in(games.SIMON_DEMO_DIR))
    run_cmd(cmd)
    print(f"Built {IMG}")


if __name__ == "__main__":
    main()
