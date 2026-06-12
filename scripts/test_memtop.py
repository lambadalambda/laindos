#!/usr/bin/env python3
"""The MCB arena must stop at the BIOS conventional-memory line (INT 12h).

The bytes between INT 12h's answer and 640K are the EBDA; the BIOS PS/2
mouse services write there while DOS runs. An arena that hands them out
corrupts whatever lands in the last kilobyte — Settlers II's VBE
mode-info transfer buffer among the casualties.
"""
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "memtop.img")
KERNEL = os.path.join(BUILDDIR, "memtop_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "MEMTOP  COM", "tests/programs/memtop.asm", "memtop.com",
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: MEMTOP", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nMCB arena top test passed.")


if __name__ == "__main__":
    main()
