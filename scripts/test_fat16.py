#!/usr/bin/env python3
import os
import subprocess
import sys
import tempfile
from testlib import build_dir, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fat16.img")
KERNEL = os.path.join(BUILDDIR, "fat16_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot16.bin")
    memtest = os.path.join(BUILDDIR, "memtest.exe")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/memtest.asm", "-o", memtest])
    with tempfile.TemporaryDirectory(dir=BUILDDIR) as filler_dir:
        fillers = []
        for i in range(224):
            path = os.path.join(filler_dir, f"f{i:03d}.dat")
            with open(path, "wb") as f:
                f.write(b"x")
            fillers.append(path)
        run_cmd(["python3", "scripts/mkimage.py", "--format=hd32m", boot, KERNEL, IMG, *fillers, memtest])


def run_qemu():
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "LainDOS booted",
        "PASS: MEM",
        "Program exited, code=00",
        "HALT",
    ]:
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
    print("\nFAT16 boot test passed.")


if __name__ == "__main__":
    main()
