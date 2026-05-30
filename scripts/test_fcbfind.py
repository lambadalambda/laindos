#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fcbfind.img")
KERNEL = os.path.join(BUILDDIR, "fcbfind_kernel.bin")
TESTFILE = os.path.join(BUILDDIR, "fcbfile.txt")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(TESTFILE, "wb") as f:
        f.write(b"FCB find test data\r\n")
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "FCBFIND COM", "tests/programs/fcbfind.asm", "fcbfind.com",
        extra_files=(TESTFILE,),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: FCBFIND", "Program exited, code=00", "HALT"), forbidden=("FAIL:", "EXC ", "INT 21h AH=11", "INT 21h AH=12")):
        sys.exit(1)
    print("\nFCB find test passed.")


if __name__ == "__main__":
    main()
