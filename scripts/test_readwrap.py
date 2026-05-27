#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "readwrap.img")
KERNEL = os.path.join(BUILDDIR, "readwrap_kernel.bin")
DATA = os.path.join(BUILDDIR, "readwrap.dat")
TIMEOUT = 8


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
    with open(DATA, "wb") as handle:
        handle.write(bytes(range(256)) * 2)
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="READWRAPEXE"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/readwrap.asm", "-o", os.path.join(BUILDDIR, "readwrap.exe")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "readwrap.exe"),
        DATA,
    ])


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
    if "PASS: READWRAP" in output:
        print("  PASS: found 'PASS: READWRAP'")
    else:
        print("  FAIL: missing 'PASS: READWRAP'")
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
    print("\nRead wrap test passed.")


if __name__ == "__main__":
    main()
