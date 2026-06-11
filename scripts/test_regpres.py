#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "regpres.img")
KERNEL = os.path.join(BUILDDIR, "regpres_kernel.bin")
TIMEOUT = 8


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="REGPRES COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/regpres.asm", "-o", os.path.join(BUILDDIR, "regpres.com")])
    testfile = write_fixture("testfile.dat", b"register preservation\n")
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "regpres.com"),
        testfile,
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("PASS: REGPRES", "Program exited, code=00")):
        sys.exit(1)
    print("\nRegister preservation test passed.")


if __name__ == "__main__":
    main()
