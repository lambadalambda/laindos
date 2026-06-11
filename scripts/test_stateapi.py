#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "stateapi.img")
KERNEL = os.path.join(BUILDDIR, "stateapi_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    state_com = os.path.join(BUILDDIR, "stateapi.com")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm", '-DBOOT_FILE="STATEAPICOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/stateapi.asm", "-o", state_com])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, state_com])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("PASS: STATEAPI", "Program exited, code=00", "HALT"),
                         forbidden=("FAIL:", "EXC ", "INT 21h AH=2B", "INT 21h AH=2D", "INT 21h AH=2E", "INT 21h AH=54")):
        sys.exit(1)
    print("\nState API test passed.")


if __name__ == "__main__":
    main()
