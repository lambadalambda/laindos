#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "highmcb.img")
KERNEL = os.path.join(BUILDDIR, "highmcb_kernel.bin")


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="HIGHMCB COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/highmcb.asm", "-o", os.path.join(BUILDDIR, "highmcb.com")])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "highmcb.com"),
    ])


def run_qemu():
    output = run_serial_image(IMG, 10)
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: HIGHMCB", "Program exited, code=00", "HALT"]:
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
    print("\nHigh MCB allocation test passed.")


if __name__ == "__main__":
    main()
