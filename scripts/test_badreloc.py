#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "badreloc.img")
KERNEL = os.path.join(BUILDDIR, "badreloc_kernel.bin")
TIMEOUT = 8


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="BADRELOCCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/badreloc.asm", "-o", os.path.join(BUILDDIR, "badreloc.com")])
    run_cmd([
        "python3", "scripts/mkbadreloc.py",
        os.path.join(BUILDDIR, "badreloc.exe"),
        os.path.join(BUILDDIR, "goodnrel.exe"),
    ])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "badreloc.com"),
        os.path.join(BUILDDIR, "badreloc.exe"),
        os.path.join(BUILDDIR, "goodnrel.exe"),
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    failed = False

    for marker in ["PASS: BADRELOC"]:
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

    print("\nBad relocation test passed.")


if __name__ == "__main__":
    main()
