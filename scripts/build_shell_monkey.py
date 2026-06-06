#!/usr/bin/env python3
"""Build a Monkey Island demo image that boots to SHELL.COM."""
import os
import subprocess
import sys

BUILDDIR = "build"
BOOT = f"{BUILDDIR}/shell_monkey_boot.bin"
KERNEL = f"{BUILDDIR}/shell_monkey_kernel.bin"
SHELLDIR = f"{BUILDDIR}/shell_monkey_files"
SHELL = os.path.join(SHELLDIR, "shell.com")
IMG = f"{BUILDDIR}/shell_monkey.img"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}", file=sys.stderr)
        sys.exit(result.returncode)


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BUILDDIR, exist_ok=True)
    os.makedirs(SHELLDIR, exist_ok=True)
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])

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

    run([
        "python3", "scripts/mkimage.py", "--format=1440k",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        *game_files,
    ])


if __name__ == "__main__":
    main()
