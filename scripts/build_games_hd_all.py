#!/usr/bin/env python3
"""Build a shell-booting hard disk image with all local game sets."""
import os
import shutil
import subprocess
import sys
import zipfile

BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "games_hd_all_boot.bin")
KERNEL = os.path.join(BUILDDIR, "games_hd_all_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
IMG = os.path.join(BUILDDIR, "games_hd_all.img")

MONKEY_FULL_ZIP = "vendor/monkey_full.zip"
MI2_DEMO_ZIP = "vendor/mi2demo.zip"
MI2_FULL_ZIP = "vendor/Monkey_Island_2_-_LeChucks_Revenge_1991.zip"
SIMON_DEMO_ZIP = "vendor/simon1demo.zip"
MONKEY_FULL_DIR = os.path.join(BUILDDIR, "monkey_full_files")
MI2_DEMO_DIR = os.path.join(BUILDDIR, "mi2demo")
MI2_FULL_DIR = os.path.join(BUILDDIR, "mi2full")
SIMON_DEMO_DIR = os.path.join(BUILDDIR, "simon1demo")


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
    if not os.path.isfile(zip_path):
        print(f"Missing {zip_path}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.namelist():
            parts = member.replace("\\", "/").split("/")
            if member.startswith("/") or ".." in parts or (parts and ":" in parts[0]):
                print(f"Unsafe zip member: {member}", file=sys.stderr)
                sys.exit(1)
        archive.extractall(output_dir)


def extract_flat(zip_path, output_dir):
    if not os.path.isfile(zip_path):
        print(f"Missing {zip_path}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            basename = os.path.basename(info.filename)
            if not basename:
                continue
            with archive.open(info) as src, open(os.path.join(output_dir, basename), "wb") as dst:
                dst.write(src.read())


def files_in(dirname):
    return [
        os.path.join(dirname, name)
        for name in sorted(os.listdir(dirname), key=str.upper)
        if os.path.isfile(os.path.join(dirname, name))
    ]


def require(paths):
    missing = [path for path in paths if not os.path.isfile(path)]
    if missing:
        print("Missing game files:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        sys.exit(1)


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BUILDDIR, exist_ok=True)
    extract_flat(MONKEY_FULL_ZIP, MONKEY_FULL_DIR)
    safe_extract(MI2_DEMO_ZIP, MI2_DEMO_DIR)
    safe_extract(MI2_FULL_ZIP, MI2_FULL_DIR)
    extract_flat(SIMON_DEMO_ZIP, SIMON_DEMO_DIR)

    run(["nasm", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/shell.asm", "-o", SHELL])

    m1_demo = [
        "vendor/midemo.exe",
        "vendor/disk01.lec",
        "vendor/000.lfl",
        "vendor/901.lfl",
        "vendor/902.lfl",
        "vendor/904.lfl",
        "vendor/monkey.txt",
        "vendor/readme",
    ]
    require(m1_demo)

    mi2_full_files = files_in(os.path.join(MI2_FULL_DIR, "mi2"))
    if not mi2_full_files:
        print(f"Missing extracted full MI2 files under {MI2_FULL_DIR}/mi2", file=sys.stderr)
        sys.exit(1)

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd20m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
    ]
    cmd.extend(f"M1DEMO:{path}" for path in m1_demo)
    cmd.extend(f"MONKEY:{path}" for path in files_in(MONKEY_FULL_DIR))
    cmd.extend(f"MI2DEMO:{path}" for path in files_in(MI2_DEMO_DIR))
    cmd.extend(f"MI2:{path}" for path in mi2_full_files)
    cmd.extend(f"SIMON:{path}" for path in files_in(SIMON_DEMO_DIR))
    run(cmd)


if __name__ == "__main__":
    main()
