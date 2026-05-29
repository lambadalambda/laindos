#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, check_markers, run_cmd, run_qemu_capture


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "pathcanon.img")
KERNEL = os.path.join(BUILDDIR, "pathcanon_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    pathcanon_com = os.path.join(BUILDDIR, "pathcan.com")
    subtest_dat = os.path.join(BUILDDIR, "subtest.dat")
    run_cmd(["nasm", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm", '-DBOOT_FILE="PATHCAN COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/pathcanon.asm", "-o", pathcanon_com])
    run_cmd(["python3", "scripts/mksubtest.py", subtest_dat])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, pathcanon_com, f"MIDEMO:{subtest_dat}"])


def main():
    build_image()
    output, _ = run_qemu_capture([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    if not check_markers(output, required=("PASS: PATHCANON", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nPath canonicalization test passed.")


if __name__ == "__main__":
    main()
