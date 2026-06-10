#!/usr/bin/env python3
"""Build a Monkey Island 2 demo image that boots to SHELL.COM."""
import os
import shutil
import subprocess
import sys

from testlib import run_cmd
import zipfile

BUILDDIR = "build"
MI2DIR = os.path.join(BUILDDIR, "mi2demo")
MI2_ZIP = "vendor/mi2demo.zip"
BOOT = f"{BUILDDIR}/shell_mi2_boot.bin"
KERNEL = f"{BUILDDIR}/shell_mi2_kernel.bin"
SHELLDIR = f"{BUILDDIR}/shell_mi2_files"
SHELL = os.path.join(SHELLDIR, "shell.com")
TIME = os.path.join(SHELLDIR, "time.com")
IMG = f"{BUILDDIR}/shell_mi2.img"


def safe_extract(zip_path, output_dir):
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    with zipfile.ZipFile(zip_path) as zf:
        for member in zf.namelist():
            parts = member.replace("\\", "/").split("/")
            if member.startswith("/") or ".." in parts or (parts and ":" in parts[0]):
                print(f"Unsafe zip member: {member}", file=sys.stderr)
                sys.exit(1)
        zf.extractall(output_dir)


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(MI2_ZIP):
        print(f"Missing {MI2_ZIP}", file=sys.stderr)
        sys.exit(1)

    safe_extract(MI2_ZIP, MI2DIR)
    os.makedirs(SHELLDIR, exist_ok=True)

    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

    mi2_files = [
        "MI2DEMO.EXE",
        "MI2DEMO.000",
        "MI2DEMO.001",
        "MI2DEMO.002",
        "DEMO.REC",
        "NULL.IMS",
    ]
    paths = []
    for name in mi2_files:
        path = os.path.join(MI2DIR, name)
        if not os.path.isfile(path):
            print(f"Missing extracted file: {path}", file=sys.stderr)
            sys.exit(1)
        paths.append(path)

    run_cmd([
        "python3", "scripts/mkimage.py", "--format=2880k",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        TIME,
        *paths,
    ])


if __name__ == "__main__":
    main()
