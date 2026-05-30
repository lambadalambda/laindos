#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "irqmask.img")
KERNEL = os.path.join(BUILDDIR, "irqmask_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    child = os.path.join(BUILDDIR, "irqterm.com")
    run_cmd(["nasm", "-f", "bin", "tests/programs/irqterm.asm", "-o", child])
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "IRQMASK COM", "tests/programs/irqmask.asm", "irqmask.com",
        extra_files=(child,),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: IRQMASK", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nIRQ1 null-vector mask test passed.")


if __name__ == "__main__":
    main()
