#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "handleleak.img")
KERNEL = os.path.join(BUILDDIR, "handleleak_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(
        BUILDDIR,
        IMG,
        KERNEL,
        "HLEAK   COM",
        "tests/programs/handleleak.asm",
        "hleak.com",
        kernel_defines=("-DTEST_HANDLE_COUNT_QUERY", "-DTEST_FLUSH_DIR_SLOT_FAIL"),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(
        output,
        required=("PASS: HANDLELEAK", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=F0"),
    ):
        sys.exit(1)
    print("\nHandle leak test passed.")


if __name__ == "__main__":
    main()
