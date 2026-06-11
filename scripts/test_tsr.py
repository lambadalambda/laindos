#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, check_markers, run_cmd, run_qemu_capture, run_serial_image


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "tsr.img")
KERNEL = os.path.join(BUILDDIR, "tsr_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
PARENT = os.path.join(BUILDDIR, "tsrtest.com")
CHILD = os.path.join(BUILDDIR, "tsrchild.com")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="TSRTEST COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/tsrtest.asm", "-o", PARENT])
    run_cmd(["nasm", "-f", "bin", "tests/programs/tsrchild.asm", "-o", CHILD])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PARENT, CHILD])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("PASS: TSR", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nTSR test passed.")


if __name__ == "__main__":
    main()
