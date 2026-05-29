#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "execparam.img")
KERNEL = os.path.join(BUILDDIR, "execparam_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    child = os.path.join(BUILDDIR, "execpchk.com")
    run_cmd(["nasm", "-f", "bin", "tests/programs/execpchk.asm", "-o", child])
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "EXECPARMCOM", "tests/programs/execparam.asm", "execparm.com",
        extra_files=(child,),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: EXECPCHK", "PASS: EXECPARAM", "Program exited, code=00", "HALT")):
        sys.exit(1)
    if output.count("PASS: EXECPCHK") != 2:
        print("  FAIL: expected two EXECPCHK child runs")
        sys.exit(1)
    print("  PASS: found two EXECPCHK child runs")
    print("\nEXEC parameter block test passed.")


if __name__ == "__main__":
    main()
