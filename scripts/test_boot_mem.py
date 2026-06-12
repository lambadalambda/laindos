#!/usr/bin/env python3
"""A .COM program owns the largest free block, like real DOS.

Real DOS loads a COM into the largest free block with SP at 0xFFFE,
and .COM images carry no BSS, so era programs freely use the room past
their file image. A file-sized allocation puts the stack a few KiB past
the code and lets in-image buffers silently overwrite it.
"""
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "bootmem.img")
KERNEL = os.path.join(BUILDDIR, "bootmem_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "BOOTMEM COM", "tests/programs/bootmem.asm", "bootmem.com",
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: BOOTMEM", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nCOM largest-block test passed.")


if __name__ == "__main__":
    main()
