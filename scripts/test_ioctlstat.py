#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "ioctlstat.img")
KERNEL = os.path.join(BUILDDIR, "ioctlstat_kernel.bin")
TIMEOUT = 10


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "ioctlstat_boot.bin")
    prog = os.path.join(BUILDDIR, "ioctlst.com")
    testdat = os.path.join(BUILDDIR, "test.dat")
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", boot])
    run(["nasm", '-DBOOT_FILE="IOCTLST COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "tests/programs/ioctlst.asm", "-o", prog])
    with open(testdat, "wb") as f:
        f.write(b"X")
    run(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, prog, testdat])


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
    for marker in [
        "MiniDOS booted",
        "PASS: IOCTLST",
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
    print("\nIOCTL input-status test passed.")


if __name__ == "__main__":
    main()
