#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, run_cmd, run_qemu_capture


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "jft.img")
KERNEL = os.path.join(BUILDDIR, "jft_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
PROGRAM = os.path.join(BUILDDIR, "jft.com")
DATA = os.path.join(BUILDDIR, "jftdata.txt")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(DATA, "wb") as handle:
        handle.write(b"JFT")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="JFT     COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/jft.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM, DATA])


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
    for marker in ["PASS: JFT", "Program exited, code=00", "HALT"]:
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
    print("\nJFT test passed.")


if __name__ == "__main__":
    main()
