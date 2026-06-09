#!/usr/bin/env python3
import os
import shutil
import sys
import zipfile
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "sammax_cd")
CUE = os.path.join(WORKDIR, "BG GOLD 3.cue")
BIN = os.path.join(WORKDIR, "BG GOLD 3.bin")
ISO = os.path.join(WORKDIR, "BG_GOLD_3_data.iso")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "sammaxcd.com")
IMG = os.path.join(WORKDIR, "sammax_cd_files.img")
TIMEOUT = 15


def extract_member(archive, name, output):
    info = archive.getinfo(name)
    if os.path.exists(output) and os.path.getsize(output) == info.file_size:
        return
    with archive.open(info) as src, open(output, "wb") as dst:
        shutil.copyfileobj(src, dst)


def prepare_cd_image():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    os.makedirs(WORKDIR, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE) as archive:
        extract_member(archive, "BG GOLD 3.cue", CUE)
        extract_member(archive, "BG GOLD 3.bin", BIN)
    run_cmd(["python3", "scripts/extract_mode1_2352.py", CUE, ISO])


def build_artifacts():
    prepare_cd_image()
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SAMMAXCDCOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/sammaxcd.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output, _ = run_qemu_capture([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    ok = check_markers(
        output,
        required=("PASS: SAMMAXCD", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="Sam & Max CD file QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nSam & Max CD file smoke passed.")


if __name__ == "__main__":
    main()
