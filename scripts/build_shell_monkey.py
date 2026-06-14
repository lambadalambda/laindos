#!/usr/bin/env python3
"""Build a Monkey Island demo image that boots to SHELL.COM."""
import os
import subprocess
import sys

from testlib import run_cmd

BUILDDIR = "build"
BOOT = f"{BUILDDIR}/shell_monkey_boot.bin"
KERNEL = f"{BUILDDIR}/shell_monkey_kernel.bin"
SHELLDIR = f"{BUILDDIR}/shell_monkey_files"
SHELL = os.path.join(SHELLDIR, "shell.com")
TIME = os.path.join(SHELLDIR, "time.com")
IMG = f"{BUILDDIR}/shell_monkey.img"


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BUILDDIR, exist_ok=True)
    os.makedirs(SHELLDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

    game_files = [
        "vendor/midemo.exe",
        "vendor/disk01.lec",
        "vendor/000.lfl",
        "vendor/901.lfl",
        "vendor/902.lfl",
        "vendor/904.lfl",
        "vendor/monkey.txt",
        "vendor/readme",
    ]
    missing = [path for path in game_files if not os.path.isfile(path)]
    if missing:
        print("Missing Monkey Island vendor files:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        sys.exit(1)

    run_cmd([
        "python3", "scripts/mkimage.py", "--format=1440k",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        TIME,
        *game_files,
    ])


if __name__ == "__main__":
    main()
