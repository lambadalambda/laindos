#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "xms.img")
KERNEL = os.path.join(BUILDDIR, "xms_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    test_com = os.path.join(BUILDDIR, "xmstest.com")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm", '-DBOOT_FILE="XMSTEST COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/xmstest.asm", "-o", test_com])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, test_com])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("PASS: XMS", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nXMS API test passed.")


if __name__ == "__main__":
    main()
