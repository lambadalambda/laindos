#!/usr/bin/env python3
"""Build a hard-disk style image for the full VGA Monkey Island archive."""
import os
import shutil
import subprocess
import sys
import zipfile

BUILDDIR = "build"
VENDOR_ZIP = "vendor/monkey_full.zip"
FULLDIR = os.path.join(BUILDDIR, "monkey_full_files")
BOOT = os.path.join(BUILDDIR, "monkey_full_boot.bin")
KERNEL = os.path.join(BUILDDIR, "monkey_full_kernel.bin")
IMG = os.path.join(BUILDDIR, "monkey_full.img")


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}", file=sys.stderr)
        sys.exit(result.returncode)


def extract_game_files():
    if not os.path.isfile(VENDOR_ZIP):
        print(f"Missing {VENDOR_ZIP}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(FULLDIR):
        shutil.rmtree(FULLDIR)
    os.makedirs(FULLDIR)
    extracted = []
    with zipfile.ZipFile(VENDOR_ZIP) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            basename = os.path.basename(info.filename)
            if not basename:
                continue
            target = os.path.join(FULLDIR, basename)
            with archive.open(info) as src, open(target, "wb") as dst:
                dst.write(src.read())
            extracted.append(target)
    return sorted(extracted, key=lambda path: os.path.basename(path).upper())


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)
    os.makedirs(BUILDDIR, exist_ok=True)
    game_files = extract_game_files()
    if not any(os.path.basename(path).upper() == "MONKEY.EXE" for path in game_files):
        print("Full Monkey archive does not contain MONKEY.EXE", file=sys.stderr)
        sys.exit(1)

    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="MONKEY  EXE"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run([
        "python3", "scripts/mkimage.py", "--format=hd10m",
        BOOT,
        KERNEL,
        IMG,
        *game_files,
    ])


if __name__ == "__main__":
    main()
