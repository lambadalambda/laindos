#!/usr/bin/env python3
"""Build a Monkey Island 2 demo image that boots to SHELL.COM."""
import os
import shutil
import subprocess
import sys
import zipfile

BUILDDIR = "build"
MI2DIR = os.path.join(BUILDDIR, "mi2demo")
MI2_ZIP = "vendor/mi2demo.zip"
BOOT = f"{BUILDDIR}/shell_mi2_boot.bin"
KERNEL = f"{BUILDDIR}/shell_mi2_kernel.bin"
SHELLDIR = f"{BUILDDIR}/shell_mi2_files"
SHELL = os.path.join(SHELLDIR, "shell.com")
IMG = f"{BUILDDIR}/shell_mi2.img"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}", file=sys.stderr)
        sys.exit(result.returncode)


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

    run(["nasm", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/shell.asm", "-o", SHELL])

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

    run([
        "python3", "scripts/mkimage.py", "--format=2880k",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        *paths,
    ])


if __name__ == "__main__":
    main()
