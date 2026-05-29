#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "parsefcb.img")
KERNEL = os.path.join(BUILDDIR, "parsefcb_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "PARSEFCBCOM", "tests/programs/parsefcb.asm", "parsefcb.com")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: PARSEFCB", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nParse FCB test passed.")


if __name__ == "__main__":
    main()
