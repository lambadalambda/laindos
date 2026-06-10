#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "bigreloc.img")
KERNEL = os.path.join(BUILDDIR, "bigreloc_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="BIGRELOCEXE"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/bigreloc.asm", "-o", os.path.join(BUILDDIR, "bigreloc.exe")])
    run_cmd(["python3", "scripts/mktestfile.py", os.path.join(BUILDDIR, "testfile.dat")])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "bigreloc.exe"),
        os.path.join(BUILDDIR, "testfile.dat"),
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    failed = False

    if "PASS: BIGRELOC" in output:
        print("  PASS: found 'PASS: BIGRELOC'")
    else:
        print("  FAIL: missing 'PASS: BIGRELOC'")
        failed = True

    for marker in ["OPEN ", "RESIZE ", "FAIL:", "EXC "]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True

    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)

    print("\nBig relocation test passed.")


if __name__ == "__main__":
    main()
