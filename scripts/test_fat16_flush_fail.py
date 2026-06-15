#!/usr/bin/env python3
import os
import sys

from fatlib import FatImage
from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fat16_flush_fail.img")
KERNEL = os.path.join(BUILDDIR, "fat16_flush_fail_kernel.bin")
PROGRAM = os.path.join(BUILDDIR, "f16ferr.com")
TOTAL_SECTORS = 2160
SIZE = TOTAL_SECTORS * 512
TIMEOUT = 20


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "fat16_flush_fail_boot.bin")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="F16FERR COM"',
        "-DTEST_FAT16_WINDOW_FLUSH_FAIL_ONCE",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/f16ferr.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd32m", boot, KERNEL, IMG, PROGRAM])


def verify_disk():
    img = FatImage.from_file(IMG)
    data = img.read_file("F16FERR.DAT")
    if len(data) != SIZE:
        print(f"  FAIL: F16FERR.DAT length {len(data)} != {SIZE}")
        return False
    for sector in range(TOTAL_SECTORS):
        start = sector * 512
        expected = sector & 0xFF
        chunk = data[start:start + 512]
        if chunk != bytes([expected]) * 512:
            got = chunk[0] if chunk else None
            print(f"  FAIL: F16FERR.DAT sector {sector} starts with {got}, expected {expected}")
            return False
    print("  PASS: F16FERR.DAT persisted after FAT16 flush retry")
    return True


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    failed = not check_markers(
        output,
        required=("PASS: F16FERR", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
    )
    if not verify_disk():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFAT16 flush failure retry test passed.")


if __name__ == "__main__":
    main()
