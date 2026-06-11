#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_cmd, build_dir, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fat16seek.img")
KERNEL = os.path.join(BUILDDIR, "fat16seek_kernel.bin")
TIMEOUT = 25
SEEK_COUNT = 128
SEEK_START = 0x00000123
SEEK_STEP = 0x00020000


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "fat16seek_boot.bin")
    fatseek = os.path.join(BUILDDIR, "fatseek.com")
    bigdat = os.path.join(BUILDDIR, "seekbig.dat")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="FATSEEK COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/fatseek.asm", "-o", fatseek])
    size = SEEK_START + SEEK_STEP * (SEEK_COUNT - 1) + 1
    with open(bigdat, "wb") as f:
        f.truncate(size)
        for i in range(SEEK_COUNT):
            f.seek(SEEK_START + SEEK_STEP * i)
            f.write(bytes([(i + 1) & 0xFF]))
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL, IMG, fatseek, bigdat])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "LainDOS booted",
        "PASS: FATSEEK",
        "Program exited, code=00",
        "HALT",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFAT16 seek/read test passed.")


if __name__ == "__main__":
    main()
