#!/usr/bin/env python3
"""Build a Wolfenstein 3D shareware image from vendor/wolf3dsw.zip."""
import os
import shutil
import subprocess
import sys
import zipfile

BUILDDIR = os.environ.get("LAINDOS_TEST_BUILD_DIR", "build")
VENDOR_ZIP = "vendor/wolf3dsw.zip"
WOLFDIR = os.path.join(BUILDDIR, "wolf3d_files")
BOOT = os.path.join(BUILDDIR, "wolf3d_boot.bin")
KERNEL = os.path.join(BUILDDIR, "wolf3d_kernel.bin")
IMG = os.path.join(BUILDDIR, "wolf3d.img")

REQUIRED = {
    "AUDIOHED.WL1",
    "AUDIOT.WL1",
    "GAMEMAPS.WL1",
    "MAPHEAD.WL1",
    "VGADICT.WL1",
    "VGAGRAPH.WL1",
    "VGAHEAD.WL1",
    "VSWAP.WL1",
    "WOLF3D.EXE",
}


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
    if os.path.isdir(WOLFDIR):
        shutil.rmtree(WOLFDIR)
    os.makedirs(WOLFDIR)
    extracted = []
    with zipfile.ZipFile(VENDOR_ZIP) as archive:
        names = {os.path.basename(info.filename).upper() for info in archive.infolist() if not info.is_dir()}
        missing = sorted(REQUIRED - names)
        if missing:
            print("Wolf3D archive is missing required files:", file=sys.stderr)
            for name in missing:
                print(f"  {name}", file=sys.stderr)
            sys.exit(1)
        for info in archive.infolist():
            if info.is_dir():
                continue
            basename = os.path.basename(info.filename).upper()
            if basename not in REQUIRED:
                continue
            target = os.path.join(WOLFDIR, basename)
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

    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="WOLF3D  EXE"', "-f", "bin", "src/kernel.asm",
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
