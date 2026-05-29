#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "rnguard.img")
KERNEL = os.path.join(BUILDDIR, "rnguard_kernel.bin")
TIMEOUT = 8


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "RNGUARD COM", "tests/programs/rnguard.asm", "rnguard.com")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: RNGUARD", "Program exited, code=00", "HALT")):
        sys.exit(1)

    print("\nRename guard test passed.")


if __name__ == "__main__":
    main()
