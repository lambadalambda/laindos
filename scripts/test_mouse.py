#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "mouse.img")
KERNEL = os.path.join(BUILDDIR, "mouse_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "MOUSE   EXE", "tests/programs/mousetest.asm", "mouse.exe")


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: MOUSE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nMouse API test passed.")


if __name__ == "__main__":
    main()
