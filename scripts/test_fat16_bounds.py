#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "fat16bounds.img")
KERNEL = os.path.join(BUILDDIR, "fat16bounds_kernel.bin")
TIMEOUT = 10
PROBE_LBA = 2
SECTOR_SIZE = 512


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "fat16bounds_boot.bin")
    run_cmd(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run_cmd([
        "nasm", "-DTEST_FAT16_FAT_SECTOR_BOUNDS", "-f", "bin",
        "src/kernel.asm", "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd32m", boot, KERNEL, IMG])


def read_probe_sector():
    with open(IMG, "rb") as f:
        f.seek(PROBE_LBA * SECTOR_SIZE)
        return f.read(SECTOR_SIZE)


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def main():
    build_image()
    before = read_probe_sector()
    output = run_qemu()
    after = read_probe_sector()
    failed = False
    for marker in ["MiniDOS booted", "PASS: FAT16BOUND", "HALT"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "Program exited, code="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if before != after:
        print("  FAIL: out-of-range FAT16 write changed a non-FAT sector")
        failed = True
    else:
        print("  PASS: out-of-range FAT16 write did not touch disk")
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFAT16 FAT sector bounds test passed.")


if __name__ == "__main__":
    main()
