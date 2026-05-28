#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "bpb_invalid.img")
KERNEL = os.path.join(BUILDDIR, "bpb_invalid_kernel.bin")
TIMEOUT = 8


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", "-DTEST_BAD_BPB_SEC_PER_CLUS", "-f", "bin",
        "src/kernel.asm", "-o", KERNEL,
    ])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
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
    for marker in ["MiniDOS booted", "Invalid BPB", "HALT"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["EXC ", "Program exited, code="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nInvalid BPB boot test passed.")


if __name__ == "__main__":
    main()
