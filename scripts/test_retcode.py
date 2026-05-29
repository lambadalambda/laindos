#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "retcode.img")
KERNEL = os.path.join(BUILDDIR, "retcode_kernel.bin")
TIMEOUT = 10


def build_child(name, code):
    path = os.path.join(BUILDDIR, name)
    run_cmd([
        "nasm", f"-DRET_CODE={code}", "-f", "bin",
        "tests/programs/retchild.asm", "-o", path,
    ])
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    ret7 = build_child("ret7.com", 7)
    ret42 = build_child("ret42.com", 42)
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "RETCODE COM", "tests/programs/retcode.asm", "retcode.com",
        extra_files=(ret7, ret42),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: RETCODE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nReturn code test passed.")


if __name__ == "__main__":
    main()
