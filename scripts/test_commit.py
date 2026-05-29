#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "committest.img")
KERNEL = os.path.join(BUILDDIR, "committest_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "COMMIT  COM", "tests/programs/committest.asm", "commit.com")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: COMMIT", "Program exited, code=00", "HALT"), forbidden=("FAIL:", "EXC ", "INT 21h AH=68")):
        sys.exit(1)
    print("\nCommit file test passed.")


if __name__ == "__main__":
    main()
