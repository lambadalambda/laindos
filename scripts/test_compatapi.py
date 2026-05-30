#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "compatapi.img")
KERNEL = os.path.join(BUILDDIR, "compatapi_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "COMPATAPCOM", "tests/programs/compatapi.asm", "compatap.com",
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: COMPATAPI", "Program exited, code=00", "HALT"), forbidden=("FAIL:", "EXC ", "INT 21h AH=50", "INT 21h AH=5D", "INT 21h AH=60", "INT 21h AH=66", "INT 21h AH=71")):
        sys.exit(1)
    print("\nCompatibility API test passed.")


if __name__ == "__main__":
    main()
