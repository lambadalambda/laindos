#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "seekedge.img")
KERNEL = os.path.join(BUILDDIR, "seekedge_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "seekedge_boot.bin")
    prog = os.path.join(BUILDDIR, "seekedge.com")
    data = os.path.join(BUILDDIR, "seekedge.dat")
    with open(data, "wb") as handle:
        handle.write(b"ABCDE")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SEEKEDGECOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/seekedge.asm", "-o", prog])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, prog, data])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: SEEKEDGE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nSeek edge test passed.")


if __name__ == "__main__":
    main()
