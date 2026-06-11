#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fat16_label.img")
KERNEL = os.path.join(BUILDDIR, "fat16_label_kernel.bin")
TIMEOUT = 15
MARKER_OFF = 0x02000010
MARKER = b"FAT16-BIG-LBA!\0\0"


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "fat16_label_boot.bin")
    fatbig = os.path.join(BUILDDIR, "fatbig.com")
    bigdat = os.path.join(BUILDDIR, "big.dat")
    dummy = os.path.join(BUILDDIR, "cfgdummy.dat")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="FATBIG  COM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/fatbig.asm", "-o", fatbig])
    with open(bigdat, "wb") as f:
        f.truncate(MARKER_OFF + len(MARKER))
        f.seek(MARKER_OFF)
        f.write(MARKER)
    with open(dummy, "wb") as f:
        f.write(b"cfgdir placeholder")
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL,
             IMG, fatbig, f"CFGDIR:{dummy}", bigdat])
    with open(IMG, "r+b") as img:
        img.seek(0x36)
        assert img.read(8) == b"FAT16   "
        img.seek(0x36)
        img.write(b"RAW DISK")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    passed = check_markers(
        output,
        required=("LainDOS booted", "PASS: FAT16BIG", "Program exited, code=00",
                  "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Invalid BPB"),
        output_label="fat16_label QEMU serial output")
    if not passed:
        sys.exit(1)
    print("\nFAT16 label-independent detection test passed.")


if __name__ == "__main__":
    main()
