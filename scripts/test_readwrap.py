#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "readwrap.img")
KERNEL = os.path.join(BUILDDIR, "readwrap_kernel.bin")
DATA = os.path.join(BUILDDIR, "readwrap.dat")
TIMEOUT = 8


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(DATA, "wb") as handle:
        handle.write(bytes(range(256)) * 2)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="READWRAPEXE"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/readwrap.asm", "-o", os.path.join(BUILDDIR, "readwrap.exe")])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "readwrap.exe"),
        DATA,
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    failed = False
    if "PASS: READWRAP" in output:
        print("  PASS: found 'PASS: READWRAP'")
    else:
        print("  FAIL: missing 'PASS: READWRAP'")
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
    print("\nRead wrap test passed.")


if __name__ == "__main__":
    main()
