#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, run_cmd, run_qemu_capture


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "tsr.img")
KERNEL = os.path.join(BUILDDIR, "tsr_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
PARENT = os.path.join(BUILDDIR, "tsrtest.com")
CHILD = os.path.join(BUILDDIR, "tsrchild.com")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="TSRTEST COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/tsrtest.asm", "-o", PARENT])
    run_cmd(["nasm", "-f", "bin", "tests/programs/tsrchild.asm", "-o", CHILD])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PARENT, CHILD])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: TSR", "Program exited, code=00", "HALT"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nTSR test passed.")


if __name__ == "__main__":
    main()
