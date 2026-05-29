#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "drivedata.img")
KERNEL = os.path.join(BUILDDIR, "drivedata_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "DRIVEDATCOM", "tests/programs/drivedata.asm", "drivedat.com")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: DRIVEDATA", "Program exited, code=00", "HALT"), forbidden=("FAIL:", "EXC ", "INT 21h AH=1B", "INT 21h AH=1C")):
        sys.exit(1)
    print("\nDrive data test passed.")


if __name__ == "__main__":
    main()
