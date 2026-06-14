#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "readmulti.img")
KERNEL = os.path.join(BUILDDIR, "readmulti_kernel.bin")
DATA = os.path.join(BUILDDIR, "readmult.dat")
TIMEOUT = 8


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(DATA, "wb") as handle:
        handle.write(bytes(range(256)) * 40)
    boot = os.path.join(BUILDDIR, "readmulti_boot.bin")
    prog = os.path.join(BUILDDIR, "readmult.exe")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="READMULTEXE"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/readmulti.asm", "-o", prog])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", boot, KERNEL, IMG, prog, DATA])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    if not check_markers(output, required=("PASS: READMULTI", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nMulti-sector read test passed.")


if __name__ == "__main__":
    main()
