#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "execenv.img")
KERNEL = os.path.join(BUILDDIR, "execenv_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    child = os.path.join(BUILDDIR, "envchild.com")
    run_cmd(["nasm", "-f", "bin", "tests/programs/envchild.asm", "-o", child])
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "EXECENV COM", "tests/programs/execenv.asm", "execenv.com",
        extra_files=(child,),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: ENVCHILD", "PASS: EXECENV", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nEXEC environment test passed.")


if __name__ == "__main__":
    main()
