#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "memrelease.img")
KERNEL = os.path.join(BUILDDIR, "memrelease_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    child = os.path.join(BUILDDIR, "memrchld.com")
    run_cmd(["nasm", "-f", "bin", "tests/programs/memrchld.asm", "-o", child])
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "MEMREL  COM", "tests/programs/memrel.asm", "memrel.com",
        extra_files=(child,),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: MEMREL", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nProcess memory release test passed.")


if __name__ == "__main__":
    main()
